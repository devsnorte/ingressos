defmodule Pretex.Payments do
  @moduledoc """
  The Payments context manages BYOG payment provider configuration and runtime
  payment processing.

  Responsibilities:
  - Provider CRUD and credential management (story-011)
  - Payment creation, confirmation, and failure tracking (story-012)
  - Webhook ingestion and routing (story-012)
  - Refund initiation for late/failed payments (story-012)
  """

  import Ecto.Query
  alias Pretex.Repo
  alias Pretex.Payments.{PaymentProvider, Payment, Refund}
  alias Pretex.Orders.Order

  @adapters %{
    "manual" => Pretex.Payments.Adapters.Manual,
    "woovi" => Pretex.Payments.Adapters.Woovi,
    "stripe" => Pretex.Payments.Adapters.Stripe,
    "abacatepay" => Pretex.Payments.Adapters.AbacatePay,
    "asaas" => Pretex.Payments.Adapters.Asaas
  }

  # ---------------------------------------------------------------------------
  # Provider types
  # ---------------------------------------------------------------------------

  def available_providers do
    Enum.map(@adapters, fn {type, mod} ->
      %{
        type: type,
        display_name: mod.display_name(),
        description: mod.description(),
        required_fields: mod.required_fields(),
        payment_methods: mod.payment_methods()
      }
    end)
    |> Enum.sort_by(& &1.display_name)
  end

  def adapter_for(type), do: Map.get(@adapters, type)

  def adapter_module!(%PaymentProvider{type: type}), do: Map.fetch!(@adapters, type)

  # ---------------------------------------------------------------------------
  # Provider CRUD
  # ---------------------------------------------------------------------------

  def list_providers(organization_id) do
    PaymentProvider
    |> where([p], p.organization_id == ^organization_id)
    |> order_by([p], asc: :name)
    |> Repo.all()
  end

  def get_provider!(id), do: Repo.get!(PaymentProvider, id)

  def get_provider(id), do: Repo.get(PaymentProvider, id)

  def get_provider_by_webhook_token(token) when is_binary(token) do
    Repo.get_by(PaymentProvider, webhook_token: token)
  end

  def get_provider_by_webhook_token(_), do: nil

  def get_default_provider(organization_id) do
    PaymentProvider
    |> where(
      [p],
      p.organization_id == ^organization_id and p.is_default == true and p.is_active == true
    )
    |> Repo.one()
  end

  def create_provider(attrs) do
    %PaymentProvider{}
    |> PaymentProvider.creation_changeset(attrs)
    |> Repo.insert()
  end

  def update_provider(%PaymentProvider{} = provider, attrs) do
    provider
    |> PaymentProvider.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_provider(%PaymentProvider{} = provider) do
    Repo.delete(provider)
  end

  def change_provider(%PaymentProvider{} = provider, attrs \\ %{}) do
    PaymentProvider.creation_changeset(provider, attrs)
  end

  def count_active_providers(organization_id) do
    PaymentProvider
    |> where([p], p.organization_id == ^organization_id and p.is_active == true)
    |> Repo.aggregate(:count)
  end

  # ---------------------------------------------------------------------------
  # Provider validation
  # ---------------------------------------------------------------------------

  def validate_provider(%PaymentProvider{} = provider) do
    adapter = adapter_module!(provider)

    case adapter.validate_credentials(provider.credentials) do
      {:ok, :valid} ->
        provider
        |> PaymentProvider.validation_changeset(%{
          validation_status: "valid",
          last_validated_at: DateTime.utc_now() |> DateTime.truncate(:second),
          is_active: true
        })
        |> Repo.update()

      {:error, reason} ->
        provider
        |> PaymentProvider.validation_changeset(%{
          validation_status: "invalid",
          last_validated_at: DateTime.utc_now() |> DateTime.truncate(:second),
          is_active: false
        })
        |> Repo.update()

        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Credential masking
  # ---------------------------------------------------------------------------

  def mask_credentials(%PaymentProvider{credentials: creds}) when is_map(creds) do
    Map.new(creds, fn {key, value} ->
      masked =
        if is_binary(value) and byte_size(value) > 4 do
          "••••" <> String.slice(value, -4, 4)
        else
          "••••"
        end

      {key, masked}
    end)
  end

  def mask_credentials(_), do: %{}

  # ---------------------------------------------------------------------------
  # Default provider management
  # ---------------------------------------------------------------------------

  def set_default_provider(%PaymentProvider{} = provider) do
    Repo.transaction(fn ->
      from(p in PaymentProvider,
        where: p.organization_id == ^provider.organization_id and p.is_default == true
      )
      |> Repo.update_all(set: [is_default: false])

      provider
      |> PaymentProvider.update_changeset(%{is_default: true})
      |> Repo.update!()
    end)
  end

  # ---------------------------------------------------------------------------
  # Payment methods for an event
  # Returns a deduplicated list of method atoms available from all active
  # providers configured for the event's organization.
  # ---------------------------------------------------------------------------

  @doc """
  Returns available payment methods for an event based on the organization's
  active configured providers. Each entry is a map with :method, :provider_id,
  and :flow.
  """
  def list_payment_options_for_organization(organization_id) do
    providers = list_providers(organization_id)

    providers
    |> Enum.filter(& &1.is_active)
    |> Enum.flat_map(fn provider ->
      adapter = adapter_module!(provider)

      adapter.payment_methods()
      |> Enum.map(fn method ->
        %{
          method: method,
          provider_id: provider.id,
          provider_type: provider.type,
          flow: payment_flow(provider.type, method)
        }
      end)
    end)
    |> Enum.uniq_by(& &1.method)
  end

  # ---------------------------------------------------------------------------
  # Payment CRUD
  # ---------------------------------------------------------------------------

  def get_payment!(id) do
    Payment
    |> preload(:refunds)
    |> Repo.get!(id)
  end

  def get_payment(id) do
    Payment
    |> preload(:refunds)
    |> Repo.get(id)
  end

  def get_payment_for_order(%Order{id: order_id}) do
    Payment
    |> where([p], p.order_id == ^order_id)
    |> order_by([p], desc: p.inserted_at)
    |> limit(1)
    |> preload(:refunds)
    |> Repo.one()
  end

  def get_payment_for_order(order_id) when is_integer(order_id) do
    Payment
    |> where([p], p.order_id == ^order_id)
    |> order_by([p], desc: p.inserted_at)
    |> limit(1)
    |> preload(:refunds)
    |> Repo.one()
  end

  def list_pending_async_payments do
    Payment
    |> where([p], p.status == "pending" and p.flow == "async")
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Payment creation — called right after an order is placed
  # ---------------------------------------------------------------------------

  @doc """
  Creates a payment record and calls the gateway adapter to initiate the charge.

  Returns:
    - `{:ok, payment}` for inline/manual payments
    - `{:ok, payment}` for async payments (pix QR code, boleto, bank transfer)
    - `{:ok, payment}` for redirect-based flows (redirect_url populated)
    - `{:error, reason}` on adapter or DB failure
  """
  def create_payment(%Order{} = order, %PaymentProvider{} = provider, payment_method) do
    adapter = adapter_module!(provider)
    flow = payment_flow(provider.type, payment_method)

    metadata = %{
      "order_id" => order.id,
      "confirmation_code" => order.confirmation_code,
      "email" => order.email,
      "name" => order.name,
      "payment_method" => payment_method
    }

    # Insert the payment record first (pending state)
    attrs = %{
      order_id: order.id,
      payment_provider_id: provider.id,
      payment_method: payment_method,
      flow: flow,
      amount_cents: order.total_cents,
      currency: "BRL"
    }

    with {:ok, payment} <- insert_payment(attrs),
         {:ok, payment} <- call_adapter(adapter, provider, payment, metadata) do
      # For async methods, broadcast so LiveViews can subscribe
      broadcast_payment_update(payment)
      {:ok, payment}
    end
  end

  defp insert_payment(attrs) do
    %Payment{}
    |> Payment.creation_changeset(attrs)
    |> Repo.insert()
  end

  defp call_adapter(adapter, provider, payment, metadata) do
    currency = payment.currency || "BRL"

    case adapter.create_payment(provider.credentials, payment.amount_cents, currency, metadata) do
      {:ok, ref} ->
        payment
        |> Payment.gateway_changeset(%{external_ref: ref})
        |> Repo.update()

      {:redirect, url} ->
        payment
        |> Payment.gateway_changeset(%{redirect_url: url})
        |> Repo.update()

      {:pix, %{qr_code_text: text, qr_code_image: image, external_ref: ref}} ->
        expires_at =
          DateTime.utc_now() |> DateTime.add(15 * 60, :second) |> DateTime.truncate(:second)

        payment
        |> Payment.gateway_changeset(%{
          external_ref: ref,
          qr_code_text: text,
          qr_code_image_base64: image,
          expires_at: expires_at
        })
        |> Repo.update()

      {:error, reason} ->
        payment
        |> Payment.fail_changeset(reason)
        |> Repo.update()

        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Payment confirmation
  # ---------------------------------------------------------------------------

  @doc """
  Confirms a payment. Also confirms the associated order and broadcasts
  the status change via PubSub so LiveViews update in real time.
  """
  def confirm_payment(payment, attrs \\ %{})

  def confirm_payment(%Payment{status: status} = payment, attrs)
      when status in ~w(pending) do
    Repo.transaction(fn ->
      {:ok, confirmed_payment} =
        payment
        |> Payment.confirm_changeset(attrs)
        |> Repo.update()

      order = Repo.get!(Order, payment.order_id)
      {:ok, _order} = Pretex.Orders.confirm_order(order)

      broadcast_payment_update(confirmed_payment)
      confirmed_payment
    end)
  end

  def confirm_payment(%Payment{} = payment, attrs) when is_map(attrs), do: {:ok, payment}

  @doc """
  Marks a payment as failed and broadcasts the status change.
  """
  def fail_payment(%Payment{} = payment, reason) do
    payment
    |> Payment.fail_changeset(reason)
    |> Repo.update()
    |> tap_ok(&broadcast_payment_update/1)
  end

  # ---------------------------------------------------------------------------
  # Webhook handling
  # ---------------------------------------------------------------------------

  @doc """
  Handles an incoming webhook for a provider identified by `webhook_token`.

  The raw body and headers are passed directly to the adapter for signature
  verification. On success, the parsed event is dispatched to update payment
  and order state.

  Returns `{:ok, :processed}`, `{:error, :invalid_signature}`, or
  `{:error, :unknown_token}`.
  """
  def handle_webhook(webhook_token, raw_body, headers) do
    case get_provider_by_webhook_token(webhook_token) do
      nil ->
        {:error, :unknown_token}

      provider ->
        adapter = adapter_module!(provider)

        case adapter.parse_webhook(provider.credentials, raw_body, headers) do
          {:ok, event} ->
            dispatch_webhook_event(provider, event)

          {:error, :invalid_signature} ->
            {:error, :invalid_signature}
        end
    end
  end

  defp dispatch_webhook_event(_provider, %{type: type} = event)
       when type in ~w(payment_intent.succeeded charge.completed PAYMENT_CONFIRMED payment.confirmed) do
    ref = Map.get(event, :external_ref) || Map.get(event, "external_ref")

    case find_payment_by_ref(ref) do
      nil ->
        # Unknown ref — silently ignore (may be a test event or other product)
        {:ok, :processed}

      payment ->
        case confirm_payment(payment) do
          {:ok, _} -> {:ok, :processed}
          {:error, _} = err -> err
        end
    end
  end

  defp dispatch_webhook_event(_provider, %{type: type} = event)
       when type in ~w(payment_intent.payment_failed charge.failed PAYMENT_OVERDUE payment.failed) do
    ref = Map.get(event, :external_ref) || Map.get(event, "external_ref")

    case find_payment_by_ref(ref) do
      nil ->
        {:ok, :processed}

      payment ->
        case fail_payment(payment, "Gateway reported failure: #{type}") do
          {:ok, _} -> {:ok, :processed}
          {:error, _} = err -> err
        end
    end
  end

  defp dispatch_webhook_event(_provider, _event), do: {:ok, :processed}

  defp find_payment_by_ref(nil), do: nil

  defp find_payment_by_ref(ref) do
    Payment
    |> where([p], p.external_ref == ^ref)
    |> Repo.one()
  end

  # ---------------------------------------------------------------------------
  # Refunds
  # ---------------------------------------------------------------------------

  @doc """
  Initiates a refund for a payment.

  Handles two scenarios:
  1. Normal refund request: calls adapter and records the refund.
  2. Late payment for sold-out/expired order: called after confirming a payment
     that should not have been collected (quota exhausted).

  Broadcasts a PubSub message so the attendee's LiveView (if open) updates.
  """
  def initiate_refund(%Payment{} = payment, reason \\ "attendee request") do
    provider = Repo.get!(PaymentProvider, payment.payment_provider_id)
    adapter = adapter_module!(provider)

    Repo.transaction(fn ->
      refund_attrs = %{
        payment_id: payment.id,
        order_id: payment.order_id,
        amount_cents: payment.amount_cents,
        reason: reason
      }

      refund =
        case Repo.insert(Refund.creation_changeset(%Refund{}, refund_attrs)) do
          {:ok, r} -> r
          {:error, cs} -> Repo.rollback(cs)
        end

      case adapter.refund(provider.credentials, payment.external_ref, payment.amount_cents) do
        {:ok, provider_ref} ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          {:ok, completed_refund} =
            refund
            |> Refund.status_changeset(%{
              status: "completed",
              provider_ref: provider_ref,
              completed_at: now
            })
            |> Repo.update()

          # Mark payment as refunded
          payment
          |> Payment.refund_changeset()
          |> Repo.update!()

          broadcast_refund(payment.order_id, completed_refund)
          completed_refund

        {:error, reason} ->
          refund
          |> Refund.status_changeset(%{status: "failed"})
          |> Repo.update!()

          Repo.rollback({:refund_failed, reason})
      end
    end)
  end

  @doc """
  Handles a late async payment that arrived after the order expired and the
  quota is now exhausted. Confirms the payment to collect the funds then
  immediately initiates a full refund.

  This function is called by the async payment worker when it detects the
  order can no longer be fulfilled.
  """
  def handle_late_payment(%Payment{} = payment) do
    Repo.transaction(fn ->
      # Confirm the payment so we have a record of receipt
      {:ok, confirmed} =
        payment
        |> Payment.confirm_changeset()
        |> Repo.update()

      broadcast_payment_update(confirmed)

      # Immediately refund — order is NOT confirmed
      case initiate_refund(confirmed, "late payment – quota exhausted") do
        {:ok, refund} ->
          broadcast_late_payment_refund(payment.order_id)
          refund

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Async payment status check — called by PollPayment Oban worker
  # ---------------------------------------------------------------------------

  @doc """
  Checks the current status of a pending async payment with the gateway.

  Returns:
    - `:confirmed` — payment confirmed; caller should call `confirm_payment/1`
    - `:failed`    — payment definitively failed
    - `:pending`   — still waiting; caller should snooze and retry
  """
  def check_async_status(%Payment{} = payment) do
    provider = Repo.get!(PaymentProvider, payment.payment_provider_id)
    adapter = adapter_module!(provider)

    # Adapters expose an optional check_status/2. If not implemented we fall
    # back to :pending so the poller keeps retrying until the webhook arrives.
    if function_exported?(adapter, :check_status, 2) do
      adapter.check_status(provider.credentials, payment.external_ref)
    else
      :pending
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub helpers
  # ---------------------------------------------------------------------------

  @doc "Topic for a specific order's payment status updates."
  def payment_topic(order_id), do: "payments:order:#{order_id}"

  defp broadcast_payment_update(%Payment{order_id: order_id} = payment) do
    Phoenix.PubSub.broadcast(
      Pretex.PubSub,
      payment_topic(order_id),
      {:payment_updated, payment}
    )
  end

  defp broadcast_refund(order_id, refund) do
    Phoenix.PubSub.broadcast(
      Pretex.PubSub,
      payment_topic(order_id),
      {:refund_initiated, refund}
    )
  end

  defp broadcast_late_payment_refund(order_id) do
    Phoenix.PubSub.broadcast(
      Pretex.PubSub,
      payment_topic(order_id),
      :late_payment_refunded
    )
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Determines the UX flow for a given provider type + payment method.
  # inline  — payment form stays within the platform (credit card, Pix QR code)
  # redirect — attendee is sent to the provider's hosted page
  # async   — payment is initiated but confirmation arrives later (Pix, boleto)
  defp payment_flow("stripe", "credit_card"), do: "inline"
  defp payment_flow("stripe", "debit_card"), do: "inline"
  defp payment_flow("stripe", "pix"), do: "async"
  defp payment_flow("woovi", _), do: "async"
  defp payment_flow("abacatepay", "pix"), do: "async"
  defp payment_flow("abacatepay", "boleto"), do: "async"
  defp payment_flow("asaas", "pix"), do: "async"
  defp payment_flow("asaas", "boleto"), do: "async"
  defp payment_flow("asaas", "credit_card"), do: "inline"
  defp payment_flow("manual", _), do: "async"
  defp payment_flow(_, _), do: "async"

  defp tap_ok({:ok, value}, fun) do
    fun.(value)
    {:ok, value}
  end

  defp tap_ok(other, _fun), do: other
end
