defmodule Pretex.Fees do
  @moduledoc "Manages fee rules and order fees."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Fees.FeeRule
  alias Pretex.Fees.OrderFee
  alias Pretex.Orders.Order

  # ---------------------------------------------------------------------------
  # Fee Rule CRUD
  # ---------------------------------------------------------------------------

  @doc "List all fee rules for an event, ordered by name."
  def list_fee_rules(%{id: event_id}) do
    FeeRule
    |> where([fr], fr.event_id == ^event_id)
    |> order_by([fr], asc: fr.name)
    |> Repo.all()
  end

  @doc "Get a fee rule by id, raises if not found."
  def get_fee_rule!(id), do: Repo.get!(FeeRule, id)

  @doc "Create a fee rule for an event."
  def create_fee_rule(%{id: event_id}, attrs) do
    %FeeRule{}
    |> FeeRule.changeset(attrs)
    |> Ecto.Changeset.put_change(:event_id, event_id)
    |> Repo.insert()
  end

  @doc "Update a fee rule."
  def update_fee_rule(%FeeRule{} = fee_rule, attrs) do
    fee_rule
    |> FeeRule.changeset(attrs)
    |> Repo.update()
  end

  @doc "Delete a fee rule."
  def delete_fee_rule(%FeeRule{} = fee_rule) do
    Repo.delete(fee_rule)
  end

  @doc "Return a changeset for a fee rule (used by forms)."
  def change_fee_rule(%FeeRule{} = fee_rule, attrs \\ %{}) do
    FeeRule.changeset(fee_rule, attrs)
  end

  # ---------------------------------------------------------------------------
  # Fee Application
  # ---------------------------------------------------------------------------

  @doc """
  Apply automatic fee rules to an order.

  Loads all active automatic fee rules for the event, computes the amount for
  each, inserts OrderFee records, and updates the order's total_cents.
  Everything runs inside a single Repo.transaction.

  Returns {:ok, updated_order} | {:error, reason}.
  """
  def apply_automatic_fees(%Order{} = order, event_id) when is_integer(event_id) do
    rules =
      FeeRule
      |> where(
        [fr],
        fr.event_id == ^event_id and fr.active == true and fr.apply_mode == "automatic"
      )
      |> Repo.all()

    if rules == [] do
      {:ok, order}
    else
      Repo.transaction(fn ->
        fees =
          Enum.map(rules, fn rule ->
            amount_cents = compute_amount(rule, order.total_cents)

            changeset =
              %OrderFee{}
              |> OrderFee.changeset(%{
                name: rule.name,
                fee_type: rule.fee_type,
                amount_cents: amount_cents,
                value_type: rule.value_type,
                value: rule.value,
                order_id: order.id,
                fee_rule_id: rule.id
              })

            case Repo.insert(changeset) do
              {:ok, fee} -> fee
              {:error, cs} -> Repo.rollback(cs)
            end
          end)

        total_fee_cents = Enum.sum(Enum.map(fees, & &1.amount_cents))
        new_total = order.total_cents + total_fee_cents

        updated_order =
          order
          |> Ecto.Changeset.change(total_cents: new_total)
          |> Repo.update!()

        updated_order
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Fee Queries
  # ---------------------------------------------------------------------------

  @doc "List all OrderFee records for an order, ordered by insertion time."
  def list_order_fees(%Order{id: order_id}) do
    OrderFee
    |> where([of], of.order_id == ^order_id)
    |> order_by([of], asc: of.inserted_at)
    |> Repo.all()
  end

  @doc """
  Compute a preview of automatic fees for a cart (read-only, does NOT persist).

  Returns a list of maps with keys: name, fee_type, amount_cents, value_type, value.
  """
  def compute_fees_for_cart(%{id: event_id}, subtotal_cents) do
    FeeRule
    |> where(
      [fr],
      fr.event_id == ^event_id and fr.active == true and fr.apply_mode == "automatic"
    )
    |> order_by([fr], asc: fr.name)
    |> Repo.all()
    |> Enum.map(fn rule ->
      %{
        name: rule.name,
        fee_type: rule.fee_type,
        amount_cents: compute_amount(rule, subtotal_cents),
        value_type: rule.value_type,
        value: rule.value
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Totals Helper
  # ---------------------------------------------------------------------------

  @doc "Sum amount_cents for a list of OrderFee records or fee preview maps."
  def total_fees_cents(fees) when is_list(fees) do
    Enum.sum(
      Enum.map(fees, fn
        %OrderFee{amount_cents: a} -> a
        %{amount_cents: a} -> a
      end)
    )
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp compute_amount(%FeeRule{value_type: "fixed", value: value}, _subtotal), do: value

  defp compute_amount(%FeeRule{value_type: "percentage", value: value}, subtotal_cents) do
    round(subtotal_cents * value / 10_000)
  end
end
