defmodule Pretex.OrderManagementTest do
  use Pretex.DataCase, async: true

  alias Pretex.Orders
  alias Pretex.Orders.Order

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp order_fixture(event, attrs \\ %{}) do
    base = %{
      name: "João Silva #{System.unique_integer([:positive])}",
      email: "joao#{System.unique_integer([:positive])}@example.com",
      payment_method: "pix",
      status: "pending",
      total_cents: 5000,
      confirmation_code: :crypto.strong_rand_bytes(3) |> Base.encode16(),
      expires_at:
        DateTime.utc_now()
        |> DateTime.add(30 * 60, :second)
        |> DateTime.truncate(:second)
    }

    attrs = Map.merge(base, attrs)

    %Order{}
    |> Order.changeset(attrs)
    |> Ecto.Changeset.put_change(:event_id, event.id)
    |> Ecto.Changeset.put_change(:status, attrs[:status] || "pending")
    |> Ecto.Changeset.put_change(:total_cents, attrs[:total_cents] || 5000)
    |> Ecto.Changeset.put_change(:confirmation_code, attrs[:confirmation_code])
    |> Ecto.Changeset.put_change(:expires_at, attrs[:expires_at])
    |> Pretex.Repo.insert!()
  end

  defp confirmed_order_fixture(event, attrs \\ %{}) do
    order_fixture(event, Map.merge(%{status: "confirmed"}, attrs))
  end

  # ---------------------------------------------------------------------------
  # search_orders_for_event/2
  # ---------------------------------------------------------------------------

  describe "search_orders_for_event/2" do
    setup do
      org = org_fixture()
      event = event_fixture(org)
      %{org: org, event: event}
    end

    test "returns all orders when no filters", %{event: event} do
      order1 = order_fixture(event, %{name: "Alice"})
      order2 = order_fixture(event, %{name: "Bob"})

      results = Orders.search_orders_for_event(event)
      ids = Enum.map(results, & &1.id)

      assert order1.id in ids
      assert order2.id in ids
    end

    test "returns empty list when event has no orders", %{event: event} do
      assert Orders.search_orders_for_event(event) == []
    end

    test "does not return orders from other events", %{event: event} do
      org2 = org_fixture()
      other_event = event_fixture(org2)
      _other_order = order_fixture(other_event, %{name: "Carlos"})

      assert Orders.search_orders_for_event(event) == []
    end

    test "filters by name using search term", %{event: event} do
      alice = order_fixture(event, %{name: "Alice Souza"})
      _bob = order_fixture(event, %{name: "Bob Ferreira"})

      results = Orders.search_orders_for_event(event, search: "alice")
      assert length(results) == 1
      assert hd(results).id == alice.id
    end

    test "filters by email using search term", %{event: event} do
      target = order_fixture(event, %{email: "special@test.com", name: "Target User"})
      _other = order_fixture(event, %{email: "other@example.com", name: "Other User"})

      results = Orders.search_orders_for_event(event, search: "special@test")
      assert length(results) == 1
      assert hd(results).id == target.id
    end

    test "search is case insensitive", %{event: event} do
      order = order_fixture(event, %{name: "Maria Joaquina"})

      results = Orders.search_orders_for_event(event, search: "MARIA")
      assert Enum.any?(results, &(&1.id == order.id))
    end

    test "filters by status", %{event: event} do
      confirmed = order_fixture(event, %{status: "confirmed"})
      _pending = order_fixture(event, %{status: "pending"})

      results = Orders.search_orders_for_event(event, status: "confirmed")
      assert length(results) == 1
      assert hd(results).id == confirmed.id
    end

    test "filters by both search and status", %{event: event} do
      match =
        order_fixture(event, %{name: "Alice Lima", status: "confirmed"})

      _wrong_status = order_fixture(event, %{name: "Alice Lima", status: "pending"})
      _wrong_name = order_fixture(event, %{name: "Bob Lima", status: "confirmed"})

      results = Orders.search_orders_for_event(event, search: "alice", status: "confirmed")
      assert length(results) == 1
      assert hd(results).id == match.id
    end

    test "returns empty list when no orders match filters", %{event: event} do
      _order = order_fixture(event, %{name: "Alice"})

      results = Orders.search_orders_for_event(event, search: "nonexistent_xyz")
      assert results == []
    end

    test "preloads order_items with item and item_variation", %{event: event} do
      _order = order_fixture(event)

      [result | _] = Orders.search_orders_for_event(event)

      assert %Ecto.Association.NotLoaded{} != result.order_items
      assert is_list(result.order_items)
    end
  end

  # ---------------------------------------------------------------------------
  # get_order_with_details!/1
  # ---------------------------------------------------------------------------

  describe "get_order_with_details!/1" do
    setup do
      org = org_fixture()
      event = event_fixture(org)
      %{org: org, event: event}
    end

    test "returns order with preloaded associations", %{event: event} do
      order = order_fixture(event)

      result = Orders.get_order_with_details!(order.id)

      assert result.id == order.id
      assert is_list(result.order_items)

      # event must be preloaded
      assert %Pretex.Events.Event{} = result.event
      assert result.event.id == event.id
    end

    test "raises when order not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Orders.get_order_with_details!(999_999_999)
      end
    end

    test "preloads order_items with item, item_variation, and answers", %{event: event} do
      item = item_fixture(event)
      order = order_fixture(event)

      # Insert an order_item manually
      %Pretex.Orders.OrderItem{}
      |> Pretex.Orders.OrderItem.changeset(%{quantity: 1, unit_price_cents: 5000})
      |> Ecto.Changeset.put_change(:order_id, order.id)
      |> Ecto.Changeset.put_change(:item_id, item.id)
      |> Ecto.Changeset.put_change(:ticket_code, "TESTCODE")
      |> Pretex.Repo.insert!()

      result = Orders.get_order_with_details!(order.id)

      assert length(result.order_items) == 1
      [oi] = result.order_items
      assert %Pretex.Catalog.Item{} = oi.item
      assert is_list(oi.answers)
    end
  end

  # ---------------------------------------------------------------------------
  # lock_order_for_editing/1
  # ---------------------------------------------------------------------------

  describe "lock_order_for_editing/1" do
    setup do
      org = org_fixture()
      event = event_fixture(org)
      %{org: org, event: event}
    end

    test "sets locked_by_organizer to true", %{event: event} do
      order = order_fixture(event)
      refute order.locked_by_organizer

      assert {:ok, updated} = Orders.lock_order_for_editing(order)
      assert updated.locked_by_organizer == true
    end

    test "persists the change in the database", %{event: event} do
      order = order_fixture(event)
      {:ok, _} = Orders.lock_order_for_editing(order)

      reloaded = Pretex.Repo.get!(Order, order.id)
      assert reloaded.locked_by_organizer == true
    end
  end

  # ---------------------------------------------------------------------------
  # unlock_order/1
  # ---------------------------------------------------------------------------

  describe "unlock_order/1" do
    setup do
      org = org_fixture()
      event = event_fixture(org)
      %{org: org, event: event}
    end

    test "sets locked_by_organizer to false", %{event: event} do
      order = order_fixture(event)
      {:ok, locked} = Orders.lock_order_for_editing(order)
      assert locked.locked_by_organizer == true

      assert {:ok, unlocked} = Orders.unlock_order(locked)
      assert unlocked.locked_by_organizer == false
    end

    test "persists the change in the database", %{event: event} do
      order = order_fixture(event)
      {:ok, locked} = Orders.lock_order_for_editing(order)
      {:ok, _} = Orders.unlock_order(locked)

      reloaded = Pretex.Repo.get!(Order, order.id)
      assert reloaded.locked_by_organizer == false
    end
  end

  # ---------------------------------------------------------------------------
  # update_order_attendee_info/2
  # ---------------------------------------------------------------------------

  describe "update_order_attendee_info/2" do
    setup do
      org = org_fixture()
      event = event_fixture(org)
      %{org: org, event: event}
    end

    test "updates name and email", %{event: event} do
      order = order_fixture(event, %{name: "Old Name", email: "old@example.com"})

      assert {:ok, updated} =
               Orders.update_order_attendee_info(order, %{
                 name: "New Name",
                 email: "new@example.com"
               })

      assert updated.name == "New Name"
      assert updated.email == "new@example.com"
    end

    test "returns error changeset when name is too short", %{event: event} do
      order = order_fixture(event)

      assert {:error, changeset} =
               Orders.update_order_attendee_info(order, %{name: "X"})

      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "returns error changeset with invalid email", %{event: event} do
      order = order_fixture(event)

      assert {:error, changeset} =
               Orders.update_order_attendee_info(order, %{email: "not-an-email"})

      assert %{email: [_ | _]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # resend_ticket_email/1
  # ---------------------------------------------------------------------------

  describe "resend_ticket_email/1" do
    setup do
      org = org_fixture()
      event = event_fixture(org)
      %{org: org, event: event}
    end

    test "returns {:ok, :sent} for a confirmed order", %{event: event} do
      order = confirmed_order_fixture(event)
      assert {:ok, :sent} = Orders.resend_ticket_email(order)
    end

    test "returns {:error, :not_confirmed} for a pending order", %{event: event} do
      order = order_fixture(event, %{status: "pending"})
      assert {:error, :not_confirmed} = Orders.resend_ticket_email(order)
    end

    test "returns {:error, :not_confirmed} for a cancelled order", %{event: event} do
      order = order_fixture(event, %{status: "cancelled"})
      assert {:error, :not_confirmed} = Orders.resend_ticket_email(order)
    end

    test "returns {:error, :not_confirmed} for an expired order", %{event: event} do
      order = order_fixture(event, %{status: "expired"})
      assert {:error, :not_confirmed} = Orders.resend_ticket_email(order)
    end
  end

  # ---------------------------------------------------------------------------
  # create_manual_order/2
  # ---------------------------------------------------------------------------

  describe "create_manual_order/2" do
    setup do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{name: "VIP Ticket", price_cents: 10_000})
      %{org: org, event: event, item: item}
    end

    test "creates an order with status 'paid'", %{event: event, item: item} do
      attrs = %{
        name: "Maria Oliveira",
        email: "maria@example.com",
        status: "paid",
        items: [%{item_id: item.id, quantity: 2, unit_price_cents: 10_000}]
      }

      assert {:ok, order} = Orders.create_manual_order(event, attrs)
      assert order.name == "Maria Oliveira"
      assert order.email == "maria@example.com"
      assert order.status == "paid"
      assert order.total_cents == 20_000
      assert order.event_id == event.id
      assert is_binary(order.confirmation_code)
      assert order.confirmation_code != ""
    end

    test "creates an order with status 'comp'", %{event: event, item: item} do
      attrs = %{
        name: "Carlos Cortesia",
        email: "carlos@example.com",
        status: "comp",
        items: [%{item_id: item.id, quantity: 1, unit_price_cents: 0}]
      }

      assert {:ok, order} = Orders.create_manual_order(event, attrs)
      assert order.status == "comp"
      assert order.total_cents == 0
    end

    test "creates order items with ticket codes", %{event: event, item: item} do
      attrs = %{
        name: "Pedro",
        email: "pedro@example.com",
        status: "paid",
        items: [%{item_id: item.id, quantity: 1, unit_price_cents: 5000}]
      }

      assert {:ok, order} = Orders.create_manual_order(event, attrs)
      assert length(order.order_items) == 1

      [oi] = order.order_items
      assert oi.quantity == 1
      assert oi.unit_price_cents == 5000
      assert is_binary(oi.ticket_code)
      assert oi.ticket_code != ""
    end

    test "sets total_cents as sum of quantity * unit_price_cents", %{event: event, item: item} do
      item2 = item_fixture(event, %{name: "Regular Ticket", price_cents: 3000})

      attrs = %{
        name: "Ana",
        email: "ana@example.com",
        status: "paid",
        items: [
          %{item_id: item.id, quantity: 2, unit_price_cents: 10_000},
          %{item_id: item2.id, quantity: 3, unit_price_cents: 3000}
        ]
      }

      assert {:ok, order} = Orders.create_manual_order(event, attrs)
      # 2 * 10000 + 3 * 3000 = 20000 + 9000 = 29000
      assert order.total_cents == 29_000
    end

    test "creates multiple order items", %{event: event, item: item} do
      item2 = item_fixture(event, %{name: "Regular Ticket", price_cents: 3000})

      attrs = %{
        name: "Felipe",
        email: "felipe@example.com",
        status: "paid",
        items: [
          %{item_id: item.id, quantity: 1, unit_price_cents: 10_000},
          %{item_id: item2.id, quantity: 2, unit_price_cents: 3000}
        ]
      }

      assert {:ok, order} = Orders.create_manual_order(event, attrs)
      assert length(order.order_items) == 2
    end

    test "does not require items list and creates order with zero total", %{event: event} do
      attrs = %{
        name: "Fernanda",
        email: "fernanda@example.com",
        status: "comp",
        items: []
      }

      assert {:ok, order} = Orders.create_manual_order(event, attrs)
      assert order.total_cents == 0
      assert order.order_items == []
    end

    test "returns error when name is missing", %{event: event, item: item} do
      attrs = %{
        email: "test@example.com",
        status: "paid",
        items: [%{item_id: item.id, quantity: 1, unit_price_cents: 5000}]
      }

      assert {:error, _changeset} = Orders.create_manual_order(event, attrs)
    end

    test "returns error when email is invalid", %{event: event, item: item} do
      attrs = %{
        name: "Test User",
        email: "not-an-email",
        status: "paid",
        items: [%{item_id: item.id, quantity: 1, unit_price_cents: 5000}]
      }

      assert {:error, _changeset} = Orders.create_manual_order(event, attrs)
    end

    test "generates a unique confirmation_code per order", %{event: event, item: item} do
      attrs = fn ->
        %{
          name: "User #{System.unique_integer([:positive])}",
          email: "user#{System.unique_integer([:positive])}@example.com",
          status: "paid",
          items: [%{item_id: item.id, quantity: 1, unit_price_cents: 5000}]
        }
      end

      {:ok, order1} = Orders.create_manual_order(event, attrs.())
      {:ok, order2} = Orders.create_manual_order(event, attrs.())

      assert order1.confirmation_code != order2.confirmation_code
    end

    test "works with string keys in attrs", %{event: event, item: item} do
      attrs = %{
        "name" => "String Keys User",
        "email" => "stringkeys@example.com",
        "status" => "paid",
        "items" => [
          %{"item_id" => to_string(item.id), "quantity" => "1", "unit_price_cents" => "5000"}
        ]
      }

      assert {:ok, order} = Orders.create_manual_order(event, attrs)
      assert order.name == "String Keys User"
      assert order.total_cents == 5000
    end
  end
end
