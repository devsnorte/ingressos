defmodule Pretex.DiscountsTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.Discounts
  alias Pretex.Discounts.OrderDiscount
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp discount_rule_fixture(event, attrs \\ %{}) do
    base = %{
      name: "Regra Teste #{System.unique_integer([:positive])}",
      condition_type: "min_quantity",
      min_quantity: 2,
      value_type: "percentage",
      value: 1000,
      active: true
    }

    {:ok, rule} = Discounts.create_discount_rule(event, Enum.into(attrs, base))
    rule
  end

  defp order_fixture(event, total_cents) do
    {:ok, order} =
      %Pretex.Orders.Order{}
      |> Ecto.Changeset.change(%{
        event_id: event.id,
        status: "pending",
        total_cents: total_cents,
        email: "test@example.com",
        name: "Test User",
        confirmation_code: "CONF#{System.unique_integer([:positive])}",
        expires_at:
          DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
      })
      |> Repo.insert()

    order
  end

  # ---------------------------------------------------------------------------
  # list_discount_rules/1
  # ---------------------------------------------------------------------------

  describe "list_discount_rules/1" do
    test "returns discount rules for the given event" do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{name: "Alfa"})

      result = Discounts.list_discount_rules(event)

      assert Enum.any?(result, &(&1.id == rule.id))
    end

    test "does not return rules for another event" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)

      _rule = discount_rule_fixture(event1, %{name: "Regra do Evento 1"})

      result = Discounts.list_discount_rules(event2)

      assert result == []
    end

    test "preloads scoped_items" do
      org = org_fixture()
      event = event_fixture(org)
      _rule = discount_rule_fixture(event)

      [rule] = Discounts.list_discount_rules(event)

      assert is_list(rule.scoped_items)
    end

    test "orders by name asc" do
      org = org_fixture()
      event = event_fixture(org)

      discount_rule_fixture(event, %{name: "Zeta"})
      discount_rule_fixture(event, %{name: "Alpha"})
      discount_rule_fixture(event, %{name: "Meso"})

      result = Discounts.list_discount_rules(event)
      names = Enum.map(result, & &1.name)

      assert names == Enum.sort(names)
    end
  end

  # ---------------------------------------------------------------------------
  # get_discount_rule!/1
  # ---------------------------------------------------------------------------

  describe "get_discount_rule!/1" do
    test "returns rule by id with scoped_items preloaded" do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event)

      fetched = Discounts.get_discount_rule!(rule.id)

      assert fetched.id == rule.id
      assert is_list(fetched.scoped_items)
    end

    test "raises when not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Discounts.get_discount_rule!(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_discount_rule/2
  # ---------------------------------------------------------------------------

  describe "create_discount_rule/2" do
    test "valid attrs creates a rule" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Desconto Grupo",
        condition_type: "min_quantity",
        min_quantity: 3,
        value_type: "percentage",
        value: 500,
        active: true
      }

      assert {:ok, rule} = Discounts.create_discount_rule(event, attrs)
      assert rule.name == "Desconto Grupo"
      assert rule.min_quantity == 3
      assert rule.value == 500
      assert rule.event_id == event.id
    end

    test "creates a fixed discount rule" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Desconto Fixo R$10",
        condition_type: "min_quantity",
        min_quantity: 1,
        value_type: "fixed",
        value: 1000
      }

      assert {:ok, rule} = Discounts.create_discount_rule(event, attrs)
      assert rule.value_type == "fixed"
      assert rule.value == 1000
    end

    test "returns error for negative value" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Inválido",
        condition_type: "min_quantity",
        value_type: "fixed",
        value: -100
      }

      assert {:error, changeset} = Discounts.create_discount_rule(event, attrs)
      assert %{value: [_ | _]} = errors_on(changeset)
    end

    test "returns error for percentage greater than 10000" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Percentual Inválido",
        condition_type: "min_quantity",
        value_type: "percentage",
        value: 10_001
      }

      assert {:error, changeset} = Discounts.create_discount_rule(event, attrs)
      assert %{value: [_ | _]} = errors_on(changeset)
    end

    test "returns error for invalid condition_type" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Inválido",
        condition_type: "unknown",
        value_type: "fixed",
        value: 100
      }

      assert {:error, changeset} = Discounts.create_discount_rule(event, attrs)
      assert %{condition_type: [_ | _]} = errors_on(changeset)
    end

    test "returns error for name shorter than 2 chars" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{name: "A", condition_type: "min_quantity", value_type: "fixed", value: 100}

      assert {:error, changeset} = Discounts.create_discount_rule(event, attrs)
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "percentage exactly 10000 is valid (100%)" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "100 porcento",
        condition_type: "min_quantity",
        value_type: "percentage",
        value: 10_000
      }

      assert {:ok, rule} = Discounts.create_discount_rule(event, attrs)
      assert rule.value == 10_000
    end
  end

  # ---------------------------------------------------------------------------
  # update_discount_rule/2
  # ---------------------------------------------------------------------------

  describe "update_discount_rule/2" do
    test "updates fields" do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event, %{name: "Original", value: 500})

      assert {:ok, updated} =
               Discounts.update_discount_rule(rule, %{name: "Atualizado", value: 1500})

      assert updated.name == "Atualizado"
      assert updated.value == 1500
    end

    test "returns error for invalid attrs" do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event)

      assert {:error, changeset} = Discounts.update_discount_rule(rule, %{value: -1})
      assert %{value: [_ | _]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # delete_discount_rule/1
  # ---------------------------------------------------------------------------

  describe "delete_discount_rule/1" do
    test "removes the rule" do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event)

      assert {:ok, _} = Discounts.delete_discount_rule(rule)
      assert_raise Ecto.NoResultsError, fn -> Discounts.get_discount_rule!(rule.id) end
    end
  end

  # ---------------------------------------------------------------------------
  # change_discount_rule/2
  # ---------------------------------------------------------------------------

  describe "change_discount_rule/2" do
    test "returns a changeset" do
      org = org_fixture()
      event = event_fixture(org)
      rule = discount_rule_fixture(event)

      changeset = Discounts.change_discount_rule(rule, %{name: "Novo Nome"})
      assert %Ecto.Changeset{} = changeset
    end
  end

  # ---------------------------------------------------------------------------
  # evaluate_cart/2
  # ---------------------------------------------------------------------------

  describe "evaluate_cart/2 with min_quantity rule (no scoped items)" do
    test "matching cart returns discount entry" do
      org = org_fixture()
      event = event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{min_quantity: 2, value_type: "percentage", value: 1000})

      cart_items = [
        %{item_id: 1, item_variation_id: nil, quantity: 2, unit_price_cents: 5000},
        %{item_id: 2, item_variation_id: nil, quantity: 1, unit_price_cents: 3000}
      ]

      results = Discounts.evaluate_cart(event.id, cart_items)

      assert length(results) == 1
      [entry] = results
      assert entry.discount_cents > 0
    end

    test "non-matching cart (quantity too low) returns empty list" do
      org = org_fixture()
      event = event_fixture(org)
      _rule = discount_rule_fixture(event, %{min_quantity: 5, value_type: "fixed", value: 500})

      cart_items = [
        %{item_id: 1, item_variation_id: nil, quantity: 2, unit_price_cents: 5000}
      ]

      results = Discounts.evaluate_cart(event.id, cart_items)

      assert results == []
    end

    test "exactly matching min_quantity triggers the discount" do
      org = org_fixture()
      event = event_fixture(org)
      _rule = discount_rule_fixture(event, %{min_quantity: 3, value_type: "fixed", value: 1000})

      cart_items = [
        %{item_id: 1, item_variation_id: nil, quantity: 3, unit_price_cents: 5000}
      ]

      results = Discounts.evaluate_cart(event.id, cart_items)

      assert length(results) == 1
    end

    test "inactive rules are not evaluated" do
      org = org_fixture()
      event = event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "fixed",
          value: 100,
          active: false
        })

      cart_items = [%{item_id: 1, item_variation_id: nil, quantity: 5, unit_price_cents: 5000}]

      results = Discounts.evaluate_cart(event.id, cart_items)

      assert results == []
    end
  end

  describe "evaluate_cart/2 with scoped min_quantity (only counts scoped items)" do
    test "only counts cart items whose item_id is in scoped_items" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, rule} =
        Discounts.create_discount_rule(event, %{
          name: "Scoped Min Qty",
          condition_type: "min_quantity",
          min_quantity: 2,
          value_type: "fixed",
          value: 500
        })

      # Add scoped item directly
      %Pretex.Discounts.DiscountRuleItem{}
      |> Pretex.Discounts.DiscountRuleItem.changeset(%{
        discount_rule_id: rule.id,
        item_id: item.id
      })
      |> Repo.insert!()

      # The scoped item has quantity 1 (not enough) but total cart has 3
      cart_items = [
        %{item_id: item.id, item_variation_id: nil, quantity: 1, unit_price_cents: 5000},
        %{item_id: item.id + 999, item_variation_id: nil, quantity: 2, unit_price_cents: 3000}
      ]

      results = Discounts.evaluate_cart(event.id, cart_items)

      # Should NOT match because only item.id counts and it has qty=1 < min_quantity=2
      assert results == []
    end

    test "matches when scoped item quantity meets threshold" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event)

      {:ok, rule} =
        Discounts.create_discount_rule(event, %{
          name: "Scoped Min Qty Match",
          condition_type: "min_quantity",
          min_quantity: 2,
          value_type: "fixed",
          value: 500
        })

      %Pretex.Discounts.DiscountRuleItem{}
      |> Pretex.Discounts.DiscountRuleItem.changeset(%{
        discount_rule_id: rule.id,
        item_id: item.id
      })
      |> Repo.insert!()

      cart_items = [
        %{item_id: item.id, item_variation_id: nil, quantity: 3, unit_price_cents: 5000}
      ]

      results = Discounts.evaluate_cart(event.id, cart_items)

      assert length(results) == 1
      [entry] = results
      assert entry.rule.id == rule.id
    end
  end

  describe "evaluate_cart/2 with item_combo rule" do
    test "matching cart (all required items present) returns discount entry" do
      org = org_fixture()
      event = event_fixture(org)
      item_a = item_fixture(event)
      item_b = item_fixture(event)

      {:ok, rule} =
        Discounts.create_discount_rule(event, %{
          name: "Combo AB",
          condition_type: "item_combo",
          value_type: "percentage",
          value: 1000
        })

      Repo.insert!(%Pretex.Discounts.DiscountRuleItem{
        discount_rule_id: rule.id,
        item_id: item_a.id
      })

      Repo.insert!(%Pretex.Discounts.DiscountRuleItem{
        discount_rule_id: rule.id,
        item_id: item_b.id
      })

      cart_items = [
        %{item_id: item_a.id, item_variation_id: nil, quantity: 1, unit_price_cents: 5000},
        %{item_id: item_b.id, item_variation_id: nil, quantity: 1, unit_price_cents: 3000}
      ]

      results = Discounts.evaluate_cart(event.id, cart_items)

      assert length(results) == 1
      [entry] = results
      assert entry.rule.id == rule.id
    end

    test "missing one required item returns empty list" do
      org = org_fixture()
      event = event_fixture(org)
      item_a = item_fixture(event)
      item_b = item_fixture(event)

      {:ok, rule} =
        Discounts.create_discount_rule(event, %{
          name: "Combo AB incompleto",
          condition_type: "item_combo",
          value_type: "fixed",
          value: 500
        })

      Repo.insert!(%Pretex.Discounts.DiscountRuleItem{
        discount_rule_id: rule.id,
        item_id: item_a.id
      })

      Repo.insert!(%Pretex.Discounts.DiscountRuleItem{
        discount_rule_id: rule.id,
        item_id: item_b.id
      })

      # Only item_a in cart, item_b missing
      cart_items = [
        %{item_id: item_a.id, item_variation_id: nil, quantity: 1, unit_price_cents: 5000}
      ]

      results = Discounts.evaluate_cart(event.id, cart_items)

      assert results == []
    end

    test "item_combo with no scoped items never matches" do
      org = org_fixture()
      event = event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          condition_type: "item_combo",
          value_type: "fixed",
          value: 500
        })

      cart_items = [%{item_id: 1, item_variation_id: nil, quantity: 5, unit_price_cents: 5000}]

      results = Discounts.evaluate_cart(event.id, cart_items)

      assert results == []
    end
  end

  describe "evaluate_cart/2 with multiple rules" do
    test "returns all matching rules sorted desc by discount_cents" do
      org = org_fixture()
      event = event_fixture(org)

      # Rule giving ~10% off R$50 = R$5 (500 cents)
      _rule_small =
        discount_rule_fixture(event, %{
          name: "Pequeno",
          min_quantity: 1,
          value_type: "percentage",
          value: 1000
        })

      # Rule giving fixed R$10 (1000 cents)
      _rule_big =
        discount_rule_fixture(event, %{
          name: "Grande",
          min_quantity: 1,
          value_type: "fixed",
          value: 1000
        })

      cart_items = [
        %{item_id: 1, item_variation_id: nil, quantity: 1, unit_price_cents: 5000}
      ]

      results = Discounts.evaluate_cart(event.id, cart_items)

      assert length(results) == 2
      [first, second] = results
      assert first.discount_cents >= second.discount_cents
    end
  end

  # ---------------------------------------------------------------------------
  # best_discount/2
  # ---------------------------------------------------------------------------

  describe "best_discount/2" do
    test "returns highest discount when multiple rules match" do
      org = org_fixture()
      event = event_fixture(org)

      # 10% of 10000 = 1000 cents
      _rule_pct =
        discount_rule_fixture(event, %{
          name: "Percentual",
          min_quantity: 1,
          value_type: "percentage",
          value: 1000
        })

      # Fixed 2000 cents
      _rule_fixed =
        discount_rule_fixture(event, %{
          name: "Fixo",
          min_quantity: 1,
          value_type: "fixed",
          value: 2000
        })

      cart_items = [%{item_id: 1, item_variation_id: nil, quantity: 1, unit_price_cents: 10_000}]

      assert {:ok, best} = Discounts.best_discount(event.id, cart_items)
      assert best.discount_cents == 2000
      assert best.rule.name == "Fixo"
    end

    test "returns :no_discount when no rules match" do
      org = org_fixture()
      event = event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 10,
          value_type: "fixed",
          value: 500
        })

      cart_items = [%{item_id: 1, item_variation_id: nil, quantity: 1, unit_price_cents: 5000}]

      assert {:error, :no_discount} = Discounts.best_discount(event.id, cart_items)
    end

    test "returns :no_discount when event has no rules" do
      org = org_fixture()
      event = event_fixture(org)

      cart_items = [%{item_id: 1, item_variation_id: nil, quantity: 1, unit_price_cents: 5000}]

      assert {:error, :no_discount} = Discounts.best_discount(event.id, cart_items)
    end
  end

  # ---------------------------------------------------------------------------
  # compute_discount_for_cart/2
  # ---------------------------------------------------------------------------

  describe "compute_discount_for_cart/2" do
    test "returns 0 when no rules match" do
      org = org_fixture()
      event = event_fixture(org)

      cart_items = [%{item_id: 1, item_variation_id: nil, quantity: 1, unit_price_cents: 5000}]

      assert Discounts.compute_discount_for_cart(event.id, cart_items) == 0
    end

    test "returns correct cents when a rule matches (percentage)" do
      org = org_fixture()
      event = event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "percentage",
          value: 500
        })

      # 5% of 10000 = 500
      cart_items = [%{item_id: 1, item_variation_id: nil, quantity: 1, unit_price_cents: 10_000}]

      assert Discounts.compute_discount_for_cart(event.id, cart_items) == 500
    end

    test "returns correct cents when a rule matches (fixed)" do
      org = org_fixture()
      event = event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "fixed",
          value: 750
        })

      cart_items = [%{item_id: 1, item_variation_id: nil, quantity: 1, unit_price_cents: 5000}]

      assert Discounts.compute_discount_for_cart(event.id, cart_items) == 750
    end

    test "fixed discount is capped at subtotal" do
      org = org_fixture()
      event = event_fixture(org)

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "fixed",
          value: 99_999
        })

      cart_items = [%{item_id: 1, item_variation_id: nil, quantity: 1, unit_price_cents: 1000}]

      # discount cannot exceed subtotal
      assert Discounts.compute_discount_for_cart(event.id, cart_items) == 1000
    end
  end

  # ---------------------------------------------------------------------------
  # apply_best_discount/2
  # ---------------------------------------------------------------------------

  describe "apply_best_discount/2" do
    test "inserts OrderDiscount and updates order.total_cents" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{price_cents: 5000})

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "fixed",
          value: 1000
        })

      order = order_fixture(event, 5000)

      # Build a fake order_items list (mimicking what preload returns)
      order_item = %Pretex.Orders.OrderItem{
        order_id: order.id,
        item_id: item.id,
        item_variation_id: nil,
        item: item,
        item_variation: nil,
        quantity: 1,
        unit_price_cents: 5000
      }

      order_with_items = %{order | order_items: [order_item]}

      assert {:ok, updated_order} = Discounts.apply_best_discount(order_with_items, event.id)
      assert updated_order.total_cents == 4000

      discount = Repo.get_by!(OrderDiscount, order_id: order.id)
      assert discount.discount_cents == 1000
    end

    test "caps discount so total does not go below zero" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{price_cents: 500})

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 1,
          value_type: "fixed",
          value: 99_999
        })

      order = order_fixture(event, 500)

      order_item = %Pretex.Orders.OrderItem{
        order_id: order.id,
        item_id: item.id,
        item_variation_id: nil,
        item: item,
        item_variation: nil,
        quantity: 1,
        unit_price_cents: 500
      }

      order_with_items = %{order | order_items: [order_item]}

      assert {:ok, updated_order} = Discounts.apply_best_discount(order_with_items, event.id)
      assert updated_order.total_cents == 0

      discount = Repo.get_by!(OrderDiscount, order_id: order.id)
      assert discount.discount_cents == 500
    end

    test "returns unchanged order when no rules match" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{price_cents: 5000})

      _rule =
        discount_rule_fixture(event, %{
          min_quantity: 100,
          value_type: "fixed",
          value: 1000
        })

      order = order_fixture(event, 5000)

      order_item = %Pretex.Orders.OrderItem{
        order_id: order.id,
        item_id: item.id,
        item_variation_id: nil,
        item: item,
        item_variation: nil,
        quantity: 1,
        unit_price_cents: 5000
      }

      order_with_items = %{order | order_items: [order_item]}

      assert {:ok, unchanged_order} = Discounts.apply_best_discount(order_with_items, event.id)
      assert unchanged_order.total_cents == 5000

      refute Repo.get_by(OrderDiscount, order_id: order.id)
    end

    test "returns unchanged order when event has no discount rules" do
      org = org_fixture()
      event = event_fixture(org)
      item = item_fixture(event, %{price_cents: 5000})

      order = order_fixture(event, 5000)

      order_item = %Pretex.Orders.OrderItem{
        order_id: order.id,
        item_id: item.id,
        item_variation_id: nil,
        item: item,
        item_variation: nil,
        quantity: 1,
        unit_price_cents: 5000
      }

      order_with_items = %{order | order_items: [order_item]}

      assert {:ok, unchanged_order} = Discounts.apply_best_discount(order_with_items, event.id)
      assert unchanged_order.total_cents == 5000
    end
  end
end
