defmodule Pretex.GiftCardOrderIntegrationTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Orders
  alias Pretex.GiftCards
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

  defp gift_card_fixture(org, attrs) do
    base = %{
      code: "GC-TEST#{System.unique_integer([:positive])}",
      balance_cents: 5000,
      active: true
    }

    {:ok, gc} = GiftCards.create_gift_card(org, Enum.into(attrs, base))
    gc
  end

  # ---------------------------------------------------------------------------
  # create_order_from_cart/2 with gift_card_code
  # ---------------------------------------------------------------------------

  describe "create_order_from_cart/2 with gift_card_code" do
    test "deducts gift card balance from order total" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-DEDUCT01", balance_cents: 2000})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      assert order.total_cents == subtotal - 2000
    end

    test "reduces gift card balance after redemption" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-BALANCE01", balance_cents: 2000})

      cart = cart_with_item(event, 5000)

      assert {:ok, _order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      updated_gc = Repo.get!(Pretex.GiftCards.GiftCard, gc.id)
      assert updated_gc.balance_cents == 0
    end

    test "inserts a debit gift card redemption record" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-REDEM01", balance_cents: 3000})

      cart = cart_with_item(event, 5000)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      redemption = GiftCards.get_debit_redemption_for_order(order.id)

      assert redemption != nil
      assert redemption.order_id == order.id
      assert redemption.amount_cents == 3000
      assert redemption.kind == "debit"
    end

    test "partial redemption: order total greater than gift card balance" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-PARTIAL01", balance_cents: 1500})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      # Only card balance deducted, remaining total > 0
      assert order.total_cents == subtotal - 1500
      assert order.total_cents > 0

      updated_gc = Repo.get!(Pretex.GiftCards.GiftCard, gc.id)
      assert updated_gc.balance_cents == 0
    end

    test "gift card balance larger than order total clamps to zero" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-LARGE01", balance_cents: 99_999})

      cart = cart_with_item(event, 1000)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      assert order.total_cents == 0
    end

    test "unused gift card balance remains on card after order" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-REMAIN01", balance_cents: 10_000})

      cart = cart_with_item(event, 3000)

      assert {:ok, _order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      updated_gc = Repo.get!(Pretex.GiftCards.GiftCard, gc.id)
      # 10000 - 3000 = 7000 remaining
      assert updated_gc.balance_cents == 7000
    end

    test "gift card from wrong organization is silently skipped" do
      org1 = org_fixture()
      org2 = org_fixture()
      event = published_event_fixture(org2)
      gc = gift_card_fixture(org1, %{code: "GC-WRONGORG1", balance_cents: 5000})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      # No deduction — wrong org
      assert order.total_cents == subtotal
    end

    test "no gift card redemption record when wrong org card is used" do
      org1 = org_fixture()
      org2 = org_fixture()
      event = published_event_fixture(org2)
      gc = gift_card_fixture(org1, %{code: "GC-WRONGORG2", balance_cents: 5000})

      cart = cart_with_item(event, 5000)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      assert GiftCards.get_debit_redemption_for_order(order.id) == nil
    end

    test "silently skips when gift_card_code is nil" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())
      assert order.total_cents == subtotal
    end

    test "silently skips when gift_card_code is an empty string" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(cart, order_attrs(%{gift_card_code: ""}))

      assert order.total_cents == subtotal
    end

    test "silently skips when gift card code does not exist" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: "GC-DOESNOTEXIST"})
               )

      assert order.total_cents == subtotal
    end

    test "silently skips when gift card is inactive" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-INACTIVE01", balance_cents: 5000, active: false})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      assert order.total_cents == subtotal
    end

    test "silently skips when gift card is expired" do
      org = org_fixture()
      event = published_event_fixture(org)

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      gc =
        gift_card_fixture(org, %{
          code: "GC-EXPIRED01",
          balance_cents: 5000,
          expires_at: past
        })

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      assert order.total_cents == subtotal
    end

    test "silently skips when gift card balance is zero" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-EMPTY01", balance_cents: 0})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      assert order.total_cents == subtotal
    end

    test "works with string-key attrs map" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-STRKEY01", balance_cents: 2000})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      string_attrs = %{
        "name" => "João Silva",
        "email" => "joao@example.com",
        "payment_method" => "pix",
        "gift_card_code" => gc.code
      }

      assert {:ok, order} = Orders.create_order_from_cart(cart, string_attrs)
      assert order.total_cents == subtotal - 2000
    end

    test "gift card applied case-insensitively" do
      org = org_fixture()
      event = published_event_fixture(org)
      _gc = gift_card_fixture(org, %{code: "GC-CASECI01", balance_cents: 1000})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: "gc-caseci01"})
               )

      assert order.total_cents == subtotal - 1000
    end

    test "preloads gift_card_redemptions on the returned order" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-PRELOAD1", balance_cents: 2000})

      cart = cart_with_item(event, 5000)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      assert is_list(order.gift_card_redemptions)
      assert length(order.gift_card_redemptions) == 1
    end

    test "fees still applied when gift card is also applied" do
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

      gc = gift_card_fixture(org, %{code: "GC-WITHFEE1", balance_cents: 1000})

      cart = cart_with_item(event, 5000)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      # total = subtotal + fee - gc = 5000 + 200 - 1000 = 4200
      assert order.total_cents == subtotal + 200 - 1000
    end
  end

  # ---------------------------------------------------------------------------
  # cancel_order/1 with gift card redemption
  # ---------------------------------------------------------------------------

  describe "cancel_order/1 with gift card redemption" do
    test "restores gift card balance when order with gift card is cancelled" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-CANCEL01", balance_cents: 5000})

      cart = cart_with_item(event, 3000)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      # Verify deduction happened
      gc_after_order = Repo.get!(Pretex.GiftCards.GiftCard, gc.id)
      assert gc_after_order.balance_cents == 2000

      # Cancel the order
      assert {:ok, _cancelled} = Orders.cancel_order(order)

      # Balance should be restored
      gc_after_cancel = Repo.get!(Pretex.GiftCards.GiftCard, gc.id)
      assert gc_after_cancel.balance_cents == 5000
    end

    test "inserts a credit redemption when order is cancelled" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-CANCEL02", balance_cents: 5000})

      cart = cart_with_item(event, 3000)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      Orders.cancel_order(order)

      credit_redemption =
        Pretex.GiftCards.GiftCardRedemption
        |> Ecto.Query.where(gift_card_id: ^gc.id, kind: "credit")
        |> Repo.one()

      assert credit_redemption != nil
      assert credit_redemption.amount_cents == 3000
    end

    test "does not touch gift card when order had no gift card redemption" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-NOCANCEL1", balance_cents: 5000})

      cart = cart_with_item(event, 3000)

      # Place order WITHOUT gift card
      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      # Cancel it
      assert {:ok, _cancelled} = Orders.cancel_order(order)

      # Gift card balance should be untouched
      gc_after = Repo.get!(Pretex.GiftCards.GiftCard, gc.id)
      assert gc_after.balance_cents == 5000
    end

    test "marks the order as cancelled" do
      org = org_fixture()
      event = published_event_fixture(org)
      gc = gift_card_fixture(org, %{code: "GC-CANCEL03", balance_cents: 5000})

      cart = cart_with_item(event, 3000)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      assert {:ok, cancelled} = Orders.cancel_order(order)
      assert cancelled.status == "cancelled"
    end

    test "restores partial gift card balance correctly" do
      org = org_fixture()
      event = published_event_fixture(org)
      # Card has less than order price — partial redemption
      gc = gift_card_fixture(org, %{code: "GC-PARTCAN1", balance_cents: 1000})

      cart = cart_with_item(event, 5000)

      assert {:ok, order} =
               Orders.create_order_from_cart(
                 cart,
                 order_attrs(%{gift_card_code: gc.code})
               )

      # Verify full card was deducted
      gc_after_order = Repo.get!(Pretex.GiftCards.GiftCard, gc.id)
      assert gc_after_order.balance_cents == 0

      # Cancel
      assert {:ok, _cancelled} = Orders.cancel_order(order)

      # Full 1000 should be restored
      gc_after_cancel = Repo.get!(Pretex.GiftCards.GiftCard, gc.id)
      assert gc_after_cancel.balance_cents == 1000
    end
  end
end
