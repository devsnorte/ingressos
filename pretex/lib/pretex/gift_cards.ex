defmodule Pretex.GiftCards do
  @moduledoc "Manages gift cards for organizations."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.GiftCards.GiftCard
  alias Pretex.GiftCards.GiftCardRedemption
  alias Pretex.Organizations.Organization

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc "List all gift cards for an organization, ordered by inserted_at desc. Preloads :redemptions."
  def list_gift_cards(%Organization{id: org_id}) do
    GiftCard
    |> where([gc], gc.organization_id == ^org_id)
    |> order_by([gc], desc: gc.inserted_at)
    |> preload(:redemptions)
    |> Repo.all()
  end

  @doc "Get a gift card by id, raises if not found. Preloads :redemptions."
  def get_gift_card!(id) do
    GiftCard
    |> preload(:redemptions)
    |> Repo.get!(id)
  end

  @doc """
  Look up a gift card by code (case-insensitive). Gift card codes are globally unique.
  Returns {:ok, gift_card} | {:error, :not_found}.
  """
  def get_gift_card_by_code(code) when is_binary(code) do
    normalized = String.upcase(String.trim(code))

    case Repo.get_by(GiftCard, code: normalized) do
      nil -> {:error, :not_found}
      gc -> {:ok, gc}
    end
  end

  def get_gift_card_by_code(_), do: {:error, :not_found}

  @doc """
  Create a gift card for an organization.
  If initial_balance_cents not given, it defaults to balance_cents.
  Returns {:ok, gift_card} | {:error, changeset}.
  """
  def create_gift_card(%Organization{} = org, attrs) do
    attrs =
      if Map.get(attrs, :initial_balance_cents) || Map.get(attrs, "initial_balance_cents") do
        attrs
      else
        balance = Map.get(attrs, :balance_cents) || Map.get(attrs, "balance_cents") || 0

        if is_map(attrs) and map_size(attrs) > 0 and match?(%{}, attrs) do
          if is_atom(hd(Map.keys(attrs))) do
            Map.put_new(attrs, :initial_balance_cents, balance)
          else
            Map.put_new(attrs, "initial_balance_cents", balance)
          end
        else
          Map.put_new(attrs, :initial_balance_cents, balance)
        end
      end

    %GiftCard{}
    |> GiftCard.changeset(attrs)
    |> Ecto.Changeset.put_change(:organization_id, org.id)
    |> Repo.insert()
  end

  @doc "Update a gift card. Returns {:ok, gift_card} | {:error, changeset}."
  def update_gift_card(%GiftCard{} = gc, attrs) do
    gc
    |> GiftCard.changeset(attrs)
    |> Repo.update()
  end

  @doc "Delete a gift card. Returns {:ok, gift_card} | {:error, changeset}."
  def delete_gift_card(%GiftCard{} = gc) do
    Repo.delete(gc)
  end

  @doc "Return a changeset for a gift card (used by forms)."
  def change_gift_card(%GiftCard{} = gc, attrs \\ %{}) do
    GiftCard.changeset(gc, attrs)
  end

  @doc """
  Add amount_cents to a gift card's balance.
  Inserts a GiftCardRedemption with kind: "credit", note: "Top-up".
  Returns {:ok, gift_card} | {:error, reason}.
  """
  def top_up(%GiftCard{} = gc, amount_cents) when is_integer(amount_cents) and amount_cents > 0 do
    Repo.transaction(fn ->
      new_balance = gc.balance_cents + amount_cents

      {:ok, updated_gc} =
        gc
        |> Ecto.Changeset.change(balance_cents: new_balance)
        |> Repo.update()

      %GiftCardRedemption{}
      |> GiftCardRedemption.changeset(%{
        amount_cents: amount_cents,
        kind: "credit",
        note: "Top-up",
        gift_card_id: gc.id
      })
      |> Repo.insert!()

      updated_gc
    end)
  end

  def top_up(%GiftCard{}, _amount), do: {:error, :invalid_amount}

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  @doc """
  Validates a gift card code for checkout.
  Checks: exists, active, belongs to organization_id, not expired, balance > 0.
  Returns {:ok, gift_card} | {:error, reason}.
  reason: :not_found | :wrong_organization | :expired | :empty | :inactive
  """
  def validate_for_checkout(code, organization_id) when is_binary(code) do
    case get_gift_card_by_code(code) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, gc} ->
        now = DateTime.utc_now()

        cond do
          gc.organization_id != organization_id ->
            {:error, :wrong_organization}

          !gc.active ->
            {:error, :inactive}

          gc.expires_at != nil and DateTime.compare(gc.expires_at, now) == :lt ->
            {:error, :expired}

          gc.balance_cents <= 0 ->
            {:error, :empty}

          true ->
            {:ok, gc}
        end
    end
  end

  def validate_for_checkout(_, _), do: {:error, :not_found}

  # ---------------------------------------------------------------------------
  # Redemption
  # ---------------------------------------------------------------------------

  @doc """
  Redeem a gift card against an order.
  requested_cents = order's remaining total.
  actual_deduction = min(gift_card.balance_cents, requested_cents).
  Updates gift_card.balance_cents and inserts a GiftCardRedemption{kind: "debit"}.
  NOTE: uses bare Repo ops (no nested transaction) — participates in caller's transaction.
  Returns {:ok, %{gift_card: updated_gc, deduction_cents: actual_deduction}}.
  """
  def redeem(%GiftCard{} = gc, order, requested_cents)
      when is_integer(requested_cents) and requested_cents >= 0 do
    actual_deduction = min(gc.balance_cents, requested_cents)

    if actual_deduction <= 0 do
      {:ok, %{gift_card: gc, deduction_cents: 0}}
    else
      new_balance = gc.balance_cents - actual_deduction

      case gc |> Ecto.Changeset.change(balance_cents: new_balance) |> Repo.update() do
        {:ok, updated_gc} ->
          %GiftCardRedemption{}
          |> GiftCardRedemption.changeset(%{
            kind: "debit",
            amount_cents: actual_deduction,
            gift_card_id: gc.id,
            order_id: order.id
          })
          |> Repo.insert!()

          {:ok, %{gift_card: updated_gc, deduction_cents: actual_deduction}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Restores amount_cents to a gift card's balance (called on refund).
  If gift_card.expires_at is in the past, extends expiry by 1 year from now.
  Uses bare Repo ops — participates in caller's transaction.
  Returns {:ok, gift_card} | {:error, reason}.
  """
  def restore_balance(%GiftCard{} = gc, amount_cents, _opts \\ [])
      when is_integer(amount_cents) and amount_cents > 0 do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {note, expires_at_update} =
      if gc.expires_at != nil and DateTime.compare(gc.expires_at, now) == :lt do
        new_expiry =
          now |> DateTime.add(365 * 24 * 3600, :second) |> DateTime.truncate(:second)

        {"Restaurado por reembolso (validade estendida)", new_expiry}
      else
        {"Restaurado por reembolso", gc.expires_at}
      end

    new_balance = gc.balance_cents + amount_cents

    changes =
      if expires_at_update != gc.expires_at do
        [balance_cents: new_balance, expires_at: expires_at_update]
      else
        [balance_cents: new_balance]
      end

    case gc |> Ecto.Changeset.change(changes) |> Repo.update() do
      {:ok, updated_gc} ->
        %GiftCardRedemption{}
        |> GiftCardRedemption.changeset(%{
          kind: "credit",
          amount_cents: amount_cents,
          note: note,
          gift_card_id: gc.id
        })
        |> Repo.insert!()

        {:ok, updated_gc}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the GiftCardRedemption with kind "debit" for the given order_id,
  preloaded with :gift_card, or nil if not found.
  """
  def get_debit_redemption_for_order(order_id) do
    GiftCardRedemption
    |> where([r], r.order_id == ^order_id and r.kind == "debit")
    |> preload(:gift_card)
    |> Repo.one()
  end

  @doc """
  Generates a candidate gift card code: "GC-XXXXXXXX" where X is uppercase alphanumeric (8 chars).
  Uniqueness is enforced by the DB unique constraint; this just generates a candidate.
  """
  def generate_code do
    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    suffix =
      1..8
      |> Enum.map(fn _ ->
        (:rand.uniform(String.length(chars)) - 1)
        |> then(&String.at(chars, &1))
      end)
      |> Enum.join()

    "GC-#{suffix}"
  end
end
