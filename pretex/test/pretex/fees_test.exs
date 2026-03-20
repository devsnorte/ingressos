defmodule Pretex.FeesTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  alias Pretex.Fees
  alias Pretex.Fees.FeeRule
  alias Pretex.Fees.OrderFee
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp fee_rule_fixture(event, attrs \\ %{}) do
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

  defp order_fixture(event) do
    {:ok, order} =
      %Pretex.Orders.Order{}
      |> Ecto.Changeset.change(%{
        event_id: event.id,
        status: "pending",
        total_cents: 5000,
        email: "test@example.com",
        name: "Test User",
        confirmation_code: "TEST#{System.unique_integer([:positive])}",
        expires_at:
          DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
      })
      |> Repo.insert()

    order
  end

  # ---------------------------------------------------------------------------
  # list_fee_rules/1
  # ---------------------------------------------------------------------------

  describe "list_fee_rules/1" do
    test "returns all fee rules for an event ordered by name" do
      org = org_fixture()
      event = event_fixture(org)

      _rule_b = fee_rule_fixture(event, %{name: "Beta Taxa"})
      _rule_a = fee_rule_fixture(event, %{name: "Alpha Taxa"})
      _rule_c = fee_rule_fixture(event, %{name: "Gamma Taxa"})

      rules = Fees.list_fee_rules(event)
      names = Enum.map(rules, & &1.name)

      assert names == ["Alpha Taxa", "Beta Taxa", "Gamma Taxa"]
    end

    test "returns only fee rules belonging to the given event" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)

      rule1 = fee_rule_fixture(event1, %{name: "Taxa Evento 1"})
      _rule2 = fee_rule_fixture(event2, %{name: "Taxa Evento 2"})

      rules = Fees.list_fee_rules(event1)
      assert length(rules) == 1
      assert hd(rules).id == rule1.id
    end

    test "returns empty list when event has no fee rules" do
      org = org_fixture()
      event = event_fixture(org)

      assert Fees.list_fee_rules(event) == []
    end
  end

  # ---------------------------------------------------------------------------
  # get_fee_rule!/1
  # ---------------------------------------------------------------------------

  describe "get_fee_rule!/1" do
    test "returns the fee rule with the given id" do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      found = Fees.get_fee_rule!(rule.id)
      assert found.id == rule.id
      assert found.name == rule.name
    end

    test "raises Ecto.NoResultsError when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Fees.get_fee_rule!(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_fee_rule/2
  # ---------------------------------------------------------------------------

  describe "create_fee_rule/2" do
    test "creates a fee rule with valid fixed attrs" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Taxa Fixa",
        fee_type: "service",
        value_type: "fixed",
        value: 300,
        apply_mode: "automatic"
      }

      assert {:ok, %FeeRule{} = rule} = Fees.create_fee_rule(event, attrs)
      assert rule.name == "Taxa Fixa"
      assert rule.fee_type == "service"
      assert rule.value_type == "fixed"
      assert rule.value == 300
      assert rule.apply_mode == "automatic"
      assert rule.active == true
      assert rule.event_id == event.id
    end

    test "creates a fee rule with valid percentage attrs" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Taxa Percentual",
        fee_type: "handling",
        value_type: "percentage",
        value: 500,
        apply_mode: "automatic"
      }

      assert {:ok, %FeeRule{} = rule} = Fees.create_fee_rule(event, attrs)
      assert rule.value_type == "percentage"
      assert rule.value == 500
    end

    test "creates a fee rule with manual apply_mode" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Taxa Manual",
        fee_type: "custom",
        value_type: "fixed",
        value: 100,
        apply_mode: "manual"
      }

      assert {:ok, %FeeRule{} = rule} = Fees.create_fee_rule(event, attrs)
      assert rule.apply_mode == "manual"
    end

    test "creates a fee rule with zero value" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Taxa Zero",
        fee_type: "service",
        value_type: "fixed",
        value: 0,
        apply_mode: "automatic"
      }

      assert {:ok, %FeeRule{}} = Fees.create_fee_rule(event, attrs)
    end

    test "returns error changeset with negative value" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Taxa Negativa",
        fee_type: "service",
        value_type: "fixed",
        value: -100,
        apply_mode: "automatic"
      }

      assert {:error, changeset} = Fees.create_fee_rule(event, attrs)
      assert %{value: [_msg]} = errors_on(changeset)
    end

    test "returns error changeset when percentage exceeds 10000 (100%)" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Taxa Impossível",
        fee_type: "service",
        value_type: "percentage",
        value: 10001,
        apply_mode: "automatic"
      }

      assert {:error, changeset} = Fees.create_fee_rule(event, attrs)
      assert %{value: [_msg]} = errors_on(changeset)
    end

    test "percentage of exactly 10000 (100%) is valid" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Taxa 100%",
        fee_type: "service",
        value_type: "percentage",
        value: 10000,
        apply_mode: "automatic"
      }

      assert {:ok, %FeeRule{}} = Fees.create_fee_rule(event, attrs)
    end

    test "returns error changeset when name is missing" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{fee_type: "service", value_type: "fixed", value: 100, apply_mode: "automatic"}

      assert {:error, changeset} = Fees.create_fee_rule(event, attrs)
      assert %{name: [_msg]} = errors_on(changeset)
    end

    test "returns error changeset with invalid fee_type" do
      org = org_fixture()
      event = event_fixture(org)

      attrs = %{
        name: "Taxa",
        fee_type: "invalid_type",
        value_type: "fixed",
        value: 100,
        apply_mode: "automatic"
      }

      assert {:error, changeset} = Fees.create_fee_rule(event, attrs)
      assert %{fee_type: [_msg]} = errors_on(changeset)
    end

    test "creates with all fee_type values" do
      org = org_fixture()
      event = event_fixture(org)

      for fee_type <- ~w(service handling shipping cancellation custom) do
        attrs = %{
          name: "Taxa #{fee_type}",
          fee_type: fee_type,
          value_type: "fixed",
          value: 100,
          apply_mode: "automatic"
        }

        assert {:ok, %FeeRule{fee_type: ^fee_type}} = Fees.create_fee_rule(event, attrs)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # update_fee_rule/2
  # ---------------------------------------------------------------------------

  describe "update_fee_rule/2" do
    test "updates fee rule fields" do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{name: "Original", value: 100})

      assert {:ok, updated} = Fees.update_fee_rule(rule, %{name: "Atualizada", value: 500})
      assert updated.name == "Atualizada"
      assert updated.value == 500
    end

    test "updates active flag" do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{active: true})

      assert {:ok, updated} = Fees.update_fee_rule(rule, %{active: false})
      assert updated.active == false
    end

    test "returns error changeset on invalid update" do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      assert {:error, changeset} = Fees.update_fee_rule(rule, %{value: -50})
      assert %{value: [_msg]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # delete_fee_rule/1
  # ---------------------------------------------------------------------------

  describe "delete_fee_rule/1" do
    test "removes the fee rule from the database" do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      assert {:ok, _deleted} = Fees.delete_fee_rule(rule)
      assert_raise Ecto.NoResultsError, fn -> Fees.get_fee_rule!(rule.id) end
    end

    test "returns the deleted fee rule" do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      assert {:ok, deleted} = Fees.delete_fee_rule(rule)
      assert deleted.id == rule.id
    end
  end

  # ---------------------------------------------------------------------------
  # change_fee_rule/2
  # ---------------------------------------------------------------------------

  describe "change_fee_rule/2" do
    test "returns a changeset for a fee rule" do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      changeset = Fees.change_fee_rule(rule)
      assert %Ecto.Changeset{} = changeset
    end

    test "returns a changeset with applied attrs" do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event)

      changeset = Fees.change_fee_rule(rule, %{name: "Novo Nome"})
      assert changeset.changes.name == "Novo Nome"
    end
  end

  # ---------------------------------------------------------------------------
  # compute_fees_for_cart/2
  # ---------------------------------------------------------------------------

  describe "compute_fees_for_cart/2" do
    test "returns empty list when event has no automatic fee rules" do
      org = org_fixture()
      event = event_fixture(org)

      assert Fees.compute_fees_for_cart(event, 5000) == []
    end

    test "computes fixed fee preview correctly" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa Fixa",
        value_type: "fixed",
        value: 300,
        apply_mode: "automatic"
      })

      fees = Fees.compute_fees_for_cart(event, 10000)

      assert length(fees) == 1
      fee = hd(fees)
      assert fee.name == "Taxa Fixa"
      assert fee.amount_cents == 300
      assert fee.value_type == "fixed"
      assert fee.value == 300
    end

    test "computes percentage fee preview correctly" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa 5%",
        value_type: "percentage",
        value: 500,
        apply_mode: "automatic"
      })

      # 5% of R$100.00 (10000 cents) = R$5.00 (500 cents)
      fees = Fees.compute_fees_for_cart(event, 10000)

      assert length(fees) == 1
      fee = hd(fees)
      assert fee.amount_cents == 500
      assert fee.value_type == "percentage"
      assert fee.value == 500
    end

    test "computes percentage fee on zero subtotal as zero" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa Percentual",
        value_type: "percentage",
        value: 1000,
        apply_mode: "automatic"
      })

      fees = Fees.compute_fees_for_cart(event, 0)

      assert length(fees) == 1
      assert hd(fees).amount_cents == 0
    end

    test "only returns active fee rules" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{name: "Taxa Ativa", active: true, value: 200})
      fee_rule_fixture(event, %{name: "Taxa Inativa", active: false, value: 300})

      fees = Fees.compute_fees_for_cart(event, 5000)

      assert length(fees) == 1
      assert hd(fees).name == "Taxa Ativa"
    end

    test "only returns automatic fee rules (not manual)" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{name: "Taxa Automática", apply_mode: "automatic", value: 200})
      fee_rule_fixture(event, %{name: "Taxa Manual", apply_mode: "manual", value: 300})

      fees = Fees.compute_fees_for_cart(event, 5000)

      assert length(fees) == 1
      assert hd(fees).name == "Taxa Automática"
    end

    test "returns multiple fees ordered by name" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{name: "Zebra Taxa", value: 100, apply_mode: "automatic"})
      fee_rule_fixture(event, %{name: "Alpha Taxa", value: 200, apply_mode: "automatic"})

      fees = Fees.compute_fees_for_cart(event, 5000)
      names = Enum.map(fees, & &1.name)

      assert names == ["Alpha Taxa", "Zebra Taxa"]
    end

    test "returns preview maps with required keys" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa",
        fee_type: "service",
        value_type: "fixed",
        value: 150,
        apply_mode: "automatic"
      })

      [fee] = Fees.compute_fees_for_cart(event, 3000)

      assert Map.has_key?(fee, :name)
      assert Map.has_key?(fee, :fee_type)
      assert Map.has_key?(fee, :amount_cents)
      assert Map.has_key?(fee, :value_type)
      assert Map.has_key?(fee, :value)
      assert fee.fee_type == "service"
    end

    test "does NOT persist any records to database" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{value: 200, apply_mode: "automatic"})

      order = order_fixture(event)
      before_count = Repo.aggregate(OrderFee, :count)

      Fees.compute_fees_for_cart(event, 5000)

      after_count = Repo.aggregate(OrderFee, :count)
      assert before_count == after_count

      # order should also be unchanged
      reloaded = Repo.get!(Pretex.Orders.Order, order.id)
      assert reloaded.total_cents == order.total_cents
    end
  end

  # ---------------------------------------------------------------------------
  # apply_automatic_fees/2
  # ---------------------------------------------------------------------------

  describe "apply_automatic_fees/2" do
    test "inserts OrderFee records for each automatic rule" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{name: "Taxa A", value: 200, apply_mode: "automatic"})
      fee_rule_fixture(event, %{name: "Taxa B", value: 300, apply_mode: "automatic"})

      order = order_fixture(event)
      original_total = order.total_cents

      assert {:ok, updated_order} = Fees.apply_automatic_fees(order, event.id)

      order_fees = Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))
      assert length(order_fees) == 2

      assert updated_order.total_cents == original_total + 200 + 300
    end

    test "updates order total_cents by adding fee amounts" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Taxa Fixa",
        value_type: "fixed",
        value: 500,
        apply_mode: "automatic"
      })

      order = order_fixture(event)
      assert {:ok, updated} = Fees.apply_automatic_fees(order, event.id)

      assert updated.total_cents == order.total_cents + 500
    end

    test "computes percentage fee based on order total_cents" do
      org = org_fixture()
      event = event_fixture(org)

      # 10% fee = 1000 basis points
      fee_rule_fixture(event, %{
        name: "Taxa 10%",
        value_type: "percentage",
        value: 1000,
        apply_mode: "automatic"
      })

      order = order_fixture(event)
      # order has 5000 total_cents; 10% = 500
      assert {:ok, updated} = Fees.apply_automatic_fees(order, event.id)

      assert updated.total_cents == 5000 + 500
    end

    test "returns unchanged order when no automatic rules exist" do
      org = org_fixture()
      event = event_fixture(org)

      order = order_fixture(event)
      original_total = order.total_cents

      assert {:ok, returned_order} = Fees.apply_automatic_fees(order, event.id)
      assert returned_order.total_cents == original_total

      count = Repo.aggregate(OrderFee, :count)
      assert count == 0
    end

    test "does not apply manual rules" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{name: "Manual", value: 500, apply_mode: "manual"})

      order = order_fixture(event)
      original_total = order.total_cents

      assert {:ok, returned} = Fees.apply_automatic_fees(order, event.id)
      assert returned.total_cents == original_total
    end

    test "does not apply inactive rules" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{
        name: "Inativa",
        value: 500,
        apply_mode: "automatic",
        active: false
      })

      order = order_fixture(event)
      original_total = order.total_cents

      assert {:ok, returned} = Fees.apply_automatic_fees(order, event.id)
      assert returned.total_cents == original_total
    end

    test "stores fee_rule_id on each OrderFee" do
      org = org_fixture()
      event = event_fixture(org)
      rule = fee_rule_fixture(event, %{value: 100, apply_mode: "automatic"})

      order = order_fixture(event)
      assert {:ok, _} = Fees.apply_automatic_fees(order, event.id)

      [order_fee] = Repo.all(Ecto.Query.where(OrderFee, order_id: ^order.id))
      assert order_fee.fee_rule_id == rule.id
    end
  end

  # ---------------------------------------------------------------------------
  # list_order_fees/1
  # ---------------------------------------------------------------------------

  describe "list_order_fees/1" do
    test "returns all OrderFee records for an order" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{name: "Taxa 1", value: 100, apply_mode: "automatic"})
      fee_rule_fixture(event, %{name: "Taxa 2", value: 200, apply_mode: "automatic"})

      order = order_fixture(event)
      {:ok, _} = Fees.apply_automatic_fees(order, event.id)

      fees = Fees.list_order_fees(order)
      assert length(fees) == 2
    end

    test "returns empty list when order has no fees" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)

      assert Fees.list_order_fees(order) == []
    end

    test "returns fees ordered by inserted_at" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{name: "Alpha Taxa", value: 100, apply_mode: "automatic"})
      fee_rule_fixture(event, %{name: "Beta Taxa", value: 200, apply_mode: "automatic"})

      order = order_fixture(event)
      {:ok, _} = Fees.apply_automatic_fees(order, event.id)

      fees = Fees.list_order_fees(order)
      assert is_list(fees)
      assert length(fees) == 2
    end

    test "returns only fees belonging to the specified order" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{value: 100, apply_mode: "automatic"})

      order1 = order_fixture(event)
      order2 = order_fixture(event)

      {:ok, _} = Fees.apply_automatic_fees(order1, event.id)
      {:ok, _} = Fees.apply_automatic_fees(order2, event.id)

      fees1 = Fees.list_order_fees(order1)
      fees2 = Fees.list_order_fees(order2)

      assert length(fees1) == 1
      assert length(fees2) == 1
      assert hd(fees1).order_id == order1.id
      assert hd(fees2).order_id == order2.id
    end
  end

  # ---------------------------------------------------------------------------
  # total_fees_cents/1
  # ---------------------------------------------------------------------------

  describe "total_fees_cents/1" do
    test "returns 0 for an empty list" do
      assert Fees.total_fees_cents([]) == 0
    end

    test "sums amount_cents from fee preview maps" do
      fees = [
        %{name: "A", fee_type: "service", amount_cents: 200, value_type: "fixed", value: 200},
        %{name: "B", fee_type: "handling", amount_cents: 300, value_type: "fixed", value: 300}
      ]

      assert Fees.total_fees_cents(fees) == 500
    end

    test "sums amount_cents from OrderFee structs" do
      org = org_fixture()
      event = event_fixture(org)

      fee_rule_fixture(event, %{name: "Taxa A", value: 150, apply_mode: "automatic"})
      fee_rule_fixture(event, %{name: "Taxa B", value: 350, apply_mode: "automatic"})

      order = order_fixture(event)
      {:ok, _} = Fees.apply_automatic_fees(order, event.id)

      order_fees = Fees.list_order_fees(order)
      assert Fees.total_fees_cents(order_fees) == 500
    end

    test "works with a single fee" do
      fees = [
        %{name: "Only", fee_type: "service", amount_cents: 999, value_type: "fixed", value: 999}
      ]

      assert Fees.total_fees_cents(fees) == 999
    end
  end
end
