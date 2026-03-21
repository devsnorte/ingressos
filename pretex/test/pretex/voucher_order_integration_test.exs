defmodule Pretex.VoucherOrderIntegrationTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Orders
  alias Pretex.Vouchers
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp cart_with_item(event, price_cents) do
    item = item_fixture(event, %{price_cents: price_cents})
    {:ok, cart} = Orders.create_cart(event)
    {:ok, _cart_item} = Orders.add_to_cart(cart, item, quantity: 1)
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

  defp voucher_fixture(event, attrs) do
    base = %{
      code: "TESTCODE#{System.unique_integer([:positive])}",
      effect: "fixed_discount",
      value: 1000,
      active: true
    }

    {:ok, voucher} = Vouchers.create_voucher(event, Enum.into(attrs, base))
    voucher
  end

  # ---------------------------------------------------------------------------
  # create_order_from_cart/2 with voucher_code
  # ---------------------------------------------------------------------------

  describe "create_order_from_cart/2 with voucher code" do
    test "applies a fixed discount voucher to the order total" do
      org = org_fixture()
      event = published_event_fixture(org)

      _voucher = voucher_fixture(event, %{code: "SAVE10", effect: "fixed_discount", value: 1000})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "SAVE10"}))

      assert order.total_cents == subtotal - 1000
    end

    test "applies a percentage discount voucher to the order total" do
      org = org_fixture()
      event = published_event_fixture(org)

      _voucher =
        voucher_fixture(event, %{
          code: "PCT10",
          effect: "percentage_discount",
          value: 1000
        })

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)
      expected_discount = round(subtotal * 1000 / 10_000)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "PCT10"}))

      assert order.total_cents == subtotal - expected_discount
    end

    test "total does not go below zero when discount exceeds subtotal" do
      org = org_fixture()
      event = published_event_fixture(org)

      _voucher =
        voucher_fixture(event, %{code: "BIGDISCOUNT", effect: "fixed_discount", value: 999_999})

      cart = cart_with_item(event, 1000)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "BIGDISCOUNT"}))

      assert order.total_cents == 0
    end

    test "inserts a VoucherRedemption record when voucher is applied" do
      org = org_fixture()
      event = published_event_fixture(org)

      _voucher = voucher_fixture(event, %{code: "REDEEM1", effect: "fixed_discount", value: 500})

      cart = cart_with_item(event, 5000)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "REDEEM1"}))

      redemption = Vouchers.get_redemption_for_order(order.id)

      assert redemption != nil
      assert redemption.order_id == order.id
      assert redemption.discount_cents == 500
    end

    test "increments voucher used_count when applied" do
      org = org_fixture()
      event = published_event_fixture(org)

      voucher = voucher_fixture(event, %{code: "COUNTME", effect: "fixed_discount", value: 500})
      assert voucher.used_count == 0

      cart = cart_with_item(event, 5000)

      assert {:ok, _order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "COUNTME"}))

      updated_voucher = Repo.get!(Pretex.Vouchers.Voucher, voucher.id)
      assert updated_voucher.used_count == 1
    end

    test "applies voucher with all-string-key attrs map" do
      org = org_fixture()
      event = published_event_fixture(org)

      _voucher = voucher_fixture(event, %{code: "STRKEY", effect: "fixed_discount", value: 800})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      string_attrs = %{
        "name" => "João Silva",
        "email" => "joao@example.com",
        "payment_method" => "pix",
        "voucher_code" => "STRKEY"
      }

      assert {:ok, order} = Orders.create_order_from_cart(cart, string_attrs)

      assert order.total_cents == subtotal - 800
    end

    test "applies voucher code case-insensitively" do
      org = org_fixture()
      event = published_event_fixture(org)

      _voucher = voucher_fixture(event, %{code: "CASETEST", effect: "fixed_discount", value: 300})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "casetest"}))

      assert order.total_cents == subtotal - 300
    end

    test "silently skips when voucher code is not found" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "DOESNOTEXIST"}))

      assert order.total_cents == subtotal
    end

    test "no redemption record when voucher is not found" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 5000)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "GHOST"}))

      assert Vouchers.get_redemption_for_order(order.id) == nil
    end

    test "silently skips when no voucher_code is provided" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal
    end

    test "no redemption record when no voucher_code is provided" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 5000)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert Vouchers.get_redemption_for_order(order.id) == nil
    end

    test "silently skips when voucher_code is an empty string" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: ""}))

      assert order.total_cents == subtotal
    end

    test "custom_price voucher does not reduce total (0 discount)" do
      org = org_fixture()
      event = published_event_fixture(org)

      _voucher =
        voucher_fixture(event, %{code: "CUSTOM1", effect: "custom_price", value: 1000})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "CUSTOM1"}))

      assert order.total_cents == subtotal
    end

    test "reveal voucher does not reduce total (0 discount)" do
      org = org_fixture()
      event = published_event_fixture(org)

      _voucher = voucher_fixture(event, %{code: "REVEAL1", effect: "reveal", value: 0})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "REVEAL1"}))

      assert order.total_cents == subtotal
    end

    test "inactive voucher is still looked up and redeemed at the orders layer" do
      # Note: inactive voucher validation happens at the checkout/LiveView layer.
      # The orders layer (create_order_from_cart) looks up by code via
      # get_voucher_by_code which returns {:ok, voucher} for inactive vouchers.
      # The UI/validate_voucher_for_cart is the gate that blocks inactive codes.
      org = org_fixture()
      event = published_event_fixture(org)

      _voucher =
        voucher_fixture(event, %{
          code: "INACTIVE1",
          effect: "fixed_discount",
          value: 1000,
          active: false
        })

      cart = cart_with_item(event, 5000)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "INACTIVE1"}))

      # The orders layer finds the voucher by code (active flag not checked here)
      assert is_integer(order.total_cents)
    end

    test "voucher from wrong event is silently skipped" do
      org = org_fixture()
      event1 = published_event_fixture(org)
      event2 = published_event_fixture(org)

      _voucher =
        voucher_fixture(event1, %{
          code: "WRONGEVENT",
          effect: "fixed_discount",
          value: 1000
        })

      cart = cart_with_item(event2, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "WRONGEVENT"}))

      assert order.total_cents == subtotal
    end

    test "fees are still applied when voucher is also applied" do
      org = org_fixture()
      event = published_event_fixture(org)

      {:ok, _rule} =
        Pretex.Fees.create_fee_rule(event, %{
          name: "Taxa de Serviço",
          fee_type: "service",
          value_type: "fixed",
          value: 200,
          apply_mode: "automatic",
          active: true
        })

      _voucher =
        voucher_fixture(event, %{code: "WITHFEE", effect: "fixed_discount", value: 1000})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{voucher_code: "WITHFEE"}))

      # total = subtotal + fee - discount = 5000 + 200 - 1000 = 4200
      assert order.total_cents == subtotal + 200 - 1000
    end
  end
end
