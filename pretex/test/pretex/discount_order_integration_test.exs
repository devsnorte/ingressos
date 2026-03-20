defmodule Pretex.DiscountOrderIntegrationTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Orders
  alias Pretex.Discounts
  alias Pretex.Vouchers
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp cart_with_item(event, price_cents \\ 5000, quantity \\ 1) do
    item = item_fixture(event, %{price_cents: price_cents})
    {:ok, cart} = Orders.create_cart(event)
    {:ok, _cart_item} = Orders.add_to_cart(cart, item, quantity: quantity)
    Orders.get_cart_by_token(cart.session_token)
  end

  defp order_attrs(extra \\ %{}) do
    Map.merge(
      %{
        name: "João Silva",
        email: "joao@example.com",
        payment_method: "pix"
      },
      extra
    )
  end

  defp discount_rule_fixture(event, attrs \\ %{}) do
    base = %{
      name: "Regra Integração #{System.unique_integer([:positive])}",
      condition_type: "min_quantity",
      min_quantity: 1,
      value_type: "fixed",
      value: 1000,
      active: true
    }

    {:ok, rule} = Discounts.create_discount_rule(event, Enum.into(attrs, base))
    rule
  end

  defp voucher_fixture(event, attrs \\ %{}) do
    base = %{
      code: "VOUCHER#{System.unique_integer([:positive])}",
      effect: "fixed_discount",
      value: 500,
      active: true
    }

    {:ok, voucher} = Vouchers.create_voucher(event, Enum.into(attrs, base))
    voucher
  end

  # ---------------------------------------------------------------------------
  # create_order_from_cart/2 with automatic discount
  # ---------------------------------------------------------------------------

  describe "create_order_from_cart/2 with matching discount rule" do
    test "reduces order total by the discount amount (fixed)" do
      org = org_fixture()
      event = published_event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "fixed",
          value: 1000
        })

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal - 1000
    end

    test "reduces order total by the discount amount (percentage)" do
      org = org_fixture()
      event = published_event_fixture(org)

      # 10% = 1000 basis points
      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "percentage",
          value: 1000
        })

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)
      expected_discount = round(subtotal * 1000 / 10_000)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal - expected_discount
    end

    test "inserts an order_discount record" do
      org = org_fixture()
      event = published_event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          name: "Desconto Integração",
          min_quantity: 1,
          value_type: "fixed",
          value: 800
        })

      cart = cart_with_item(event, 5000)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      discount =
        Repo.get_by(Pretex.Discounts.OrderDiscount, order_id: order.id)

      assert discount != nil
      assert discount.discount_cents == 800
      assert discount.name == "Desconto Integração"
    end

    test "selects the best (highest) discount when multiple rules match" do
      org = org_fixture()
      event = published_event_fixture(org)

      # Small: 5% of 5000 = 250 cents
      _rule_small =
        discount_rule_fixture(event, %{
          name: "Pequeno",
          min_quantity: 1,
          value_type: "percentage",
          value: 500
        })

      # Big: fixed 1500 cents
      _rule_big =
        discount_rule_fixture(event, %{
          name: "Grande",
          min_quantity: 1,
          value_type: "fixed",
          value: 1500
        })

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      # The big (1500) discount should have been applied
      assert order.total_cents == subtotal - 1500

      discount = Repo.get_by!(Pretex.Discounts.OrderDiscount, order_id: order.id)
      assert discount.discount_cents == 1500
      assert discount.name == "Grande"
    end

    test "order total never goes below zero even with a huge fixed discount" do
      org = org_fixture()
      event = published_event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "fixed",
          value: 999_999
        })

      cart = cart_with_item(event, 500)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents >= 0
    end
  end

  describe "create_order_from_cart/2 with non-matching rule" do
    test "leaves total unchanged when condition is not met" do
      org = org_fixture()
      event = published_event_fixture(org)

      # Requires 10 items, cart has only 1
      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 10,
          value_type: "fixed",
          value: 1000
        })

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal

      refute Repo.get_by(Pretex.Discounts.OrderDiscount, order_id: order.id)
    end

    test "leaves total unchanged when event has no discount rules" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal
    end
  end

  describe "create_order_from_cart/2 with both discount and voucher" do
    test "applies discount first, then voucher on the discounted price (both reduce total)" do
      org = org_fixture()
      event = published_event_fixture(org)

      # Automatic discount: fixed R$10 (1000 cents)
      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "fixed",
          value: 1000
        })

      # Voucher: fixed R$5 (500 cents)
      _voucher = voucher_fixture(event, %{code: "VOUCHER5", effect: "fixed_discount", value: 500})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      # subtotal = 5000
      # After discount: 5000 - 1000 = 4000
      # After voucher:  4000 - 500  = 3500
      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "VOUCHER5"}))

      assert order.total_cents == subtotal - 1000 - 500

      # Verify discount record exists
      discount = Repo.get_by!(Pretex.Discounts.OrderDiscount, order_id: order.id)
      assert discount.discount_cents == 1000

      # Verify voucher redemption exists
      redemption =
        Repo.get_by!(Pretex.Vouchers.VoucherRedemption, order_id: order.id)

      assert redemption.discount_cents == 500
    end

    test "discount applies even when voucher is invalid" do
      org = org_fixture()
      event = published_event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "fixed",
          value: 1000
        })

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      # Use a non-existent voucher code
      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{voucher_code: "INVALID_CODE"})
               )

      # Discount still applied, voucher silently skipped
      assert order.total_cents == subtotal - 1000
    end

    test "voucher applies even when no discount rules match" do
      org = org_fixture()
      event = published_event_fixture(org)

      # Rule requires 10 items — won't match
      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 10,
          value_type: "fixed",
          value: 1000
        })

      _voucher = voucher_fixture(event, %{code: "ONLY5", effect: "fixed_discount", value: 500})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "ONLY5"}))

      # Only voucher applied
      assert order.total_cents == subtotal - 500
      refute Repo.get_by(Pretex.Discounts.OrderDiscount, order_id: order.id)
    end
  end
end
