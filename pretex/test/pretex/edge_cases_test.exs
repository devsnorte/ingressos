defmodule Pretex.EdgeCasesTest do
  use Pretex.DataCase, async: true

  alias Pretex.Organizations
  alias Pretex.Events
  alias Pretex.Catalog

  describe "organization edge cases" do
    test "create with very long name at boundary (100 chars)" do
      long_name = String.duplicate("a", 100)

      assert {:ok, org} =
               Organizations.create_organization(%{
                 name: long_name,
                 slug: "long-name-#{System.unique_integer([:positive])}"
               })

      assert String.length(org.name) == 100
    end

    test "create with name exceeding max length fails" do
      too_long = String.duplicate("a", 101)

      assert {:error, changeset} =
               Organizations.create_organization(%{
                 name: too_long,
                 slug: "too-long-#{System.unique_integer([:positive])}"
               })

      assert %{name: [_]} = errors_on(changeset)
    end

    test "slug with special characters fails validation" do
      assert {:error, changeset} =
               Organizations.create_organization(%{
                 name: "Test",
                 slug: "UPPER-case"
               })

      assert %{slug: [_]} = errors_on(changeset)
    end

    test "slug with leading hyphen fails validation" do
      assert {:error, changeset} =
               Organizations.create_organization(%{
                 name: "Test",
                 slug: "-leading-hyphen"
               })

      assert %{slug: [_]} = errors_on(changeset)
    end

    test "slug with trailing hyphen fails validation" do
      assert {:error, changeset} =
               Organizations.create_organization(%{
                 name: "Test",
                 slug: "trailing-hyphen-"
               })

      assert %{slug: [_]} = errors_on(changeset)
    end
  end

  describe "event status transitions" do
    test "cannot publish completed event" do
      {:ok, org} =
        Organizations.create_organization(%{
          name: "Status Org",
          slug: "status-#{System.unique_integer([:positive])}"
        })

      {:ok, event} =
        Events.create_event(org, %{
          name: "Status Event",
          slug: "status-event-#{System.unique_integer([:positive])}",
          starts_at: ~U[2030-06-01 10:00:00Z],
          ends_at: ~U[2030-06-01 18:00:00Z]
        })

      {:ok, _item} = Catalog.create_item(event, %{name: "Ticket", price_cents: 5000})
      {:ok, published} = Events.publish_event(event)
      {:ok, completed} = Events.complete_event(published)

      assert {:error, _} = Events.publish_event(completed)
    end

    test "cannot complete draft event" do
      {:ok, org} =
        Organizations.create_organization(%{
          name: "Draft Org",
          slug: "draft-#{System.unique_integer([:positive])}"
        })

      {:ok, event} =
        Events.create_event(org, %{
          name: "Draft Event",
          slug: "draft-event-#{System.unique_integer([:positive])}",
          starts_at: ~U[2030-06-01 10:00:00Z],
          ends_at: ~U[2030-06-01 18:00:00Z]
        })

      assert {:error, _} = Events.complete_event(event)
    end

    test "publish without catalog items fails" do
      {:ok, org} =
        Organizations.create_organization(%{
          name: "Empty Org",
          slug: "empty-#{System.unique_integer([:positive])}"
        })

      {:ok, event} =
        Events.create_event(org, %{
          name: "Empty Event",
          slug: "empty-event-#{System.unique_integer([:positive])}",
          starts_at: ~U[2030-06-01 10:00:00Z],
          ends_at: ~U[2030-06-01 18:00:00Z]
        })

      assert {:error, :no_catalog_items} = Events.publish_event(event)
    end
  end

  describe "catalog edge cases" do
    setup do
      {:ok, org} =
        Organizations.create_organization(%{
          name: "Catalog Edge Org",
          slug: "catalog-edge-#{System.unique_integer([:positive])}"
        })

      {:ok, event} =
        Events.create_event(org, %{
          name: "Catalog Event",
          slug: "catalog-event-#{System.unique_integer([:positive])}",
          starts_at: ~U[2030-06-01 10:00:00Z],
          ends_at: ~U[2030-06-01 18:00:00Z]
        })

      %{org: org, event: event}
    end

    test "item with zero price is valid", %{event: event} do
      assert {:ok, item} = Catalog.create_item(event, %{name: "Free Ticket", price_cents: 0})
      assert item.price_cents == 0
    end

    test "item with negative price fails", %{event: event} do
      assert {:error, changeset} =
               Catalog.create_item(event, %{name: "Negative", price_cents: -100})

      assert %{price_cents: [_]} = errors_on(changeset)
    end

    test "item without name fails", %{event: event} do
      assert {:error, changeset} = Catalog.create_item(event, %{price_cents: 5000})
      assert %{name: [_]} = errors_on(changeset)
    end

    test "count_items returns 0 for event with no items", %{event: event} do
      assert Catalog.count_items(event) == 0
    end

    test "count_items returns correct count after adding items", %{event: event} do
      {:ok, _} = Catalog.create_item(event, %{name: "Item 1", price_cents: 1000})
      {:ok, _} = Catalog.create_item(event, %{name: "Item 2", price_cents: 2000})
      assert Catalog.count_items(event) == 2
    end

    test "items are scoped to their event", %{org: org, event: event} do
      {:ok, other_event} =
        Events.create_event(org, %{
          name: "Other",
          slug: "other-#{System.unique_integer([:positive])}",
          starts_at: ~U[2030-06-01 10:00:00Z],
          ends_at: ~U[2030-06-01 18:00:00Z]
        })

      {:ok, _} = Catalog.create_item(event, %{name: "My Item", price_cents: 1000})
      {:ok, _} = Catalog.create_item(other_event, %{name: "Other Item", price_cents: 2000})

      assert Catalog.count_items(event) == 1
      assert Catalog.count_items(other_event) == 1
    end
  end
end
