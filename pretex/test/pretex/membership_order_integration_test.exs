defmodule Pretex.MembershipOrderIntegrationTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures
  import Pretex.CustomersFixtures

  alias Pretex.Orders
  alias Pretex.Memberships
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp cart_with_item(event, price_cents, quantity \\ 1) do
    item = item_fixture(event, %{price_cents: price_cents})
    {:ok, cart} = Orders.create_cart(event)
    {:ok, _} = Orders.add_to_cart(cart, item, quantity: quantity)
    Orders.get_cart_by_token(cart.session_token)
  end

  defp order_attrs(extra \\ %{}) do
    Map.merge(
      %{name: "Maria Silva", email: "maria@example.com", payment_method: "pix"},
      extra
    )
  end

  # ---------------------------------------------------------------------------
  # AC3: Membership benefits applied at checkout
  # ---------------------------------------------------------------------------

  describe "create_order_from_cart/2 with active membership (percentage)" do
    test "applies membership discount before other promotions" do
      org = org_fixture()
      customer = customer_fixture()
      event = published_event_fixture(org)

      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      {:ok, _b} =
        Memberships.create_benefit(mt, %{benefit_type: "percentage_discount", value: 1500})

      {:ok, _m} = Memberships.grant_membership(mt, customer, org)

      cart = cart_with_item(event, 20_000)
      subtotal = Orders.cart_total(cart)
      expected_discount = round(subtotal * 1500 / 10_000)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{customer_id: customer.id}))

      assert order.total_cents == subtotal - expected_discount

      md = Repo.get_by!(Memberships.OrderMembershipDiscount, order_id: order.id)
      assert md.discount_cents == expected_discount
    end
  end

  describe "create_order_from_cart/2 with active membership (fixed)" do
    test "applies fixed membership discount" do
      org = org_fixture()
      customer = customer_fixture()
      event = published_event_fixture(org)

      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})
      {:ok, _b} = Memberships.create_benefit(mt, %{benefit_type: "fixed_discount", value: 3000})
      {:ok, _m} = Memberships.grant_membership(mt, customer, org)

      cart = cart_with_item(event, 20_000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{customer_id: customer.id}))

      assert order.total_cents == subtotal - 3000
    end
  end

  describe "create_order_from_cart/2 with expired membership" do
    test "does not apply discount for expired membership" do
      org = org_fixture()
      customer = customer_fixture()
      event = published_event_fixture(org)

      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      {:ok, _b} =
        Memberships.create_benefit(mt, %{benefit_type: "percentage_discount", value: 1500})

      {:ok, m} = Memberships.grant_membership(mt, customer, org)
      {:ok, _} = Memberships.expire_membership(m)

      cart = cart_with_item(event, 20_000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{customer_id: customer.id}))

      assert order.total_cents == subtotal
    end
  end

  describe "create_order_from_cart/2 with membership from another org" do
    test "does not apply membership discount from different org" do
      org1 = org_fixture()
      org2 = org_fixture()
      customer = customer_fixture()
      event = published_event_fixture(org2)

      {:ok, mt} = Memberships.create_membership_type(org1, %{name: "Gold", validity_days: 365})

      {:ok, _b} =
        Memberships.create_benefit(mt, %{benefit_type: "percentage_discount", value: 1500})

      {:ok, _m} = Memberships.grant_membership(mt, customer, org1)

      cart = cart_with_item(event, 20_000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{customer_id: customer.id}))

      assert order.total_cents == subtotal
    end
  end

  describe "create_order_from_cart/2 with overlapping memberships" do
    test "applies the best (highest) membership discount" do
      org = org_fixture()
      customer = customer_fixture()
      event = published_event_fixture(org)

      {:ok, mt_gold} =
        Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      {:ok, _b} =
        Memberships.create_benefit(mt_gold, %{benefit_type: "percentage_discount", value: 1500})

      {:ok, _m} = Memberships.grant_membership(mt_gold, customer, org)

      {:ok, mt_silver} =
        Memberships.create_membership_type(org, %{name: "Silver", validity_days: 365})

      {:ok, _b} =
        Memberships.create_benefit(mt_silver, %{benefit_type: "percentage_discount", value: 1000})

      {:ok, _m} = Memberships.grant_membership(mt_silver, customer, org)

      cart = cart_with_item(event, 20_000)
      subtotal = Orders.cart_total(cart)
      expected_discount = round(subtotal * 1500 / 10_000)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{customer_id: customer.id}))

      assert order.total_cents == subtotal - expected_discount

      md = Repo.get_by!(Memberships.OrderMembershipDiscount, order_id: order.id)
      assert md.name == "Gold"
    end
  end

  describe "create_order_from_cart/2 without customer_id" do
    test "skips membership evaluation when no customer" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 20_000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal
    end
  end

  describe "create_order_from_cart/2 with membership + auto-discount + voucher" do
    test "applies membership first, then auto-discount on reduced total, then voucher" do
      org = org_fixture()
      customer = customer_fixture()
      event = published_event_fixture(org)

      # Membership: 10% off
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      {:ok, _b} =
        Memberships.create_benefit(mt, %{benefit_type: "percentage_discount", value: 1000})

      {:ok, _m} = Memberships.grant_membership(mt, customer, org)

      # Auto-discount: fixed R$5
      {:ok, _rule} =
        Pretex.Discounts.create_discount_rule(event, %{
          name: "Auto 5",
          condition_type: "min_quantity",
          min_quantity: 1,
          value_type: "fixed",
          value: 500,
          active: true
        })

      # Voucher: fixed R$3
      {:ok, _voucher} =
        Pretex.Vouchers.create_voucher(event, %{
          code: "SAVE3",
          effect: "fixed_discount",
          value: 300,
          active: true
        })

      cart = cart_with_item(event, 10_000)
      # subtotal: 10000
      # After membership 10%: 10000 - 1000 = 9000
      # After auto-discount R$5: 9000 - 500 = 8500
      # After voucher R$3: 8500 - 300 = 8200

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{customer_id: customer.id, voucher_code: "SAVE3"})
               )

      assert order.total_cents == 8200
    end
  end

  # ---------------------------------------------------------------------------
  # AC2: Sell membership during checkout
  # ---------------------------------------------------------------------------

  describe "create_order_from_cart/2 purchasing a membership item" do
    test "auto-activates membership for customer on order creation" do
      org = org_fixture()
      customer = customer_fixture()
      event = published_event_fixture(org)

      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      {:ok, _b} =
        Memberships.create_benefit(mt, %{benefit_type: "percentage_discount", value: 1500})

      # Create a membership item in the catalog
      item =
        item_fixture(event, %{
          name: "Gold Membership",
          price_cents: 9900,
          item_type: "membership",
          membership_type_id: mt.id
        })

      {:ok, cart} = Orders.create_cart(event)
      {:ok, _} = Orders.add_to_cart(cart, item, quantity: 1)
      cart = Orders.get_cart_by_token(cart.session_token)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{customer_id: customer.id}))

      # Membership should be auto-activated
      memberships = Memberships.list_active_memberships(customer)
      assert length(memberships) == 1
      assert hd(memberships).membership_type_id == mt.id
      assert hd(memberships).source_order_id == order.id
    end

    test "requires customer account to purchase membership" do
      org = org_fixture()
      event = published_event_fixture(org)

      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      item =
        item_fixture(event, %{
          name: "Gold Membership",
          price_cents: 9900,
          item_type: "membership",
          membership_type_id: mt.id
        })

      {:ok, cart} = Orders.create_cart(event)
      {:ok, _} = Orders.add_to_cart(cart, item, quantity: 1)
      cart = Orders.get_cart_by_token(cart.session_token)

      # No customer_id — should fail
      assert {:error, :customer_required_for_membership} =
               Orders.create_order_from_cart(cart, order_attrs())
    end
  end
end
