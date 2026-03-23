defmodule Pretex.CheckInsTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures
  import Pretex.AccountsFixtures

  alias Pretex.CheckIns
  alias Pretex.CheckIns.CheckIn
  alias Pretex.Orders

  defp confirmed_order_fixture(event) do
    {:ok, cart} = Orders.create_cart(event)
    cart = Orders.get_cart_by_token(cart.session_token)
    item = item_fixture(event)

    {:ok, _} = Orders.add_to_cart(cart, item)
    cart = Orders.get_cart_by_token(cart.session_token)

    {:ok, order} =
      Orders.create_order_from_cart(cart, %{
        name: "Jane Doe",
        email: "jane@example.com",
        payment_method: "pix"
      })

    {:ok, order} = Orders.confirm_order(order)
    Orders.get_order!(order.id)
  end

  describe "check_in_by_ticket_code/3" do
    test "checks in an attendee with a valid ticket code" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      assert {:ok, %CheckIn{} = check_in} =
               CheckIns.check_in_by_ticket_code(event.id, order_item.ticket_code, operator.id)

      assert check_in.order_item_id == order_item.id
      assert check_in.event_id == event.id
      assert check_in.checked_in_by_id == operator.id
      assert check_in.checked_in_at != nil
      assert check_in.annulled_at == nil
    end

    test "returns :invalid_ticket for unknown ticket code" do
      org = org_fixture()
      event = published_event_fixture(org)
      operator = user_fixture()

      assert {:error, :invalid_ticket} =
               CheckIns.check_in_by_ticket_code(event.id, "ZZZZZZZZ", operator.id)
    end

    test "returns :wrong_event when ticket belongs to different event" do
      org = org_fixture()
      event1 = published_event_fixture(org)
      event2 = published_event_fixture(org)
      order = confirmed_order_fixture(event1)
      operator = user_fixture()
      [order_item | _] = order.order_items

      assert {:error, :wrong_event} =
               CheckIns.check_in_by_ticket_code(event2.id, order_item.ticket_code, operator.id)
    end

    test "returns :ticket_cancelled when order is cancelled" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      {:ok, _} = Orders.cancel_order(order)
      operator = user_fixture()
      [order_item | _] = order.order_items

      assert {:error, :ticket_cancelled} =
               CheckIns.check_in_by_ticket_code(event.id, order_item.ticket_code, operator.id)
    end

    test "returns :already_checked_in on duplicate check-in" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      assert {:ok, _} =
               CheckIns.check_in_by_ticket_code(event.id, order_item.ticket_code, operator.id)

      assert {:error, :already_checked_in} =
               CheckIns.check_in_by_ticket_code(event.id, order_item.ticket_code, operator.id)
    end

    test "allows re-check-in after annulment when multi_entry is enabled" do
      org = org_fixture()
      event = published_event_fixture(org, %{multi_entry: true})
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      assert {:ok, ci1} =
               CheckIns.check_in_by_ticket_code(event.id, order_item.ticket_code, operator.id)

      assert {:ok, _} = CheckIns.annul_check_in(ci1.id, operator.id)

      assert {:ok, _ci2} =
               CheckIns.check_in_by_ticket_code(event.id, order_item.ticket_code, operator.id)
    end
  end

  describe "annul_check_in/2" do
    test "annuls an active check-in" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      {:ok, check_in} =
        CheckIns.check_in_by_ticket_code(event.id, order_item.ticket_code, operator.id)

      assert {:ok, annulled} = CheckIns.annul_check_in(check_in.id, operator.id)
      assert annulled.annulled_at != nil
      assert annulled.annulled_by_id == operator.id
    end

    test "returns error for already-annulled check-in" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      {:ok, check_in} =
        CheckIns.check_in_by_ticket_code(event.id, order_item.ticket_code, operator.id)

      {:ok, _} = CheckIns.annul_check_in(check_in.id, operator.id)

      assert {:error, :already_annulled} = CheckIns.annul_check_in(check_in.id, operator.id)
    end
  end

  describe "search_attendees/2" do
    test "finds attendees by name" do
      org = org_fixture()
      event = published_event_fixture(org)
      _order = confirmed_order_fixture(event)

      results = CheckIns.search_attendees(event.id, "Jane")
      assert length(results) > 0
      result = hd(results)
      # Match found via order_item.attendee_name or order.name
      name = result.attendee_name || result.order.name
      assert name =~ "Jane"
    end

    test "returns empty list when no match" do
      org = org_fixture()
      event = published_event_fixture(org)
      _order = confirmed_order_fixture(event)

      assert [] = CheckIns.search_attendees(event.id, "NOMATCH12345")
    end
  end

  describe "get_check_in_count/1" do
    test "counts active (non-annulled) check-ins" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      assert CheckIns.get_check_in_count(event.id) == 0

      {:ok, check_in} =
        CheckIns.check_in_by_ticket_code(event.id, order_item.ticket_code, operator.id)

      assert CheckIns.get_check_in_count(event.id) == 1

      {:ok, _} = CheckIns.annul_check_in(check_in.id, operator.id)
      assert CheckIns.get_check_in_count(event.id) == 0
    end
  end

  describe "check_in_by_ticket_code/4 with check_in_list" do
    test "checks in on a specific list" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      {:ok, list} =
        CheckIns.create_check_in_list(event.id, %{
          name: "Main Hall",
          item_ids: [order_item.item_id]
        })

      assert {:ok, check_in} =
               CheckIns.check_in_by_ticket_code(
                 event.id,
                 order_item.ticket_code,
                 operator.id,
                 list.id
               )

      assert check_in.check_in_list_id == list.id
    end

    test "same ticket can be checked in on different lists independently" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      {:ok, list1} =
        CheckIns.create_check_in_list(event.id, %{name: "Hall A", item_ids: [order_item.item_id]})

      {:ok, list2} =
        CheckIns.create_check_in_list(event.id, %{name: "Hall B", item_ids: [order_item.item_id]})

      assert {:ok, _} =
               CheckIns.check_in_by_ticket_code(
                 event.id,
                 order_item.ticket_code,
                 operator.id,
                 list1.id
               )

      assert {:ok, _} =
               CheckIns.check_in_by_ticket_code(
                 event.id,
                 order_item.ticket_code,
                 operator.id,
                 list2.id
               )
    end

    test "returns :not_on_list when ticket item is not in check-in list" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items
      other_item = item_fixture(event, %{name: "VIP Only"})

      {:ok, list} =
        CheckIns.create_check_in_list(event.id, %{name: "VIP", item_ids: [other_item.id]})

      assert {:error, :not_on_list} =
               CheckIns.check_in_by_ticket_code(
                 event.id,
                 order_item.ticket_code,
                 operator.id,
                 list.id
               )
    end

    test "returns :list_not_active when outside time window" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      {:ok, list} =
        CheckIns.create_check_in_list(event.id, %{
          name: "Morning",
          item_ids: [order_item.item_id],
          starts_at_time: ~T[01:00:00],
          ends_at_time: ~T[01:01:00]
        })

      assert {:error, :list_not_active} =
               CheckIns.check_in_by_ticket_code(
                 event.id,
                 order_item.ticket_code,
                 operator.id,
                 list.id
               )
    end
  end

  describe "check_in_at_gate/4" do
    test "checks in via gate on matching list" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      {:ok, list} =
        CheckIns.create_check_in_list(event.id, %{name: "General", item_ids: [order_item.item_id]})

      {:ok, gate} =
        CheckIns.create_gate(event.id, %{name: "North Door", check_in_list_ids: [list.id]})

      assert {:ok, check_in} =
               CheckIns.check_in_at_gate(event.id, order_item.ticket_code, operator.id, gate.id)

      assert check_in.check_in_list_id == list.id
    end

    test "returns :not_on_list when ticket doesn't match any gate list" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items
      other_item = item_fixture(event, %{name: "VIP Only"})

      {:ok, list} =
        CheckIns.create_check_in_list(event.id, %{name: "VIP", item_ids: [other_item.id]})

      {:ok, gate} =
        CheckIns.create_gate(event.id, %{name: "VIP Door", check_in_list_ids: [list.id]})

      assert {:error, :not_on_list} =
               CheckIns.check_in_at_gate(event.id, order_item.ticket_code, operator.id, gate.id)
    end
  end
end
