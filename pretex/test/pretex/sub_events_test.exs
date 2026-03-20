defmodule Pretex.SubEventsTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures

  alias Pretex.Events
  alias Pretex.Events.SubEvent

  defp sub_event_fixture(event, attrs \\ %{}) do
    base = %{
      name: "Sub Event #{System.unique_integer([:positive])}",
      starts_at: ~U[2030-06-01 10:00:00Z],
      ends_at: ~U[2030-06-01 12:00:00Z],
      venue: "Room A"
    }

    {:ok, sub_event} = Events.create_sub_event(event, Enum.into(attrs, base))
    sub_event
  end

  # ---------------------------------------------------------------------------
  # enable_series/1
  # ---------------------------------------------------------------------------

  describe "enable_series/1" do
    test "sets is_series to true on the event" do
      org = org_fixture()
      event = event_fixture(org)
      assert event.is_series == false

      assert {:ok, updated} = Events.enable_series(event)
      assert updated.is_series == true
    end
  end

  # ---------------------------------------------------------------------------
  # disable_series/1
  # ---------------------------------------------------------------------------

  describe "disable_series/1" do
    test "sets is_series to false on the event" do
      org = org_fixture()
      event = event_fixture(org)
      {:ok, event} = Events.enable_series(event)
      assert event.is_series == true

      assert {:ok, updated} = Events.disable_series(event)
      assert updated.is_series == false
    end
  end

  # ---------------------------------------------------------------------------
  # list_sub_events/1
  # ---------------------------------------------------------------------------

  describe "list_sub_events/1" do
    test "returns sub-events for the given parent event" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      results = Events.list_sub_events(event)
      assert Enum.any?(results, &(&1.id == sub_event.id))
    end

    test "does not return sub-events from a different parent event" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      sub_event_fixture(event1)

      assert Events.list_sub_events(event2) == []
    end

    test "returns an empty list when the event has no sub-events" do
      org = org_fixture()
      event = event_fixture(org)

      assert Events.list_sub_events(event) == []
    end
  end

  # ---------------------------------------------------------------------------
  # get_sub_event!/1
  # ---------------------------------------------------------------------------

  describe "get_sub_event!/1" do
    test "returns the sub-event with the given id" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      found = Events.get_sub_event!(sub_event.id)
      assert found.id == sub_event.id
    end

    test "raises Ecto.NoResultsError for a missing id" do
      assert_raise Ecto.NoResultsError, fn -> Events.get_sub_event!(0) end
    end
  end

  # ---------------------------------------------------------------------------
  # create_sub_event/2
  # ---------------------------------------------------------------------------

  describe "create_sub_event/2" do
    test "with valid attrs creates a draft sub-event" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, %SubEvent{} = sub_event} =
               Events.create_sub_event(event, %{
                 name: "Morning Session",
                 starts_at: ~U[2030-06-01 09:00:00Z],
                 ends_at: ~U[2030-06-01 11:00:00Z]
               })

      assert sub_event.name == "Morning Session"
      assert sub_event.status == "draft"
      assert sub_event.parent_event_id == event.id
      assert sub_event.slug == "morning-session"
    end

    test "auto-generates slug from name" do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, sub_event} = Events.create_sub_event(event, %{name: "Day One Keynote!"})
      assert sub_event.slug == "day-one-keynote"
    end

    test "with missing name returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} = Events.create_sub_event(event, %{})
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "with name shorter than 2 chars returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} = Events.create_sub_event(event, %{name: "A"})
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "with ends_at before starts_at returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Events.create_sub_event(event, %{
                 name: "Bad Dates",
                 starts_at: ~U[2030-06-01 12:00:00Z],
                 ends_at: ~U[2030-06-01 10:00:00Z]
               })

      assert %{ends_at: [_ | _]} = errors_on(changeset)
    end

    test "with invalid status returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Events.create_sub_event(event, %{name: "Test", status: "invalid"})

      assert %{status: [_ | _]} = errors_on(changeset)
    end

    test "duplicate slug within same parent event returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _} = Events.create_sub_event(event, %{name: "Same Name"})

      assert {:error, changeset} = Events.create_sub_event(event, %{name: "Same Name"})
      assert %{slug: [_ | _]} = errors_on(changeset)
    end

    test "same slug is allowed on different parent events" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)

      assert {:ok, _} = Events.create_sub_event(event1, %{name: "Same Name"})
      assert {:ok, _} = Events.create_sub_event(event2, %{name: "Same Name"})
    end
  end

  # ---------------------------------------------------------------------------
  # update_sub_event/2
  # ---------------------------------------------------------------------------

  describe "update_sub_event/2" do
    test "with valid attrs updates the sub-event" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      assert {:ok, updated} = Events.update_sub_event(sub_event, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
      assert updated.slug == "updated-name"
    end

    test "with invalid attrs returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      assert {:error, changeset} = Events.update_sub_event(sub_event, %{name: ""})
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "does not change slug when name is not updated" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event, %{name: "Original Name"})
      original_slug = sub_event.slug

      assert {:ok, updated} = Events.update_sub_event(sub_event, %{venue: "New Venue"})
      assert updated.slug == original_slug
    end
  end

  # ---------------------------------------------------------------------------
  # delete_sub_event/1
  # ---------------------------------------------------------------------------

  describe "delete_sub_event/1" do
    test "deletes the sub-event" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      assert {:ok, _} = Events.delete_sub_event(sub_event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_sub_event!(sub_event.id) end
    end
  end

  # ---------------------------------------------------------------------------
  # change_sub_event/2
  # ---------------------------------------------------------------------------

  describe "change_sub_event/2" do
    test "returns a changeset for a new sub-event" do
      assert %Ecto.Changeset{} = Events.change_sub_event(%SubEvent{})
    end

    test "returns a changeset with applied attrs" do
      changeset = Events.change_sub_event(%SubEvent{}, %{name: "Hello"})
      assert changeset.changes.name == "Hello"
    end
  end

  # ---------------------------------------------------------------------------
  # publish_sub_event/1
  # ---------------------------------------------------------------------------

  describe "publish_sub_event/1" do
    test "publishes a draft sub-event" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      assert sub_event.status == "draft"
      assert {:ok, published} = Events.publish_sub_event(sub_event)
      assert published.status == "published"
    end

    test "returns :invalid_status when sub-event is already published" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      {:ok, published} = Events.publish_sub_event(sub_event)
      assert {:error, :invalid_status} = Events.publish_sub_event(published)
    end

    test "returns :invalid_status when sub-event is hidden" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      {:ok, published} = Events.publish_sub_event(sub_event)
      {:ok, hidden} = Events.hide_sub_event(published)
      assert {:error, :invalid_status} = Events.publish_sub_event(hidden)
    end
  end

  # ---------------------------------------------------------------------------
  # hide_sub_event/1
  # ---------------------------------------------------------------------------

  describe "hide_sub_event/1" do
    test "hides a draft sub-event" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      assert {:ok, hidden} = Events.hide_sub_event(sub_event)
      assert hidden.status == "hidden"
    end

    test "hides a published sub-event" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      {:ok, published} = Events.publish_sub_event(sub_event)
      assert {:ok, hidden} = Events.hide_sub_event(published)
      assert hidden.status == "hidden"
    end

    test "returns :invalid_status when sub-event is already hidden" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      {:ok, hidden} = Events.hide_sub_event(sub_event)
      assert {:error, :invalid_status} = Events.hide_sub_event(hidden)
    end
  end

  # ---------------------------------------------------------------------------
  # cascade delete: deleting parent event removes sub-events
  # ---------------------------------------------------------------------------

  describe "cascade delete" do
    test "deleting the parent event also deletes its sub-events" do
      org = org_fixture()
      event = event_fixture(org)
      sub_event = sub_event_fixture(event)

      {:ok, _} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_sub_event!(sub_event.id) end
    end
  end
end
