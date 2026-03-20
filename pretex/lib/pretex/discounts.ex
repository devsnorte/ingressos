defmodule Pretex.Discounts do
  @moduledoc "Manages automatic discount rules for events."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Discounts.DiscountRule

  alias Pretex.Discounts.OrderDiscount
  alias Pretex.Orders.Order

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc "List all discount rules for an event, ordered by name asc. Preloads :scoped_items."
  def list_discount_rules(%{id: event_id}) do
    DiscountRule
    |> where([dr], dr.event_id == ^event_id)
    |> order_by([dr], asc: dr.name)
    |> preload(:scoped_items)
    |> Repo.all()
  end

  @doc "Get a discount rule by id, raises if not found. Preloads :scoped_items."
  def get_discount_rule!(id) do
    DiscountRule
    |> preload(:scoped_items)
    |> Repo.get!(id)
  end

  @doc "Create a discount rule for an event."
  def create_discount_rule(%{id: event_id}, attrs) do
    %DiscountRule{}
    |> DiscountRule.changeset(attrs)
    |> Ecto.Changeset.put_change(:event_id, event_id)
    |> Repo.insert()
  end

  @doc "Update a discount rule."
  def update_discount_rule(%DiscountRule{} = rule, attrs) do
    rule
    |> DiscountRule.changeset(attrs)
    |> Repo.update()
  end

  @doc "Delete a discount rule."
  def delete_discount_rule(%DiscountRule{} = rule) do
    Repo.delete(rule)
  end

  @doc "Return a changeset for a discount rule (used by forms)."
  def change_discount_rule(%DiscountRule{} = rule, attrs \\ %{}) do
    DiscountRule.changeset(rule, attrs)
  end

  # ---------------------------------------------------------------------------
  # Evaluation
  # ---------------------------------------------------------------------------

  @doc """
  Evaluate all active discount rules for an event against the given cart items.

  cart_items is a list of maps with keys:
    %{item_id:, item_variation_id:, quantity:, unit_price_cents:}

  Returns a list of matching %{rule: rule, discount_cents: integer} sorted
  descending by discount_cents (highest discount first).
  """
  def evaluate_cart(event_id, cart_items) when is_list(cart_items) do
    rules =
      DiscountRule
      |> where([dr], dr.event_id == ^event_id and dr.active == true)
      |> preload(:scoped_items)
      |> Repo.all()

    rules
    |> Enum.filter(&rule_matches?(&1, cart_items))
    |> Enum.map(fn rule ->
      discount_cents = compute_discount(rule, cart_items)
      %{rule: rule, discount_cents: discount_cents}
    end)
    |> Enum.sort_by(& &1.discount_cents, :desc)
  end

  @doc """
  Returns the single best (highest) discount for the cart.
  Returns {:ok, %{rule: rule, discount_cents: integer}} | {:error, :no_discount}
  """
  def best_discount(event_id, cart_items) do
    case evaluate_cart(event_id, cart_items) do
      [] -> {:error, :no_discount}
      [best | _] -> {:ok, best}
    end
  end

  @doc """
  Quick preview of the best discount in cents. Returns 0 if no rule matches.
  """
  def compute_discount_for_cart(event_id, cart_items) do
    case best_discount(event_id, cart_items) do
      {:ok, %{discount_cents: cents}} -> cents
      {:error, :no_discount} -> 0
    end
  end

  @doc """
  Apply the best matching discount rule to an order.

  Expects order to have order_items preloaded with :item and :item_variation.
  Inserts an OrderDiscount record and updates order.total_cents.

  Uses bare Repo operations (no nested transaction) so it participates in
  any outer transaction the caller has started.

  Returns {:ok, updated_order} | {:error, reason}
  """
  def apply_best_discount(%Order{} = order, event_id) do
    cart_items = build_cart_items_from_order(order)

    case best_discount(event_id, cart_items) do
      {:error, :no_discount} ->
        {:ok, order}

      {:ok, %{rule: rule, discount_cents: discount_cents}} ->
        # Cap so total never goes below 0
        capped_discount = min(discount_cents, order.total_cents)

        od_changeset =
          %OrderDiscount{}
          |> OrderDiscount.changeset(%{
            name: rule.name,
            discount_cents: capped_discount,
            value_type: rule.value_type,
            value: rule.value,
            order_id: order.id,
            discount_rule_id: rule.id
          })

        case Repo.insert(od_changeset) do
          {:ok, _order_discount} ->
            new_total = max(0, order.total_cents - capped_discount)

            updated =
              order
              |> Ecto.Changeset.change(total_cents: new_total)
              |> Repo.update!()

            {:ok, updated}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_cart_items_from_order(%Order{order_items: order_items})
       when is_list(order_items) do
    Enum.map(order_items, fn oi ->
      unit_price =
        if oi.item_variation && oi.item_variation.price_cents do
          oi.item_variation.price_cents
        else
          oi.item.price_cents
        end

      %{
        item_id: oi.item_id,
        item_variation_id: oi.item_variation_id,
        quantity: oi.quantity,
        unit_price_cents: unit_price
      }
    end)
  end

  defp build_cart_items_from_order(_order), do: []

  defp rule_matches?(%DiscountRule{condition_type: "min_quantity"} = rule, cart_items) do
    scoped_item_ids = scoped_item_ids(rule)

    total_quantity =
      if scoped_item_ids == [] do
        # No scope restriction — count ALL cart items
        Enum.sum(Enum.map(cart_items, & &1.quantity))
      else
        # Only count items in the scoped set
        cart_items
        |> Enum.filter(&(&1.item_id in scoped_item_ids))
        |> Enum.sum_by(& &1.quantity)
      end

    total_quantity >= rule.min_quantity
  end

  defp rule_matches?(%DiscountRule{condition_type: "item_combo"} = rule, cart_items) do
    scoped_item_ids = scoped_item_ids(rule)

    if scoped_item_ids == [] do
      # item_combo with no scoped items never matches
      false
    else
      cart_item_ids = MapSet.new(cart_items, & &1.item_id)

      Enum.all?(scoped_item_ids, &MapSet.member?(cart_item_ids, &1))
    end
  end

  defp rule_matches?(_rule, _cart_items), do: false

  defp scoped_item_ids(%DiscountRule{scoped_items: scoped_items})
       when is_list(scoped_items) do
    scoped_items
    |> Enum.map(& &1.item_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp scoped_item_ids(_), do: []

  defp compute_discount(%DiscountRule{} = rule, cart_items) do
    scoped_item_ids = scoped_item_ids(rule)

    subtotal =
      if scoped_item_ids == [] do
        Enum.sum(Enum.map(cart_items, &(&1.quantity * &1.unit_price_cents)))
      else
        cart_items
        |> Enum.filter(&(&1.item_id in scoped_item_ids))
        |> Enum.sum_by(&(&1.quantity * &1.unit_price_cents))
      end

    case rule.value_type do
      "fixed" ->
        min(rule.value, subtotal)

      "percentage" ->
        round(subtotal * rule.value / 10_000)

      _ ->
        0
    end
  end
end
