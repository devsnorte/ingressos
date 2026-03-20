defmodule Pretex.QuotasTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Catalog
  alias Pretex.Catalog.Quota

  # ---------------------------------------------------------------------------
  # list_quotas/1
  # ---------------------------------------------------------------------------

  describe "list_quotas/1" do
    test "returns quotas ordered by name" do
      org = org_fixture()
      event = event_fixture(org)
      _q1 = quota_fixture(event, %{name: "Zebra Quota", capacity: 50})
      _q2 = quota_fixture(event, %{name: "Alpha Quota", capacity: 50})
      _q3 = quota_fixture(event, %{name: "Middle Quota", capacity: 50})

      quotas = Catalog.list_quotas(event)
      names = Enum.map(quotas, & &1.name)

      assert names == Enum.sort(names)
      assert length(quotas) == 3
    end

    test "returns empty list when no quotas exist" do
      org = org_fixture()
      event = event_fixture(org)

      assert Catalog.list_quotas(event) == []
    end

    test "does not return quotas from other events" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      quota = quota_fixture(event1, %{name: "Event 1 Quota"})

      result = Catalog.list_quotas(event2)
      ids = Enum.map(result, & &1.id)

      refute quota.id in ids
    end

    test "preloads quota_items" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item = item_fixture(event)
      {:ok, _} = Catalog.assign_item_to_quota(quota, item)

      [loaded_quota] = Catalog.list_quotas(event)

      assert length(loaded_quota.quota_items) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # get_quota!/1
  # ---------------------------------------------------------------------------

  describe "get_quota!/1" do
    test "returns the quota with given id" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "VIP Quota", capacity: 200})

      found = Catalog.get_quota!(quota.id)

      assert found.id == quota.id
      assert found.name == "VIP Quota"
      assert found.capacity == 200
    end

    test "preloads quota_items with item and item_variation" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item = item_fixture(event)
      {:ok, _} = Catalog.assign_item_to_quota(quota, item)

      found = Catalog.get_quota!(quota.id)

      assert length(found.quota_items) == 1
      [qi] = found.quota_items
      assert qi.item.id == item.id
    end

    test "raises Ecto.NoResultsError for missing id" do
      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_quota!(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_quota/2
  # ---------------------------------------------------------------------------

  describe "create_quota/2" do
    test "with valid attrs creates a quota" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, quota} =
               Catalog.create_quota(event, %{name: "Weekend Quota", capacity: 500})

      assert quota.name == "Weekend Quota"
      assert quota.capacity == 500
      assert quota.sold_count == 0
      assert quota.event_id == event.id
    end

    test "missing name returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} = Catalog.create_quota(event, %{capacity: 100})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "name too short returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} = Catalog.create_quota(event, %{name: "X", capacity: 100})
      assert %{name: [msg]} = errors_on(changeset)
      assert msg =~ "should be at least 2 character"
    end

    test "name too long returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      long_name = String.duplicate("a", 256)

      assert {:error, changeset} =
               Catalog.create_quota(event, %{name: long_name, capacity: 100})

      assert %{name: [msg]} = errors_on(changeset)
      assert msg =~ "should be at most 255 character"
    end

    test "capacity = 0 returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_quota(event, %{name: "Bad Quota", capacity: 0})

      assert %{capacity: [msg]} = errors_on(changeset)
      assert msg =~ "must be greater than 0"
    end

    test "negative capacity returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_quota(event, %{name: "Bad Quota", capacity: -10})

      assert %{capacity: [msg]} = errors_on(changeset)
      assert msg =~ "must be greater than 0"
    end

    test "missing capacity returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} = Catalog.create_quota(event, %{name: "No Cap Quota"})
      assert %{capacity: ["can't be blank"]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # update_quota/2
  # ---------------------------------------------------------------------------

  describe "update_quota/2" do
    test "with valid attrs updates the quota" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{name: "Old Name", capacity: 50})

      assert {:ok, updated} =
               Catalog.update_quota(quota, %{name: "New Name", capacity: 200})

      assert updated.name == "New Name"
      assert updated.capacity == 200
    end

    test "with invalid attrs returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)

      assert {:error, changeset} = Catalog.update_quota(quota, %{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "with capacity = 0 returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)

      assert {:error, changeset} = Catalog.update_quota(quota, %{capacity: 0})
      assert %{capacity: [msg]} = errors_on(changeset)
      assert msg =~ "must be greater than 0"
    end
  end

  # ---------------------------------------------------------------------------
  # delete_quota/1
  # ---------------------------------------------------------------------------

  describe "delete_quota/1" do
    test "deletes the quota" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)

      assert {:ok, _} = Catalog.delete_quota(quota)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_quota!(quota.id) end
    end

    test "deleting quota cascades to quota_items" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item = item_fixture(event)
      {:ok, _} = Catalog.assign_item_to_quota(quota, item)

      assert {:ok, _} = Catalog.delete_quota(quota)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_quota!(quota.id) end
    end
  end

  # ---------------------------------------------------------------------------
  # change_quota/2
  # ---------------------------------------------------------------------------

  describe "change_quota/2" do
    test "returns a changeset" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)

      assert %Ecto.Changeset{} = Catalog.change_quota(quota)
    end

    test "returns a changeset with defaults for empty struct" do
      assert %Ecto.Changeset{} = Catalog.change_quota(%Quota{})
    end
  end

  # ---------------------------------------------------------------------------
  # assign_item_to_quota/2
  # ---------------------------------------------------------------------------

  describe "assign_item_to_quota/2" do
    test "creates a quota_item linking the quota and item" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item = item_fixture(event)

      assert {:ok, quota_item} = Catalog.assign_item_to_quota(quota, item)
      assert quota_item.quota_id == quota.id
      assert quota_item.item_id == item.id
      assert is_nil(quota_item.item_variation_id)
    end

    test "allows assigning multiple items to the same quota" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item1 = item_fixture(event)
      item2 = item_fixture(event)

      assert {:ok, _} = Catalog.assign_item_to_quota(quota, item1)
      assert {:ok, _} = Catalog.assign_item_to_quota(quota, item2)

      loaded = Catalog.get_quota!(quota.id)
      assert length(loaded.quota_items) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # assign_variation_to_quota/2
  # ---------------------------------------------------------------------------

  describe "assign_variation_to_quota/2" do
    test "creates a quota_item linking the quota and variation" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item = item_fixture(event)
      variation = variation_fixture(item)

      assert {:ok, quota_item} = Catalog.assign_variation_to_quota(quota, variation)
      assert quota_item.quota_id == quota.id
      assert quota_item.item_variation_id == variation.id
      assert is_nil(quota_item.item_id)
    end
  end

  # ---------------------------------------------------------------------------
  # remove_item_from_quota/2
  # ---------------------------------------------------------------------------

  describe "remove_item_from_quota/2" do
    test "removes the quota_item for the given quota and item" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item = item_fixture(event)
      {:ok, _} = Catalog.assign_item_to_quota(quota, item)

      assert {:ok, _} = Catalog.remove_item_from_quota(quota, item)

      loaded = Catalog.get_quota!(quota.id)
      assert loaded.quota_items == []
    end

    test "returns error when assignment does not exist" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item = item_fixture(event)

      assert {:error, :not_found} = Catalog.remove_item_from_quota(quota, item)
    end
  end

  # ---------------------------------------------------------------------------
  # remove_variation_from_quota/2
  # ---------------------------------------------------------------------------

  describe "remove_variation_from_quota/2" do
    test "removes the quota_item for the given quota and variation" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item = item_fixture(event)
      variation = variation_fixture(item)
      {:ok, _} = Catalog.assign_variation_to_quota(quota, variation)

      assert {:ok, _} = Catalog.remove_variation_from_quota(quota, variation)

      loaded = Catalog.get_quota!(quota.id)
      assert loaded.quota_items == []
    end

    test "returns error when assignment does not exist" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event)
      item = item_fixture(event)
      variation = variation_fixture(item)

      assert {:error, :not_found} = Catalog.remove_variation_from_quota(quota, variation)
    end
  end

  # ---------------------------------------------------------------------------
  # available_quantity/1
  # ---------------------------------------------------------------------------

  describe "available_quantity/1" do
    test "returns full capacity when nothing sold" do
      quota = %Quota{capacity: 100, sold_count: 0}
      assert Catalog.available_quantity(quota) == 100
    end

    test "returns remaining capacity when partially sold" do
      quota = %Quota{capacity: 100, sold_count: 40}
      assert Catalog.available_quantity(quota) == 60
    end

    test "returns 0 when fully sold out" do
      quota = %Quota{capacity: 100, sold_count: 100}
      assert Catalog.available_quantity(quota) == 0
    end

    test "never returns negative even if sold_count exceeds capacity" do
      quota = %Quota{capacity: 100, sold_count: 110}
      assert Catalog.available_quantity(quota) == 0
    end

    test "works with freshly created quota" do
      org = org_fixture()
      event = event_fixture(org)
      quota = quota_fixture(event, %{capacity: 250})

      assert Catalog.available_quantity(quota) == 250
    end
  end

  # ---------------------------------------------------------------------------
  # sold_out?/1
  # ---------------------------------------------------------------------------

  describe "sold_out?/1" do
    test "returns false when quota has available capacity" do
      quota = %Quota{capacity: 100, sold_count: 50}
      refute Catalog.sold_out?(quota)
    end

    test "returns false when quota has not been touched" do
      quota = %Quota{capacity: 100, sold_count: 0}
      refute Catalog.sold_out?(quota)
    end

    test "returns true when quota is fully sold" do
      quota = %Quota{capacity: 100, sold_count: 100}
      assert Catalog.sold_out?(quota)
    end

    test "returns true when sold_count exceeds capacity" do
      quota = %Quota{capacity: 100, sold_count: 150}
      assert Catalog.sold_out?(quota)
    end

    test "returns true when capacity is 1 and sold_count is 1" do
      quota = %Quota{capacity: 1, sold_count: 1}
      assert Catalog.sold_out?(quota)
    end
  end
end
