defmodule Pretex.CatalogTest do
  use Pretex.DataCase, async: true

  alias Pretex.Catalog
  alias Pretex.Events
  alias Pretex.Organizations

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp org_fixture(attrs \\ %{}) do
    {:ok, org} =
      attrs
      |> Enum.into(%{name: "Test Org", slug: "test-org-#{System.unique_integer([:positive])}"})
      |> Organizations.create_organization()

    org
  end

  defp event_fixture(org, attrs \\ %{}) do
    base = %{
      name: "My Event #{System.unique_integer([:positive])}",
      starts_at: ~U[2030-06-01 10:00:00Z],
      ends_at: ~U[2030-06-01 18:00:00Z],
      venue: "Main Stage"
    }

    {:ok, event} = Events.create_event(org, Enum.into(attrs, base))
    event
  end

  defp category_fixture(event, attrs \\ %{}) do
    {:ok, category} =
      Catalog.create_category(event, Enum.into(attrs, %{name: "General Category"}))

    category
  end

  defp item_fixture(event, attrs \\ %{}) do
    base = %{
      name: "Test Item #{System.unique_integer([:positive])}",
      price_cents: 1000,
      item_type: "ticket",
      status: "active"
    }

    {:ok, item} = Catalog.create_item(event, Enum.into(attrs, base))
    item
  end

  defp variation_fixture(item, attrs \\ %{}) do
    base = %{
      name: "Variation #{System.unique_integer([:positive])}",
      price_cents: 500,
      status: "active"
    }

    {:ok, variation} = Catalog.create_variation(item, Enum.into(attrs, base))
    variation
  end

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  describe "list_categories/1" do
    test "returns categories ordered by position" do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, c2} = Catalog.create_category(event, %{name: "Second", position: 2})
      {:ok, c1} = Catalog.create_category(event, %{name: "First", position: 1})

      categories = Catalog.list_categories(event)
      ids = Enum.map(categories, & &1.id)
      assert Enum.find_index(ids, &(&1 == c1.id)) < Enum.find_index(ids, &(&1 == c2.id))
    end

    test "returns empty list when no categories" do
      org = org_fixture()
      event = event_fixture(org)
      assert Catalog.list_categories(event) == []
    end

    test "does not return categories from other events" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      category_fixture(event1, %{name: "Event1 Category"})

      assert Catalog.list_categories(event2) == []
    end
  end

  describe "get_category!/1" do
    test "returns the category with given id" do
      org = org_fixture()
      event = event_fixture(org)
      category = category_fixture(event)

      assert Catalog.get_category!(category.id).id == category.id
    end

    test "raises for missing id" do
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_category!(0) end
    end
  end

  describe "create_category/2" do
    test "with valid attrs creates a category" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, category} = Catalog.create_category(event, %{name: "VIP", position: 1})
      assert category.name == "VIP"
      assert category.position == 1
      assert category.event_id == event.id
    end

    test "with empty name returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} = Catalog.create_category(event, %{name: ""})
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "with name too long returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      long_name = String.duplicate("a", 101)

      assert {:error, changeset} = Catalog.create_category(event, %{name: long_name})
      assert %{name: [_ | _]} = errors_on(changeset)
    end
  end

  describe "update_category/2" do
    test "with valid attrs updates the category" do
      org = org_fixture()
      event = event_fixture(org)
      category = category_fixture(event)

      assert {:ok, updated} = Catalog.update_category(category, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "with invalid attrs returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      category = category_fixture(event)

      assert {:error, changeset} = Catalog.update_category(category, %{name: ""})
      assert %{name: [_ | _]} = errors_on(changeset)
    end
  end

  describe "delete_category/1" do
    test "deletes the category" do
      org = org_fixture()
      event = event_fixture(org)
      category = category_fixture(event)

      assert {:ok, _} = Catalog.delete_category(category)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_category!(category.id) end
    end
  end

  describe "change_category/2" do
    test "returns a changeset" do
      org = org_fixture()
      event = event_fixture(org)
      category = category_fixture(event)

      assert %Ecto.Changeset{} = Catalog.change_category(category)
    end
  end

  # ---------------------------------------------------------------------------
  # Items
  # ---------------------------------------------------------------------------

  describe "list_items/1" do
    test "returns items ordered by name" do
      org = org_fixture()
      event = event_fixture(org)
      item_fixture(event, %{name: "Zebra Ticket"})
      item_fixture(event, %{name: "Alpha Ticket"})

      items = Catalog.list_items(event)
      names = Enum.map(items, & &1.name)
      assert names == Enum.sort(names)
    end

    test "returns empty list when no items" do
      org = org_fixture()
      event = event_fixture(org)
      assert Catalog.list_items(event) == []
    end

    test "preloads category and variations" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      _variation = variation_fixture(item)

      [fetched] = Catalog.list_items(event)
      assert %Pretex.Catalog.ItemVariation{} = hd(fetched.variations)
    end

    test "does not return items from other events" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      item_fixture(event1)

      assert Catalog.list_items(event2) == []
    end
  end

  describe "get_item!/1" do
    test "returns the item with given id" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert Catalog.get_item!(item.id).id == item.id
    end

    test "preloads category and variations" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      variation_fixture(item)

      fetched = Catalog.get_item!(item.id)
      assert is_list(fetched.variations)
      assert length(fetched.variations) == 1
    end

    test "raises for missing id" do
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_item!(0) end
    end
  end

  describe "create_item/2" do
    test "with valid attrs creates an item" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, item} =
               Catalog.create_item(event, %{
                 name: "General Admission",
                 price_cents: 5000,
                 item_type: "ticket",
                 status: "active"
               })

      assert item.name == "General Admission"
      assert item.price_cents == 5000
      assert item.item_type == "ticket"
      assert item.status == "active"
      assert item.event_id == event.id
    end

    test "with empty name returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_item(event, %{name: "", price_cents: 500, item_type: "ticket"})

      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "with name too short returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_item(event, %{name: "X", price_cents: 500, item_type: "ticket"})

      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "with negative price returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_item(event, %{
                 name: "Bad Item",
                 price_cents: -1,
                 item_type: "ticket"
               })

      assert %{price_cents: [_ | _]} = errors_on(changeset)
    end

    test "with invalid item_type returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_item(event, %{
                 name: "Bad Item",
                 price_cents: 100,
                 item_type: "unknown"
               })

      assert %{item_type: [_ | _]} = errors_on(changeset)
    end

    test "with invalid status returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_item(event, %{
                 name: "Bad Item",
                 price_cents: 100,
                 item_type: "ticket",
                 status: "pending"
               })

      assert %{status: [_ | _]} = errors_on(changeset)
    end

    test "accepts merchandise item_type" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, item} =
               Catalog.create_item(event, %{
                 name: "Event T-Shirt",
                 price_cents: 2500,
                 item_type: "merchandise"
               })

      assert item.item_type == "merchandise"
    end

    test "accepts addon item_type" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, item} =
               Catalog.create_item(event, %{
                 name: "Parking Pass",
                 price_cents: 1000,
                 item_type: "addon"
               })

      assert item.item_type == "addon"
    end
  end

  describe "update_item/2" do
    test "with valid attrs updates the item" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert {:ok, updated} = Catalog.update_item(item, %{name: "Updated Item Name"})
      assert updated.name == "Updated Item Name"
    end

    test "with invalid attrs returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert {:error, changeset} = Catalog.update_item(item, %{name: ""})
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "with negative price returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert {:error, changeset} = Catalog.update_item(item, %{price_cents: -10})
      assert %{price_cents: [_ | _]} = errors_on(changeset)
    end
  end

  describe "delete_item/1" do
    test "deletes the item" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert {:ok, _} = Catalog.delete_item(item)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_item!(item.id) end
    end
  end

  describe "change_item/2" do
    test "returns a changeset" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert %Ecto.Changeset{} = Catalog.change_item(item)
    end
  end

  # ---------------------------------------------------------------------------
  # Variations
  # ---------------------------------------------------------------------------

  describe "create_variation/2" do
    test "with valid attrs creates a variation" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert {:ok, variation} =
               Catalog.create_variation(item, %{
                 name: "Small",
                 price_cents: 800,
                 status: "active"
               })

      assert variation.name == "Small"
      assert variation.price_cents == 800
      assert variation.item_id == item.id
    end

    test "with empty name returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert {:error, changeset} =
               Catalog.create_variation(item, %{name: "", price_cents: 100})

      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "with negative price returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert {:error, changeset} =
               Catalog.create_variation(item, %{name: "Small", price_cents: -5})

      assert %{price_cents: [_ | _]} = errors_on(changeset)
    end

    test "with invalid status returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      assert {:error, changeset} =
               Catalog.create_variation(item, %{
                 name: "Small",
                 price_cents: 100,
                 status: "unknown"
               })

      assert %{status: [_ | _]} = errors_on(changeset)
    end
  end

  describe "update_variation/2" do
    test "with valid attrs updates the variation" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      variation = variation_fixture(item)

      assert {:ok, updated} = Catalog.update_variation(variation, %{name: "Large"})
      assert updated.name == "Large"
    end

    test "with invalid attrs returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      variation = variation_fixture(item)

      assert {:error, changeset} = Catalog.update_variation(variation, %{name: ""})
      assert %{name: [_ | _]} = errors_on(changeset)
    end
  end

  describe "delete_variation/1" do
    test "deletes the variation" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)
      variation = variation_fixture(item)

      assert {:ok, _} = Catalog.delete_variation(variation)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_variation!(variation.id) end
    end
  end

  # ---------------------------------------------------------------------------
  # Bundles
  # ---------------------------------------------------------------------------

  describe "create_bundle/2" do
    test "with valid attrs creates a bundle without items" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, bundle} =
               Catalog.create_bundle(event, %{
                 name: "Weekend Pass",
                 price_cents: 8000,
                 status: "active"
               })

      assert bundle.name == "Weekend Pass"
      assert bundle.price_cents == 8000
      assert bundle.event_id == event.id
      assert bundle.items == []
    end

    test "with item_ids creates a bundle with items" do
      org = org_fixture()
      event = event_fixture(org)
      item1 = item_fixture(event, %{name: "Item A"})
      item2 = item_fixture(event, %{name: "Item B"})

      assert {:ok, bundle} =
               Catalog.create_bundle(event, %{
                 name: "Combo Pack",
                 price_cents: 3000,
                 item_ids: [item1.id, item2.id]
               })

      assert length(bundle.items) == 2
      item_ids = Enum.map(bundle.items, & &1.id)
      assert item1.id in item_ids
      assert item2.id in item_ids
    end

    test "with empty name returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_bundle(event, %{name: "", price_cents: 1000})

      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "with negative price returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_bundle(event, %{name: "Bad Bundle", price_cents: -1})

      assert %{price_cents: [_ | _]} = errors_on(changeset)
    end
  end

  describe "get_bundle!/1" do
    test "returns the bundle with given id and preloads items" do
      org = org_fixture()
      event = event_fixture(org)
      {:ok, bundle} = Catalog.create_bundle(event, %{name: "My Bundle", price_cents: 1000})

      fetched = Catalog.get_bundle!(bundle.id)
      assert fetched.id == bundle.id
      assert is_list(fetched.items)
    end

    test "raises for missing id" do
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_bundle!(0) end
    end
  end

  # ---------------------------------------------------------------------------
  # Addon assignments
  # ---------------------------------------------------------------------------

  describe "assign_addon/2" do
    test "creates an addon assignment" do
      org = org_fixture()
      event = event_fixture(org)
      addon = item_fixture(event, %{name: "Parking Pass", item_type: "addon"})
      parent = item_fixture(event, %{name: "General Ticket"})

      assert {:ok, assignment} = Catalog.assign_addon(addon, parent)
      assert assignment.item_id == addon.id
      assert assignment.parent_item_id == parent.id
    end

    test "duplicate assignment returns error" do
      org = org_fixture()
      event = event_fixture(org)
      addon = item_fixture(event, %{name: "Parking Pass", item_type: "addon"})
      parent = item_fixture(event, %{name: "General Ticket"})

      {:ok, _} = Catalog.assign_addon(addon, parent)
      assert {:error, changeset} = Catalog.assign_addon(addon, parent)
      assert changeset.errors[:item_id] != nil or changeset.errors[:parent_item_id] != nil
    end
  end

  describe "remove_addon/2" do
    test "removes an existing addon assignment" do
      org = org_fixture()
      event = event_fixture(org)
      addon = item_fixture(event, %{name: "Parking Pass", item_type: "addon"})
      parent = item_fixture(event, %{name: "General Ticket"})

      {:ok, _} = Catalog.assign_addon(addon, parent)
      assert {:ok, _} = Catalog.remove_addon(addon, parent)

      addons = Catalog.list_addons_for_item(parent)
      assert addons == []
    end

    test "returns error when assignment does not exist" do
      org = org_fixture()
      event = event_fixture(org)
      addon = item_fixture(event, %{name: "Parking Pass", item_type: "addon"})
      parent = item_fixture(event, %{name: "General Ticket"})

      assert {:error, :not_found} = Catalog.remove_addon(addon, parent)
    end
  end

  describe "list_addons_for_item/1" do
    test "returns addon items assigned to parent" do
      org = org_fixture()
      event = event_fixture(org)
      addon1 = item_fixture(event, %{name: "Parking Pass", item_type: "addon"})
      addon2 = item_fixture(event, %{name: "Meal Voucher", item_type: "addon"})
      parent = item_fixture(event, %{name: "General Ticket"})

      {:ok, _} = Catalog.assign_addon(addon1, parent)
      {:ok, _} = Catalog.assign_addon(addon2, parent)

      addons = Catalog.list_addons_for_item(parent)
      assert length(addons) == 2
      addon_ids = Enum.map(addons, & &1.id)
      assert addon1.id in addon_ids
      assert addon2.id in addon_ids
    end

    test "returns empty list when no addons assigned" do
      org = org_fixture()
      event = event_fixture(org)
      parent = item_fixture(event, %{name: "General Ticket"})

      assert Catalog.list_addons_for_item(parent) == []
    end
  end
end
