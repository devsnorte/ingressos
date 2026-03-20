defmodule Pretex.OrderFeesIntegrationTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Fees
  alias Pretex.Fees.OrderFee
  alias Pretex.Orders
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp fee_rule_fixture(event, attrs) do
    base = %{
      name: "Taxa de Serviço #{System.unique_integer([:positive])}",
      fee_type: "service",
      value_type: "fixed",
      value: 200,
      apply_mode: "automatic",
      active: true
    }

    {:ok, rule} = Fees.create_fee_rule(event, Enum.into(attrs, base))
    rule
  end

  defp cart_with_item(event) do
    item = item_fixture(event, %{price_cents: 5000})
    {:ok, cart} = Orders.create_cart(event)
    {:ok, _cart_item} = Orders.add_to_cart(cart, item, quantity: 1)
    # Reload the cart so cart_items are preloaded
    Orders.get_cart_by_token(cart.session_token)
  end

  defp order_attrs do
    %{
      name: "João Silva",
      email: "joao@example.com",
      payment_method: "pix"
    }
  end

  # ---------------------------------------------------------------------------
  # create_order_from_cart/2 — automatic fee application
  # ---------------------------------------------------------------------------

  describe "create_order_from_cart/2 with automatic fee rules" do
    test "order total includes a single fixed fee" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa de Serviço",
        value_type: "fixed",
        value: 300,
        apply_mode: "automatic"
      })

      cart = cart_with_item(event)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      # total should be subtotal + fee
      assert order.total_cents == subtotal + 300
    end

    test "order total includes multiple fixed fees" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa de Serviço",
        value_type: "fixed",
        value: 200,
        apply_mode: "automatic"
      })

      fee_rule_fixture(event, %{
        name: "Taxa de Manuseio",
        value_type: "fixed",
        value: 150,
        apply_mode: "automatic"
      })

      cart = cart_with_item(event)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal + 200 + 150
    end

    test "order total includes a percentage fee calculated from subtotal" do
      org = org_fixture()
      # published_event_fixture creates an item with default price 1000 cents (R$10)
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa 10%",
        value_type: "percentage",
        value: 1000,
        apply_mode: "automatic"
      })

      cart = cart_with_item(event)
      subtotal = Orders.cart_total(cart)
      expected_fee = round(subtotal * 1000 / 10_000)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal + expected_fee
    end

    test "inserts OrderFee records attached to the order" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa Fixa",
        value_type: "fixed",
        value: 400,
        apply_mode: "automatic"
      })

      cart = cart_with_item(event)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      order_fees = Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))
      assert length(order_fees) == 1

      [fee] = order_fees
      assert fee.name == "Taxa Fixa"
      assert fee.amount_cents == 400
      assert fee.value_type == "fixed"
    end

    test "inserts one OrderFee per applicable rule" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{name: "Taxa A", value: 100, apply_mode: "automatic"})
      fee_rule_fixture(event, %{name: "Taxa B", value: 200, apply_mode: "automatic"})
      fee_rule_fixture(event, %{name: "Taxa C", value: 300, apply_mode: "automatic"})

      cart = cart_with_item(event)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      order_fees = Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))
      assert length(order_fees) == 3
    end

    test "the returned order is preloaded with fees" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{value: 200, apply_mode: "automatic"})

      cart = cart_with_item(event)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      # fees association should be preloaded (not an Ecto.Association.NotLoaded)
      assert is_list(order.fees)
      assert length(order.fees) == 1
    end

    test "order total is unchanged when no fee rules exist" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal
    end

    test "no OrderFee records when no fee rules exist" do
      org = org_fixture()
      event = published_event_fixture(org)

      cart = cart_with_item(event)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      order_fees = Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))
      assert order_fees == []
    end

    test "manual fee rules are NOT applied automatically" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa Manual",
        value: 500,
        apply_mode: "manual"
      })

      cart = cart_with_item(event)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal

      order_fees = Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))
      assert order_fees == []
    end

    test "inactive fee rules are NOT applied" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa Inativa",
        value: 500,
        apply_mode: "automatic",
        active: false
      })

      cart = cart_with_item(event)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      assert order.total_cents == subtotal

      order_fees = Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))
      assert order_fees == []
    end

    test "only active automatic fees are applied when mixed rules exist" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa Automática Ativa",
        value: 200,
        apply_mode: "automatic",
        active: true
      })

      fee_rule_fixture(event, %{
        name: "Taxa Automática Inativa",
        value: 300,
        apply_mode: "automatic",
        active: false
      })

      fee_rule_fixture(event, %{
        name: "Taxa Manual Ativa",
        value: 400,
        apply_mode: "manual",
        active: true
      })

      cart = cart_with_item(event)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      # only the active+automatic fee of 200 should be applied
      assert order.total_cents == subtotal + 200

      order_fees = Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))
      assert length(order_fees) == 1
      assert hd(order_fees).name == "Taxa Automática Ativa"
    end
  end

  # ---------------------------------------------------------------------------
  # Fee does NOT retroactively affect existing orders
  # ---------------------------------------------------------------------------

  describe "fee rules added after order creation do not affect existing orders" do
    test "adding a fee rule does not change already-created order totals" do
      org = org_fixture()
      event = published_event_fixture(org)

      # Create order with no fee rules
      cart = cart_with_item(event)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())
      assert order.total_cents == subtotal

      # Now add a fee rule after the order was created
      fee_rule_fixture(event, %{value: 500, apply_mode: "automatic"})

      # The existing order total should be unchanged in the DB
      reloaded = Repo.get!(Pretex.Orders.Order, order.id)
      assert reloaded.total_cents == subtotal
    end

    test "deleting a fee rule does not change already-created order fees" do
      org = org_fixture()
      event = published_event_fixture(org)

      rule = fee_rule_fixture(event, %{value: 300, apply_mode: "automatic"})

      cart = cart_with_item(event)
      subtotal = Orders.cart_total(cart)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())
      expected_total = subtotal + 300
      assert order.total_cents == expected_total

      # Delete the rule
      {:ok, _} = Fees.delete_fee_rule(rule)

      # Order total should still reflect the fee that was applied at creation
      reloaded = Repo.get!(Pretex.Orders.Order, order.id)
      assert reloaded.total_cents == expected_total
    end

    test "OrderFee records are preserved even when fee_rule is deleted (nilify_all)" do
      org = org_fixture()
      event = published_event_fixture(org)

      rule = fee_rule_fixture(event, %{value: 250, apply_mode: "automatic"})

      cart = cart_with_item(event)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      order_fees_before =
        Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))

      assert length(order_fees_before) == 1
      assert hd(order_fees_before).fee_rule_id == rule.id

      # Delete the fee rule
      {:ok, _} = Fees.delete_fee_rule(rule)

      # OrderFee record should still exist but fee_rule_id should be nil
      order_fees_after =
        Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))

      assert length(order_fees_after) == 1
      assert hd(order_fees_after).fee_rule_id == nil
      assert hd(order_fees_after).amount_cents == 250
    end
  end

  # ---------------------------------------------------------------------------
  # list_order_fees/1 — post-creation verification
  # ---------------------------------------------------------------------------

  describe "list_order_fees/1 after order creation" do
    test "returns fees with correct fields after create_order_from_cart" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa de Envio",
        fee_type: "shipping",
        value_type: "fixed",
        value: 1000,
        apply_mode: "automatic"
      })

      cart = cart_with_item(event)

      assert {:ok, order} = Orders.create_order_from_cart(cart, order_attrs())

      fees = Fees.list_order_fees(order)
      assert length(fees) == 1

      [fee] = fees
      assert fee.name == "Taxa de Envio"
      assert fee.fee_type == "shipping"
      assert fee.amount_cents == 1000
      assert fee.value_type == "fixed"
      assert fee.value == 1000
      assert fee.order_id == order.id
    end

    test "fees from one order do not appear in another order" do
      org = org_fixture()
      event = published_event_fixture(org)

      fee_rule_fixture(event, %{value: 200, apply_mode: "automatic"})

      cart1 = cart_with_item(event)
      cart2 = cart_with_item(event)

      assert {:ok, order1} = Orders.create_order_from_cart(cart1, order_attrs())
      assert {:ok, order2} = Orders.create_order_from_cart(cart2, order_attrs())

      fees1 = Fees.list_order_fees(order1)
      fees2 = Fees.list_order_fees(order2)

      assert length(fees1) == 1
      assert length(fees2) == 1
      assert hd(fees1).order_id == order1.id
      assert hd(fees2).order_id == order2.id
    end
  end
end
