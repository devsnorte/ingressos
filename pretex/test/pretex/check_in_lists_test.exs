defmodule Pretex.CheckInListsTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.CheckIns
  alias Pretex.CheckIns.{CheckInList, Gate}

  describe "check-in lists CRUD" do
    test "create_check_in_list/2 creates a list with items" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      assert {:ok, %CheckInList{} = list} =
               CheckIns.create_check_in_list(event.id, %{
                 name: "VIP Entrance",
                 item_ids: [item.id]
               })

      assert list.name == "VIP Entrance"
      list = Pretex.Repo.preload(list, :check_in_list_items)
      assert length(list.check_in_list_items) == 1
    end

    test "create_check_in_list/2 fails without items" do
      org = org_fixture()
      event = published_event_fixture(org)

      assert {:error, :no_items} =
               CheckIns.create_check_in_list(event.id, %{name: "Empty", item_ids: []})
    end

    test "create_check_in_list/2 with time restrictions" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      assert {:ok, list} =
               CheckIns.create_check_in_list(event.id, %{
                 name: "Morning Only",
                 item_ids: [item.id],
                 starts_at_time: ~T[08:00:00],
                 ends_at_time: ~T[10:00:00]
               })

      assert list.starts_at_time == ~T[08:00:00]
      assert list.ends_at_time == ~T[10:00:00]
    end

    test "list_check_in_lists/1 returns all lists for event" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      {:ok, _} = CheckIns.create_check_in_list(event.id, %{name: "List A", item_ids: [item.id]})
      {:ok, _} = CheckIns.create_check_in_list(event.id, %{name: "List B", item_ids: [item.id]})

      lists = CheckIns.list_check_in_lists(event.id)
      assert length(lists) == 2
    end

    test "update_check_in_list/2 updates name and items" do
      org = org_fixture()
      event = published_event_fixture(org)
      item1 = item_fixture(event)
      item2 = item_fixture(event)

      {:ok, list} = CheckIns.create_check_in_list(event.id, %{name: "Old", item_ids: [item1.id]})

      assert {:ok, updated} =
               CheckIns.update_check_in_list(list.id, %{name: "New", item_ids: [item2.id]})

      assert updated.name == "New"
      updated = Pretex.Repo.preload(updated, :check_in_list_items)
      assert length(updated.check_in_list_items) == 1
      assert hd(updated.check_in_list_items).item_id == item2.id
    end

    test "delete_check_in_list/1 removes list" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      {:ok, list} =
        CheckIns.create_check_in_list(event.id, %{name: "Delete Me", item_ids: [item.id]})

      assert {:ok, _} = CheckIns.delete_check_in_list(list.id)
      assert CheckIns.list_check_in_lists(event.id) == []
    end
  end

  describe "gates CRUD" do
    test "create_gate/2 creates a gate with check-in lists" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      {:ok, list} =
        CheckIns.create_check_in_list(event.id, %{name: "General", item_ids: [item.id]})

      assert {:ok, %Gate{} = gate} =
               CheckIns.create_gate(event.id, %{name: "North Door", check_in_list_ids: [list.id]})

      assert gate.name == "North Door"
      gate = Pretex.Repo.preload(gate, :check_in_lists)
      assert length(gate.check_in_lists) == 1
    end

    test "create_gate/2 fails without check-in lists" do
      org = org_fixture()
      event = published_event_fixture(org)

      assert {:error, :no_check_in_lists} =
               CheckIns.create_gate(event.id, %{name: "Empty Gate", check_in_list_ids: []})
    end

    test "list_gates/1 returns all gates for event" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      {:ok, list} =
        CheckIns.create_check_in_list(event.id, %{name: "General", item_ids: [item.id]})

      {:ok, _} = CheckIns.create_gate(event.id, %{name: "Gate A", check_in_list_ids: [list.id]})
      {:ok, _} = CheckIns.create_gate(event.id, %{name: "Gate B", check_in_list_ids: [list.id]})

      gates = CheckIns.list_gates(event.id)
      assert length(gates) == 2
    end

    test "delete_gate/1 removes gate" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      {:ok, list} =
        CheckIns.create_check_in_list(event.id, %{name: "General", item_ids: [item.id]})

      {:ok, gate} =
        CheckIns.create_gate(event.id, %{name: "Delete Me", check_in_list_ids: [list.id]})

      assert {:ok, _} = CheckIns.delete_gate(gate.id)
      assert CheckIns.list_gates(event.id) == []
    end
  end
end
