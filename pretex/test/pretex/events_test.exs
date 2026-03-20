defmodule Pretex.EventsTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Events
  alias Pretex.Events.Event

  defp catalog_item_fixture(event) do
    item_fixture(event, %{name: "Ingresso Geral", price_cents: 5000})
  end

  # ---------------------------------------------------------------------------
  # list_events/1
  # ---------------------------------------------------------------------------

  describe "list_events/1" do
    test "returns events for an org" do
      org = org_fixture()
      event = event_fixture(org)

      events = Events.list_events(org)
      assert Enum.any?(events, &(&1.id == event.id))
    end

    test "does not return events from another org" do
      org1 =
        org_fixture(%{name: "Org One", slug: "org-one-#{System.unique_integer([:positive])}"})

      org2 =
        org_fixture(%{name: "Org Two", slug: "org-two-#{System.unique_integer([:positive])}"})

      event_fixture(org1)

      events = Events.list_events(org2)
      assert events == []
    end

    test "auto-completes published events whose end date has passed" do
      org = org_fixture()

      {:ok, event} =
        Events.create_event(org, %{
          name: "Past Event",
          starts_at: ~U[2020-01-01 10:00:00Z],
          ends_at: ~U[2020-01-01 18:00:00Z]
        })

      catalog_item_fixture(event)
      {:ok, published} = Events.publish_event(event)
      assert published.status == "published"

      events = Events.list_events(org)
      found = Enum.find(events, &(&1.id == event.id))
      assert found.status == "completed"
    end
  end

  # ---------------------------------------------------------------------------
  # get_event!/1
  # ---------------------------------------------------------------------------

  describe "get_event!/1" do
    test "returns the event with given id" do
      org = org_fixture()
      event = event_fixture(org)
      assert Events.get_event!(event.id).id == event.id
    end

    test "raises for missing id" do
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(0) end
    end
  end

  # ---------------------------------------------------------------------------
  # create_event/2
  # ---------------------------------------------------------------------------

  describe "create_event/2" do
    test "with valid attrs creates a draft event" do
      org = org_fixture()

      assert {:ok, %Event{} = event} =
               Events.create_event(org, %{
                 name: "Summer Fest",
                 starts_at: ~U[2030-07-01 10:00:00Z],
                 ends_at: ~U[2030-07-01 22:00:00Z]
               })

      assert event.name == "Summer Fest"
      assert event.status == "draft"
      assert event.organization_id == org.id
      assert event.slug == "summer-fest"
    end

    test "with missing name returns error changeset" do
      org = org_fixture()

      assert {:error, changeset} =
               Events.create_event(org, %{
                 starts_at: ~U[2030-07-01 10:00:00Z],
                 ends_at: ~U[2030-07-01 22:00:00Z]
               })

      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "with ends_at before starts_at returns error changeset" do
      org = org_fixture()

      assert {:error, changeset} =
               Events.create_event(org, %{
                 name: "Bad Dates",
                 starts_at: ~U[2030-07-02 10:00:00Z],
                 ends_at: ~U[2030-07-01 10:00:00Z]
               })

      assert %{ends_at: [_ | _]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # update_event/2
  # ---------------------------------------------------------------------------

  describe "update_event/2" do
    test "with valid attrs updates the event" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, updated} = Events.update_event(event, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "with invalid attrs returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} = Events.update_event(event, %{name: ""})
      assert %{name: [_ | _]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # delete_event/1
  # ---------------------------------------------------------------------------

  describe "delete_event/1" do
    test "deletes the event" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, _} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end
  end

  # ---------------------------------------------------------------------------
  # publish_event/1
  # ---------------------------------------------------------------------------

  describe "publish_event/1" do
    test "on draft with catalog items succeeds" do
      org = org_fixture()
      event = event_fixture(org)
      catalog_item_fixture(event)

      assert {:ok, published} = Events.publish_event(event)
      assert published.status == "published"
    end

    test "on draft without catalog items returns :no_catalog_items error" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, :no_catalog_items} = Events.publish_event(event)
    end

    test "on already-published event returns :invalid_status error" do
      org = org_fixture()
      event = event_fixture(org)
      catalog_item_fixture(event)

      {:ok, published} = Events.publish_event(event)
      assert {:error, :invalid_status} = Events.publish_event(published)
    end
  end

  # ---------------------------------------------------------------------------
  # complete_event/1
  # ---------------------------------------------------------------------------

  describe "complete_event/1" do
    test "on published event succeeds" do
      org = org_fixture()
      event = event_fixture(org)
      catalog_item_fixture(event)

      {:ok, published} = Events.publish_event(event)
      assert {:ok, completed} = Events.complete_event(published)
      assert completed.status == "completed"
    end

    test "on draft event returns :invalid_status error" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, :invalid_status} = Events.complete_event(event)
    end
  end

  # ---------------------------------------------------------------------------
  # clone_event/1 and clone_event/2
  # ---------------------------------------------------------------------------

  describe "clone_event/1" do
    test "creates a new draft with same config" do
      org = org_fixture()
      event = event_fixture(org, %{name: "Original", venue: "Arena"})

      assert {:ok, clone} = Events.clone_event(event)
      assert clone.name == "Original (copy)"
      assert clone.venue == "Arena"
      assert clone.status == "draft"
      assert clone.id != event.id
    end

    test "with name attr uses the provided name" do
      org = org_fixture()
      event = event_fixture(org, %{name: "Original"})

      assert {:ok, clone} = Events.clone_event(event, %{name: "My Clone"})
      assert clone.name == "My Clone"
    end
  end
end
