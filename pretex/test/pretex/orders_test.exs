defmodule Pretex.OrdersTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Orders
  alias Pretex.Orders.CartSession
  alias Pretex.Orders.CartItem
  alias Pretex.Orders.Order
  alias Pretex.Catalog

  defp cart_fixture(event) do
    {:ok, cart} = Orders.create_cart(event)
    cart
  end

  defp active_cart_fixture(event) do
    cart = cart_fixture(event)
    # Reload to have all fields
    Orders.get_cart_by_token(cart.session_token)
  end

  # ---------------------------------------------------------------------------
  # create_cart/1
  # ---------------------------------------------------------------------------

  describe "create_cart/1" do
    test "creates a cart session with a unique token" do
      org = org_fixture()
      event = published_event_fixture(org)

      assert {:ok, %CartSession{} = cart} = Orders.create_cart(event)
      assert cart.session_token != nil
      assert byte_size(cart.session_token) == 64
      assert cart.status == "active"
      assert cart.event_id == event.id
    end

    test "sets expires_at to approximately 15 minutes in the future" do
      org = org_fixture()
      event = published_event_fixture(org)

      {:ok, cart} = Orders.create_cart(event)

      diff = DateTime.diff(cart.expires_at, DateTime.utc_now(), :second)
      assert diff > 800 and diff <= 900
    end

    test "each cart gets a unique token" do
      org = org_fixture()
      event = published_event_fixture(org)

      {:ok, cart1} = Orders.create_cart(event)
      {:ok, cart2} = Orders.create_cart(event)

      assert cart1.session_token != cart2.session_token
    end
  end

  # ---------------------------------------------------------------------------
  # get_cart_by_token/1
  # ---------------------------------------------------------------------------

  describe "get_cart_by_token/1" do
    test "returns cart for a valid token" do
      org = org_fixture()
      event = published_event_fixture(org)
      {:ok, cart} = Orders.create_cart(event)

      found = Orders.get_cart_by_token(cart.session_token)
      assert found.id == cart.id
    end

    test "returns nil for an unknown token" do
      assert Orders.get_cart_by_token("nonexistent-token-abc") == nil
    end

    test "returns nil for a nil token" do
      assert Orders.get_cart_by_token(nil) == nil
    end

    test "preloads cart_items with item and variation" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)

      Orders.add_to_cart(cart, item)

      found = Orders.get_cart_by_token(cart.session_token)
      assert is_list(found.cart_items)
      assert length(found.cart_items) == 1
      assert hd(found.cart_items).item.id == item.id
    end
  end

  # ---------------------------------------------------------------------------
  # add_to_cart/3
  # ---------------------------------------------------------------------------

  describe "add_to_cart/3" do
    test "creates a new cart item for an item" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)

      assert {:ok, %CartItem{} = cart_item} = Orders.add_to_cart(cart, item)
      assert cart_item.item_id == item.id
      assert cart_item.quantity == 1
      assert cart_item.cart_session_id == cart.id
    end

    test "creates a cart item with specified quantity" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)

      assert {:ok, cart_item} = Orders.add_to_cart(cart, item, quantity: 3)
      assert cart_item.quantity == 3
    end

    test "accumulates quantity when adding same item twice" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)

      Orders.add_to_cart(cart, item, quantity: 2)
      {:ok, cart_item} = Orders.add_to_cart(cart, item, quantity: 1)

      assert cart_item.quantity == 3
    end

    test "creates a cart item with a variation" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      variation = variation_fixture(item)
      cart = cart_fixture(event)

      assert {:ok, cart_item} =
               Orders.add_to_cart(cart, item, variation_id: variation.id)

      assert cart_item.item_variation_id == variation.id
    end

    test "treats same item with different variations as separate cart items" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      var1 = variation_fixture(item, %{name: "Small"})
      var2 = variation_fixture(item, %{name: "Large"})
      cart = cart_fixture(event)

      {:ok, _ci1} = Orders.add_to_cart(cart, item, variation_id: var1.id)
      {:ok, _ci2} = Orders.add_to_cart(cart, item, variation_id: var2.id)

      updated = Orders.get_cart_by_token(cart.session_token)
      assert length(updated.cart_items) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # remove_from_cart/2
  # ---------------------------------------------------------------------------

  describe "remove_from_cart/2" do
    test "removes an existing cart item" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)

      {:ok, cart_item} = Orders.add_to_cart(cart, item)
      assert {:ok, _} = Orders.remove_from_cart(cart, cart_item.id)

      updated = Orders.get_cart_by_token(cart.session_token)
      assert updated.cart_items == []
    end

    test "returns error when cart item does not exist" do
      org = org_fixture()
      event = published_event_fixture(org)
      cart = cart_fixture(event)

      assert {:error, :not_found} = Orders.remove_from_cart(cart, -1)
    end

    test "cannot remove cart item from a different cart" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart1 = cart_fixture(event)
      cart2 = cart_fixture(event)

      {:ok, cart_item} = Orders.add_to_cart(cart1, item)

      assert {:error, :not_found} = Orders.remove_from_cart(cart2, cart_item.id)
    end
  end

  # ---------------------------------------------------------------------------
  # cart_total/1
  # ---------------------------------------------------------------------------

  describe "cart_total/1" do
    test "returns 0 for an empty cart" do
      org = org_fixture()
      event = published_event_fixture(org)
      cart = active_cart_fixture(event)

      assert Orders.cart_total(cart) == 0
    end

    test "returns the sum of item prices times quantities" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 1500})
      cart = cart_fixture(event)

      Orders.add_to_cart(cart, item, quantity: 2)

      updated = Orders.get_cart_by_token(cart.session_token)
      assert Orders.cart_total(updated) == 3000
    end

    test "uses variation price when variation is present" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 1000})
      variation = variation_fixture(item, %{price_cents: 2500})
      cart = cart_fixture(event)

      Orders.add_to_cart(cart, item, quantity: 1, variation_id: variation.id)

      updated = Orders.get_cart_by_token(cart.session_token)
      assert Orders.cart_total(updated) == 2500
    end

    test "sums multiple cart items correctly" do
      org = org_fixture()
      event = published_event_fixture(org)
      item1 = item_fixture(event, %{name: "Item A", price_cents: 1000})
      item2 = item_fixture(event, %{name: "Item B", price_cents: 500})
      cart = cart_fixture(event)

      Orders.add_to_cart(cart, item1, quantity: 2)
      Orders.add_to_cart(cart, item2, quantity: 3)

      updated = Orders.get_cart_by_token(cart.session_token)
      assert Orders.cart_total(updated) == 3500
    end
  end

  # ---------------------------------------------------------------------------
  # create_order_from_cart/2
  # ---------------------------------------------------------------------------

  describe "create_order_from_cart/2" do
    test "creates an order from a valid cart" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 2000})
      cart = cart_fixture(event)
      Orders.add_to_cart(cart, item, quantity: 2)

      cart = Orders.get_cart_by_token(cart.session_token)

      attrs = %{
        name: "Jane Doe",
        email: "jane@example.com",
        payment_method: "pix"
      }

      assert {:ok, %Order{} = order} = Orders.create_order_from_cart(cart, attrs)
      assert order.email == "jane@example.com"
      assert order.name == "Jane Doe"
      assert order.payment_method == "pix"
      assert order.status == "pending"
      assert order.total_cents == 4000
      assert order.event_id == event.id
      assert order.confirmation_code != nil
      assert length(order.order_items) == 1
    end

    test "generates unique ticket codes for each order item" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)
      Orders.add_to_cart(cart, item)

      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test",
          email: "t@example.com",
          payment_method: "credit_card"
        })

      assert hd(order.order_items).ticket_code != nil
    end

    test "marks cart as checked_out after order creation" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)
      Orders.add_to_cart(cart, item)

      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, _order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test",
          email: "t@example.com",
          payment_method: "credit_card"
        })

      updated_cart = Orders.get_cart_by_token(cart.session_token)
      assert updated_cart.status == "checked_out"
    end

    test "returns error when cart has expired" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      {:ok, cart} = Orders.create_cart(event)

      Orders.add_to_cart(cart, item)

      expired_cart =
        cart
        |> Ecto.Changeset.change(expires_at: ~U[2020-01-01 00:00:00Z])
        |> Pretex.Repo.update!()

      expired_cart = Orders.get_cart_by_token(expired_cart.session_token)

      assert {:error, :cart_expired} =
               Orders.create_order_from_cart(expired_cart, %{
                 name: "Test",
                 email: "t@example.com",
                 payment_method: "pix"
               })
    end

    test "returns error when cart is not active" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)
      Orders.add_to_cart(cart, item)

      checked_out_cart =
        cart
        |> Ecto.Changeset.change(status: "checked_out")
        |> Pretex.Repo.update!()

      checked_out_cart = Orders.get_cart_by_token(checked_out_cart.session_token)

      assert {:error, :cart_not_active} =
               Orders.create_order_from_cart(checked_out_cart, %{
                 name: "Test",
                 email: "t@example.com",
                 payment_method: "pix"
               })
    end

    test "sets expires_at based on payment method" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      for {method, expected_seconds} <- [
            {"credit_card", 900},
            {"pix", 900},
            {"boleto", 1800},
            {"bank_transfer", 3 * 24 * 60 * 60}
          ] do
        cart = cart_fixture(event)
        Orders.add_to_cart(cart, item)
        cart = Orders.get_cart_by_token(cart.session_token)

        {:ok, order} =
          Orders.create_order_from_cart(cart, %{
            name: "Test",
            email: "test@example.com",
            payment_method: method
          })

        diff = DateTime.diff(order.expires_at, DateTime.utc_now(), :second)

        assert diff > expected_seconds - 10 and diff <= expected_seconds,
               "Expected ~#{expected_seconds}s expiry for #{method}, got #{diff}s"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # confirm_order/1
  # ---------------------------------------------------------------------------

  describe "confirm_order/1" do
    test "sets order status to confirmed" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)
      Orders.add_to_cart(cart, item)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test",
          email: "t@example.com",
          payment_method: "credit_card"
        })

      assert {:ok, confirmed} = Orders.confirm_order(order)
      assert confirmed.status == "confirmed"
    end
  end

  # ---------------------------------------------------------------------------
  # cancel_order/1
  # ---------------------------------------------------------------------------

  describe "cancel_order/1" do
    test "sets order status to cancelled" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)
      Orders.add_to_cart(cart, item)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test",
          email: "t@example.com",
          payment_method: "credit_card"
        })

      assert {:ok, cancelled} = Orders.cancel_order(order)
      assert cancelled.status == "cancelled"
    end

    test "decrements quota sold_count when cancelling" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      {:ok, quota} = Catalog.create_quota(event, %{name: "General Quota", capacity: 100})
      Catalog.assign_item_to_quota(quota, item)

      cart = cart_fixture(event)
      Orders.add_to_cart(cart, item, quantity: 2)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test",
          email: "t@example.com",
          payment_method: "credit_card"
        })

      quota_after = Catalog.get_quota!(quota.id)
      assert quota_after.sold_count == 2

      {:ok, _} = Orders.cancel_order(order)

      quota_final = Catalog.get_quota!(quota.id)
      assert quota_final.sold_count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # get_order_by_confirmation_code/1
  # ---------------------------------------------------------------------------

  describe "get_order_by_confirmation_code/1" do
    test "returns the order for a valid code" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)
      Orders.add_to_cart(cart, item)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Alice",
          email: "alice@example.com",
          payment_method: "pix"
        })

      assert {:ok, found} = Orders.get_order_by_confirmation_code(order.confirmation_code)
      assert found.id == order.id
      assert found.name == "Alice"
    end

    test "returns error for unknown code" do
      assert {:error, :not_found} = Orders.get_order_by_confirmation_code("ZZZZZZ")
    end

    test "returns error for nil" do
      assert {:error, :not_found} = Orders.get_order_by_confirmation_code(nil)
    end
  end

  # ---------------------------------------------------------------------------
  # list_orders_for_event/1
  # ---------------------------------------------------------------------------

  describe "list_orders_for_event/1" do
    test "returns all orders for an event" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)

      for i <- 1..3 do
        cart = cart_fixture(event)
        Orders.add_to_cart(cart, item)
        cart = Orders.get_cart_by_token(cart.session_token)

        Orders.create_order_from_cart(cart, %{
          name: "Customer #{i}",
          email: "c#{i}@example.com",
          payment_method: "pix"
        })
      end

      orders = Orders.list_orders_for_event(event)
      assert length(orders) == 3
    end

    test "does not return orders from other events" do
      org = org_fixture()
      event1 = published_event_fixture(org)
      event2 = published_event_fixture(org)

      item1 = item_fixture(event1)
      cart1 = cart_fixture(event1)
      Orders.add_to_cart(cart1, item1)
      cart1 = Orders.get_cart_by_token(cart1.session_token)

      Orders.create_order_from_cart(cart1, %{
        name: "Test",
        email: "t@example.com",
        payment_method: "pix"
      })

      assert Orders.list_orders_for_event(event2) == []
    end

    test "preloads order_items" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event)
      cart = cart_fixture(event)
      Orders.add_to_cart(cart, item)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, _order} =
        Orders.create_order_from_cart(cart, %{
          name: "Test",
          email: "t@example.com",
          payment_method: "pix"
        })

      [order] = Orders.list_orders_for_event(event)
      assert is_list(order.order_items)
      assert length(order.order_items) == 1
    end
  end
end
