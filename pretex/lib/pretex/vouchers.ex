defmodule Pretex.Vouchers do
  @moduledoc "Manages voucher codes for events."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Vouchers.Voucher
  alias Pretex.Vouchers.VoucherRedemption

  require Logger

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc """
  List all vouchers for an event, ordered by code asc.
  Accepts opts: [tag: string] to filter by tag.
  """
  def list_vouchers(%{id: event_id}, opts \\ []) do
    tag = Keyword.get(opts, :tag)

    Voucher
    |> where([v], v.event_id == ^event_id)
    |> then(fn q ->
      if tag do
        where(q, [v], v.tag == ^tag)
      else
        q
      end
    end)
    |> order_by([v], asc: v.code)
    |> preload(:scoped_items)
    |> Repo.all()
  end

  @doc "Get a voucher by id, raises if not found. Preloads scoped_items and redemptions."
  def get_voucher!(id) do
    Voucher
    |> preload([:scoped_items, :redemptions])
    |> Repo.get!(id)
  end

  @doc """
  Look up a voucher by code (case-insensitive) and event_id.
  Returns {:ok, voucher} | {:error, :not_found}.
  """
  def get_voucher_by_code(event_id, code) when is_binary(code) do
    normalized = String.upcase(String.trim(code))

    case Repo.one(
           from(v in Voucher,
             where: v.event_id == ^event_id and v.code == ^normalized
           )
         ) do
      nil -> {:error, :not_found}
      voucher -> {:ok, voucher}
    end
  end

  def get_voucher_by_code(_event_id, _code), do: {:error, :not_found}

  @doc "Create a voucher for an event."
  def create_voucher(%{id: event_id}, attrs) do
    %Voucher{}
    |> Voucher.changeset(attrs)
    |> Ecto.Changeset.put_change(:event_id, event_id)
    |> Repo.insert()
  end

  @doc "Update a voucher."
  def update_voucher(%Voucher{} = voucher, attrs) do
    voucher
    |> Voucher.changeset(attrs)
    |> Repo.update()
  end

  @doc "Delete a voucher."
  def delete_voucher(%Voucher{} = voucher) do
    Repo.delete(voucher)
  end

  @doc "Return a changeset for a voucher (used by forms)."
  def change_voucher(%Voucher{} = voucher, attrs \\ %{}) do
    Voucher.changeset(voucher, attrs)
  end

  @doc "Returns a list of distinct non-nil tags for the event's vouchers."
  def list_tags(%{id: event_id}) do
    Voucher
    |> where([v], v.event_id == ^event_id and not is_nil(v.tag))
    |> select([v], v.tag)
    |> distinct(true)
    |> order_by([v], asc: v.tag)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Bulk generation
  # ---------------------------------------------------------------------------

  @doc """
  Bulk-generate vouchers for an event.

  opts: %{prefix: string, quantity: integer, effect: string, value: integer,
           max_uses: integer | nil, valid_until: datetime | nil, tag: string | nil}

  Returns {:ok, count} | {:error, reason}.
  """
  def bulk_generate(%{id: event_id} = _event, opts) do
    prefix = Map.get(opts, :prefix) || Map.get(opts, "prefix") || ""
    quantity = Map.get(opts, :quantity) || Map.get(opts, "quantity") || 0
    effect = Map.get(opts, :effect) || Map.get(opts, "effect") || "fixed_discount"
    value = Map.get(opts, :value) || Map.get(opts, "value") || 0
    max_uses = Map.get(opts, :max_uses) || Map.get(opts, "max_uses")
    valid_until = Map.get(opts, :valid_until) || Map.get(opts, "valid_until")
    tag = Map.get(opts, :tag) || Map.get(opts, "tag")

    quantity = if is_binary(quantity), do: String.to_integer(quantity), else: quantity
    value = if is_binary(value), do: String.to_integer(value), else: value

    max_uses =
      cond do
        is_binary(max_uses) and max_uses != "" -> String.to_integer(max_uses)
        max_uses == "" -> nil
        true -> max_uses
      end

    count =
      Enum.reduce(1..quantity, 0, fn _i, acc ->
        case attempt_insert_with_retry(
               event_id,
               prefix,
               effect,
               value,
               max_uses,
               valid_until,
               tag,
               3
             ) do
          :ok -> acc + 1
          :skip -> acc
        end
      end)

    {:ok, count}
  rescue
    e ->
      Logger.error("bulk_generate failed: #{inspect(e)}")
      {:error, :generation_failed}
  end

  defp attempt_insert_with_retry(
         _event_id,
         _prefix,
         _effect,
         _value,
         _max_uses,
         _valid_until,
         _tag,
         0
       ) do
    Logger.warning("bulk_generate: giving up after max retries for a code")
    :skip
  end

  defp attempt_insert_with_retry(
         event_id,
         prefix,
         effect,
         value,
         max_uses,
         valid_until,
         tag,
         retries_left
       ) do
    suffix = generate_random_suffix()
    code = String.upcase("#{prefix}#{suffix}")

    attrs =
      %{
        code: code,
        effect: effect,
        value: value,
        max_uses: max_uses,
        valid_until: valid_until,
        tag: tag,
        active: true,
        event_id: event_id
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    changeset =
      %Voucher{}
      |> Voucher.changeset(attrs)
      |> Ecto.Changeset.put_change(:event_id, event_id)

    case Repo.insert(changeset) do
      {:ok, _} ->
        :ok

      {:error, %Ecto.Changeset{errors: errors}} ->
        if Keyword.has_key?(errors, :code) do
          attempt_insert_with_retry(
            event_id,
            prefix,
            effect,
            value,
            max_uses,
            valid_until,
            tag,
            retries_left - 1
          )
        else
          :skip
        end
    end
  rescue
    Ecto.ConstraintError ->
      attempt_insert_with_retry(
        event_id,
        prefix,
        effect,
        value,
        max_uses,
        valid_until,
        tag,
        retries_left - 1
      )
  end

  defp generate_random_suffix do
    chars = ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    for _ <- 1..6, into: "", do: <<Enum.random(chars)>>
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  @doc """
  Validate a voucher code for use in a cart.

  Returns {:ok, voucher} if valid, {:error, reason} otherwise.
  reason: :not_found | :expired | :exhausted | :already_applied
  """
  def validate_voucher_for_cart(event_id, code, order_id \\ nil) do
    case get_voucher_by_code(event_id, code) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, voucher} ->
        now = DateTime.utc_now()

        cond do
          !voucher.active ->
            {:error, :not_found}

          voucher.valid_until && DateTime.compare(voucher.valid_until, now) == :lt ->
            {:error, :expired}

          voucher.max_uses && voucher.used_count >= voucher.max_uses ->
            {:error, :exhausted}

          order_id && already_redeemed?(voucher.id, order_id) ->
            {:error, :already_applied}

          true ->
            {:ok, voucher}
        end
    end
  end

  defp already_redeemed?(voucher_id, order_id) do
    Repo.exists?(
      from(r in VoucherRedemption,
        where: r.voucher_id == ^voucher_id and r.order_id == ^order_id
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Redemption
  # ---------------------------------------------------------------------------

  @doc """
  Redeem a voucher for an order.

  Computes discount_cents, inserts VoucherRedemption, increments used_count.
  Returns {:ok, redemption} | {:error, reason}.
  Note: does NOT update order total — caller handles that.
  """
  def redeem_voucher(%Voucher{} = voucher, order, subtotal_cents) do
    discount_cents = compute_discount(voucher, subtotal_cents)

    Repo.transaction(fn ->
      redemption_changeset =
        %VoucherRedemption{}
        |> VoucherRedemption.changeset(%{
          discount_cents: discount_cents,
          voucher_id: voucher.id,
          order_id: order.id
        })

      redemption =
        case Repo.insert(redemption_changeset) do
          {:ok, r} -> r
          {:error, cs} -> Repo.rollback(cs)
        end

      voucher
      |> Ecto.Changeset.change(used_count: voucher.used_count + 1)
      |> Repo.update!()

      redemption
    end)
  end

  defp compute_discount(%Voucher{effect: "fixed_discount", value: value}, subtotal_cents) do
    min(value, subtotal_cents)
  end

  defp compute_discount(%Voucher{effect: "percentage_discount", value: value}, subtotal_cents) do
    round(subtotal_cents * value / 10_000)
  end

  defp compute_discount(%Voucher{effect: effect}, _subtotal_cents)
       when effect in ~w(custom_price reveal grant_access) do
    0
  end

  @doc """
  Compute a discount preview (same logic as redeem_voucher but no DB write).
  """
  def preview_discount(%Voucher{} = voucher, subtotal_cents) do
    compute_discount(voucher, subtotal_cents)
  end

  @doc """
  Returns the VoucherRedemption for an order (preloaded with voucher), or nil.
  """
  def get_redemption_for_order(order_id) do
    VoucherRedemption
    |> where([r], r.order_id == ^order_id)
    |> preload(:voucher)
    |> Repo.one()
  end
end
