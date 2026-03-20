defmodule Pretex.Orders do
  @moduledoc "Manages cart sessions and orders."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Orders.CartSession
  alias Pretex.Orders.CartItem
  alias Pretex.Orders.Order
  alias Pretex.Orders.OrderItem
  alias Pretex.Catalog.QuotaItem
  alias Pretex.Catalog.Quota
  alias Pretex.Events.Event

  # ---------------------------------------------------------------------------
  # Cart management
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new cart session for an event.
  Generates a random 32-byte hex session token and sets expiry to 15 minutes.
  """
  def create_cart(%Event{} = event) do
    token = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)

    expires_at =
      DateTime.utc_now() |> DateTime.add(15 * 60, :second) |> DateTime.truncate(:second)

    %CartSession{}
    |> CartSession.changeset(%{
      session_token: token,
      expires_at: expires_at,
      status: "active"
    })
    |> Ecto.Changeset.put_change(:event_id, event.id)
    |> Repo.insert()
  end

  @doc """
  Fetches a cart session by token, preloading cart_items with item and variation.
  Returns nil if not found.
  """
  def get_cart_by_token(token) when is_binary(token) do
    CartSession
    |> where([c], c.session_token == ^token)
    |> preload(cart_items: [:item, :item_variation])
    |> Repo.one()
  end

  def get_cart_by_token(_), do: nil

  @doc """
  Marks a cart as expired.
  """
  def expire_cart(%CartSession{} = cart) do
    cart
    |> Ecto.Changeset.change(status: "expired")
    |> Repo.update()
  end

  @doc """
  Adds an item to the cart or updates quantity if already present.
  Options: [quantity: 1, variation_id: nil]
  """
  def add_to_cart(%CartSession{} = cart, item, opts \\ []) do
    quantity = Keyword.get(opts, :quantity, 1)
    variation_id = Keyword.get(opts, :variation_id, nil)

    existing =
      CartItem
      |> where([ci], ci.cart_session_id == ^cart.id and ci.item_id == ^item.id)
      |> then(fn q ->
        if variation_id do
          where(q, [ci], ci.item_variation_id == ^variation_id)
        else
          where(q, [ci], is_nil(ci.item_variation_id))
        end
      end)
      |> Repo.one()

    case existing do
      nil ->
        %CartItem{}
        |> CartItem.changeset(%{
          quantity: quantity,
          item_id: item.id,
          item_variation_id: variation_id
        })
        |> Ecto.Changeset.put_change(:cart_session_id, cart.id)
        |> Repo.insert()

      cart_item ->
        new_quantity = cart_item.quantity + quantity

        cart_item
        |> CartItem.changeset(%{quantity: new_quantity})
        |> Repo.update()
    end
  end

  @doc """
  Removes a cart item by its id from the cart.
  """
  def remove_from_cart(%CartSession{} = cart, cart_item_id) do
    case Repo.get_by(CartItem, id: cart_item_id, cart_session_id: cart.id) do
      nil -> {:error, :not_found}
      cart_item -> Repo.delete(cart_item)
    end
  end

  @doc """
  Deletes all cart items for the given cart session.
  """
  def clear_cart(%CartSession{} = cart) do
    CartItem
    |> where([ci], ci.cart_session_id == ^cart.id)
    |> Repo.delete_all()

    {:ok, cart}
  end

  @doc """
  Computes the total price in cents for a cart.
  Uses variation price if present, otherwise item price.
  """
  def cart_total(%CartSession{cart_items: cart_items}) when is_list(cart_items) do
    Enum.reduce(cart_items, 0, fn cart_item, acc ->
      unit_price =
        if cart_item.item_variation && cart_item.item_variation.price_cents do
          cart_item.item_variation.price_cents
        else
          cart_item.item.price_cents
        end

      acc + cart_item.quantity * unit_price
    end)
  end

  def cart_total(_), do: 0

  # ---------------------------------------------------------------------------
  # Order management
  # ---------------------------------------------------------------------------

  @doc """
  Creates an order from the given cart and attrs.
  attrs: %{email:, name:, payment_method:, payment_provider_id: (optional)}

  - Validates cart is active and not expired
  - Creates Order with OrderItems
  - Generates ticket_code per order_item and confirmation_code for order
  - Sets expires_at based on payment_method
  - Marks cart as checked_out
  - Increments quota sold_count
  - All inside a Repo.transaction
  """
  def create_order_from_cart(%CartSession{} = cart, attrs) do
    cart = Repo.preload(cart, cart_items: [:item, :item_variation])

    with :ok <- validate_cart_active(cart),
         :ok <- validate_cart_not_expired(cart) do
      Repo.transaction(fn ->
        total_cents = cart_total(cart)
        payment_method = Map.get(attrs, :payment_method) || Map.get(attrs, "payment_method")

        provider_id =
          Map.get(attrs, :payment_provider_id) || Map.get(attrs, "payment_provider_id")

        expires_at = order_expires_at(payment_method)
        confirmation_code = generate_confirmation_code()

        order_changeset =
          %Order{}
          |> Order.changeset(attrs)
          |> Ecto.Changeset.put_change(:event_id, cart.event_id)
          |> Ecto.Changeset.put_change(:status, "pending")
          |> Ecto.Changeset.put_change(:total_cents, total_cents)
          |> Ecto.Changeset.put_change(:expires_at, expires_at)
          |> Ecto.Changeset.put_change(:confirmation_code, confirmation_code)
          |> then(fn cs ->
            if provider_id,
              do: Ecto.Changeset.put_change(cs, :payment_provider_id, provider_id),
              else: cs
          end)

        order =
          case Repo.insert(order_changeset) do
            {:ok, o} -> o
            {:error, cs} -> Repo.rollback(cs)
          end

        Enum.each(cart.cart_items, fn cart_item ->
          unit_price =
            if cart_item.item_variation && cart_item.item_variation.price_cents do
              cart_item.item_variation.price_cents
            else
              cart_item.item.price_cents
            end

          ticket_code = generate_ticket_code()

          item_changeset =
            %OrderItem{}
            |> OrderItem.changeset(%{
              quantity: cart_item.quantity,
              unit_price_cents: unit_price
            })
            |> Ecto.Changeset.put_change(:order_id, order.id)
            |> Ecto.Changeset.put_change(:item_id, cart_item.item_id)
            |> Ecto.Changeset.put_change(:item_variation_id, cart_item.item_variation_id)
            |> Ecto.Changeset.put_change(:ticket_code, ticket_code)

          case Repo.insert(item_changeset) do
            {:ok, _} -> :ok
            {:error, cs} -> Repo.rollback(cs)
          end

          increment_quota_sold_count(
            cart_item.item_id,
            cart_item.item_variation_id,
            cart_item.quantity
          )
        end)

        cart
        |> Ecto.Changeset.change(status: "checked_out")
        |> Repo.update!()

        # Preload order_items so discount evaluation can inspect them
        order_preloaded = Repo.preload(order, order_items: [:item, :item_variation])

        # Apply best automatic discount BEFORE fees (fees computed on discounted price)
        order =
          case Pretex.Discounts.apply_best_discount(order_preloaded, cart.event_id) do
            {:ok, updated} -> updated
            {:error, _} -> order_preloaded
          end

        order_with_fees =
          case Pretex.Fees.apply_automatic_fees(order, cart.event_id) do
            {:ok, updated_order} -> updated_order
            {:error, reason} -> Repo.rollback(reason)
          end

        # Apply voucher if provided
        voucher_code =
          Map.get(attrs, :voucher_code) || Map.get(attrs, "voucher_code")

        order_after_voucher =
          if voucher_code && String.trim(voucher_code) != "" do
            case Pretex.Vouchers.get_voucher_by_code(cart.event_id, voucher_code) do
              {:ok, voucher} ->
                case Pretex.Vouchers.redeem_voucher(
                       voucher,
                       order_with_fees,
                       order_with_fees.total_cents
                     ) do
                  {:ok, redemption} ->
                    new_total = max(0, order_with_fees.total_cents - redemption.discount_cents)

                    {:ok, updated} =
                      order_with_fees
                      |> Ecto.Changeset.change(total_cents: new_total)
                      |> Repo.update()

                    updated

                  {:error, _} ->
                    order_with_fees
                end

              {:error, _} ->
                order_with_fees
            end
          else
            order_with_fees
          end

        Repo.preload(order_after_voucher,
          order_items: [:item, :item_variation],
          fees: [],
          discounts: []
        )
      end)
    end
  end

  @doc """
  Lists all orders for an event, preloading order_items.
  """
  def list_orders_for_event(%Event{id: event_id}) do
    Order
    |> where([o], o.event_id == ^event_id)
    |> order_by([o], desc: o.inserted_at)
    |> preload(:order_items)
    |> Repo.all()
  end

  @doc """
  Searches and filters orders for an event.
  opts:
    - search: string — filters by name or email (case-insensitive)
    - status: string — filters by exact status
  Preloads order_items with item and item_variation.
  """
  def search_orders_for_event(%Event{id: event_id}, opts \\ []) do
    search = Keyword.get(opts, :search)
    status = Keyword.get(opts, :status)

    Order
    |> where([o], o.event_id == ^event_id)
    |> then(fn q ->
      if search && search != "" do
        term = "%#{search}%"
        where(q, [o], ilike(o.name, ^term) or ilike(o.email, ^term))
      else
        q
      end
    end)
    |> then(fn q ->
      if status && status != "" do
        where(q, [o], o.status == ^status)
      else
        q
      end
    end)
    |> order_by([o], desc: o.inserted_at)
    |> preload(order_items: [:item, :item_variation])
    |> Repo.all()
  end

  @doc """
  Gets an order by id with full details for the organizer view.
  Preloads: event, order_items (item, item_variation, answers).
  Raises if not found.
  """
  def get_order_with_details!(id) do
    Order
    |> preload([:event, order_items: [:item, :item_variation, :answers]])
    |> Repo.get!(id)
  end

  @doc """
  Locks an order for editing by setting locked_by_organizer: true.
  Returns {:ok, order} | {:error, changeset}.
  """
  def lock_order_for_editing(%Order{} = order) do
    order
    |> Ecto.Changeset.change(locked_by_organizer: true)
    |> Repo.update()
  end

  @doc """
  Unlocks an order by setting locked_by_organizer: false.
  Returns {:ok, order} | {:error, changeset}.
  """
  def unlock_order(%Order{} = order) do
    order
    |> Ecto.Changeset.change(locked_by_organizer: false)
    |> Repo.update()
  end

  @doc """
  Updates attendee info (name and/or email) on an order.
  Returns {:ok, order} | {:error, changeset}.
  """
  def update_order_attendee_info(%Order{} = order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Stub for resending ticket confirmation email.
  Returns {:ok, :sent} for confirmed orders.
  Returns {:error, :not_confirmed} if the order is not confirmed.
  Real email delivery will be implemented in Story 015.
  """
  def resend_ticket_email(%Order{status: "confirmed"}) do
    {:ok, :sent}
  end

  def resend_ticket_email(%Order{}) do
    {:error, :not_confirmed}
  end

  @doc """
  Creates a manual (admin/comp) order for an event without going through the cart.
  attrs:
    - name (required)
    - email (required)
    - status: "paid" | "comp" (defaults to "paid")
    - items: list of %{item_id:, quantity:, unit_price_cents:}

  - Generates ticket_code per order_item and confirmation_code for order
  - Does NOT decrement quota (manual/comp orders bypass quota)
  - Sets total_cents as sum of (quantity * unit_price_cents)
  - Returns {:ok, order} | {:error, reason}
  """
  def create_manual_order(%Event{} = event, attrs) do
    name = Map.get(attrs, :name) || Map.get(attrs, "name")
    email = Map.get(attrs, :email) || Map.get(attrs, "email")
    status = Map.get(attrs, :status) || Map.get(attrs, "status") || "paid"
    items = Map.get(attrs, :items) || Map.get(attrs, "items") || []

    items =
      Enum.map(items, fn item ->
        raw_item_id = Map.get(item, :item_id) || Map.get(item, "item_id")

        %{
          item_id: parse_integer(raw_item_id),
          quantity: parse_integer(Map.get(item, :quantity) || Map.get(item, "quantity")),
          unit_price_cents:
            parse_integer(Map.get(item, :unit_price_cents) || Map.get(item, "unit_price_cents"))
        }
      end)

    total_cents =
      Enum.reduce(items, 0, fn item, acc ->
        acc + item.quantity * item.unit_price_cents
      end)

    confirmation_code = generate_confirmation_code()

    Repo.transaction(fn ->
      order_changeset =
        %Order{}
        |> Order.changeset(%{name: name, email: email})
        |> Ecto.Changeset.put_change(:event_id, event.id)
        |> Ecto.Changeset.put_change(:status, status)
        |> Ecto.Changeset.put_change(:total_cents, total_cents)
        |> Ecto.Changeset.put_change(:confirmation_code, confirmation_code)
        |> Ecto.Changeset.put_change(
          :expires_at,
          DateTime.utc_now()
          |> DateTime.add(365 * 24 * 60 * 60, :second)
          |> DateTime.truncate(:second)
        )

      order =
        case Repo.insert(order_changeset) do
          {:ok, o} -> o
          {:error, cs} -> Repo.rollback(cs)
        end

      Enum.each(items, fn item ->
        ticket_code = generate_ticket_code()

        item_changeset =
          %OrderItem{}
          |> OrderItem.changeset(%{
            quantity: item.quantity,
            unit_price_cents: item.unit_price_cents
          })
          |> Ecto.Changeset.put_change(:order_id, order.id)
          |> Ecto.Changeset.put_change(:item_id, item.item_id)
          |> Ecto.Changeset.put_change(:ticket_code, ticket_code)

        case Repo.insert(item_changeset) do
          {:ok, _} -> :ok
          {:error, cs} -> Repo.rollback(cs)
        end
      end)

      order_with_fees =
        case Pretex.Fees.apply_automatic_fees(order, event.id) do
          {:ok, updated_order} -> updated_order
          {:error, reason} -> Repo.rollback(reason)
        end

      Repo.preload(order_with_fees, order_items: [:item, :item_variation], fees: [])
    end)
  end

  @doc """
  Lists all orders for a customer by customer_id.
  """
  def list_orders_for_customer(customer_id) do
    Order
    |> where([o], o.customer_id == ^customer_id)
    |> order_by([o], desc: o.inserted_at)
    |> preload([:event, order_items: [:item, :item_variation]])
    |> Repo.all()
  end

  @doc """
  Gets an order by id, preloading order_items with item, item_variation, and answers.
  Raises if not found.
  """
  def get_order!(id) do
    Order
    |> preload(order_items: [:item, :item_variation, :answers])
    |> Repo.get!(id)
  end

  @doc """
  Looks up an order by its confirmation code.
  Returns {:ok, order} or {:error, :not_found}.
  """
  def get_order_by_confirmation_code(code) when is_binary(code) do
    case Order
         |> where([o], o.confirmation_code == ^code)
         |> preload([:event, order_items: [:item, :item_variation]])
         |> Repo.one() do
      nil -> {:error, :not_found}
      order -> {:ok, order}
    end
  end

  def get_order_by_confirmation_code(_), do: {:error, :not_found}

  @doc """
  Confirms an order by setting its status to "confirmed".
  """
  def confirm_order(%Order{} = order) do
    order
    |> Ecto.Changeset.change(status: "confirmed")
    |> Repo.update()
  end

  @doc """
  Cancels an order and decrements the quota sold_count for each order item.
  """
  def cancel_order(%Order{} = order) do
    order = Repo.preload(order, :order_items)

    Repo.transaction(fn ->
      Enum.each(order.order_items, fn order_item ->
        decrement_quota_sold_count(
          order_item.item_id,
          order_item.item_variation_id,
          order_item.quantity
        )
      end)

      case order |> Ecto.Changeset.change(status: "cancelled") |> Repo.update() do
        {:ok, updated} -> updated
        {:error, cs} -> Repo.rollback(cs)
      end
    end)
  end

  @doc """
  Marks all stale pending orders (where expires_at < now) as expired.
  """
  def expire_stale_orders do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Order
    |> where([o], o.status == "pending" and o.expires_at < ^now)
    |> Repo.update_all(set: [status: "expired"])
  end

  @doc """
  Attempts to reactivate an expired order and confirm it, subject to quota
  availability. Called by `PollPayment` when an async payment arrives after
  the order has expired but quota may still be available.

  Returns:
    - `{:ok, order}` — order reactivated and confirmed
    - `{:error, :quota_exhausted}` — no quota available for one or more items
    - `{:error, reason}` — other failure
  """
  def reactivate_and_confirm_order(%Order{} = order) do
    order = Repo.preload(order, :order_items)

    Repo.transaction(fn ->
      # Check quota availability for each item under a row lock
      quota_check =
        Enum.reduce_while(order.order_items, :ok, fn order_item, :ok ->
          case check_and_reserve_quota(order_item) do
            :ok -> {:cont, :ok}
            {:error, :quota_exhausted} -> {:halt, {:error, :quota_exhausted}}
          end
        end)

      case quota_check do
        :ok ->
          case order |> Ecto.Changeset.change(status: "confirmed") |> Repo.update() do
            {:ok, confirmed} -> confirmed
            {:error, cs} -> Repo.rollback(cs)
          end

        {:error, :quota_exhausted} ->
          Repo.rollback(:quota_exhausted)
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp parse_integer(v) when is_integer(v), do: v
  defp parse_integer(v) when is_binary(v), do: String.to_integer(v)
  defp parse_integer(nil), do: 0

  defp validate_cart_active(%CartSession{status: "active"}), do: :ok
  defp validate_cart_active(_), do: {:error, :cart_not_active}

  defp validate_cart_not_expired(%CartSession{expires_at: expires_at}) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
      :ok
    else
      {:error, :cart_expired}
    end
  end

  defp order_expires_at("credit_card"), do: future_datetime(15 * 60)
  defp order_expires_at("debit_card"), do: future_datetime(15 * 60)
  defp order_expires_at("pix"), do: future_datetime(15 * 60)
  defp order_expires_at("boleto"), do: future_datetime(30 * 60)
  defp order_expires_at("bank_transfer"), do: future_datetime(3 * 24 * 60 * 60)
  defp order_expires_at(_), do: future_datetime(15 * 60)

  defp future_datetime(seconds) do
    DateTime.utc_now()
    |> DateTime.add(seconds, :second)
    |> DateTime.truncate(:second)
  end

  defp generate_ticket_code do
    :crypto.strong_rand_bytes(4) |> Base.encode16()
  end

  defp generate_confirmation_code do
    :crypto.strong_rand_bytes(3) |> Base.encode16()
  end

  defp increment_quota_sold_count(item_id, variation_id, quantity) do
    quota_ids = find_quota_ids(item_id, variation_id)

    if quota_ids != [] do
      from(q in Quota, where: q.id in ^quota_ids)
      |> Repo.update_all(inc: [sold_count: quantity])
    end
  end

  defp decrement_quota_sold_count(item_id, variation_id, quantity) do
    quota_ids = find_quota_ids(item_id, variation_id)

    if quota_ids != [] do
      from(q in Quota, where: q.id in ^quota_ids)
      |> Repo.update_all(inc: [sold_count: -quantity])
    end
  end

  # Atomically checks quota availability and increments sold_count for one
  # order item. Uses SELECT FOR UPDATE to prevent race conditions.
  defp check_and_reserve_quota(%OrderItem{
         item_id: item_id,
         item_variation_id: variation_id,
         quantity: quantity
       }) do
    quota_ids = find_quota_ids(item_id, variation_id)

    result =
      Enum.reduce_while(quota_ids, :ok, fn quota_id, :ok ->
        quota =
          from(q in Quota, where: q.id == ^quota_id, lock: "FOR UPDATE")
          |> Repo.one()

        available = quota.capacity - quota.sold_count

        if available >= quantity do
          from(q in Quota, where: q.id == ^quota_id)
          |> Repo.update_all(inc: [sold_count: quantity])

          {:cont, :ok}
        else
          {:halt, {:error, :quota_exhausted}}
        end
      end)

    result
  end

  defp find_quota_ids(item_id, nil) do
    QuotaItem
    |> where([qi], qi.item_id == ^item_id)
    |> select([qi], qi.quota_id)
    |> Repo.all()
  end

  defp find_quota_ids(_item_id, variation_id) do
    QuotaItem
    |> where([qi], qi.item_variation_id == ^variation_id)
    |> select([qi], qi.quota_id)
    |> Repo.all()
  end
end
