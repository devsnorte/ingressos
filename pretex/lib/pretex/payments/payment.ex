defmodule Pretex.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending confirmed failed refunded cancelled)
  @payment_flows ~w(inline redirect async)

  schema "payments" do
    field(:order_id, :integer)
    field(:payment_provider_id, :integer)
    field(:status, :string, default: "pending")
    # e.g. "credit_card", "pix", "boleto", "bank_transfer"
    field(:payment_method, :string)
    # inline | redirect | async
    field(:flow, :string)
    # External reference from the gateway
    field(:external_ref, :string)
    # Amount in cents
    field(:amount_cents, :integer)
    field(:currency, :string, default: "BRL")
    # For redirect-based flows
    field(:redirect_url, :string)
    # For Pix QR code flows
    field(:qr_code_text, :string)
    field(:qr_code_image_base64, :string)
    # ISO8601 expiry of the payment (e.g. Pix expires in 15 min)
    field(:expires_at, :utc_datetime)
    # When the payment was confirmed/failed
    field(:settled_at, :utc_datetime)
    # Human-readable failure reason, if any
    field(:failure_reason, :string)
    # Customer-submitted proof/note for manual bank transfer payments
    field(:transfer_note, :string)

    has_many(:refunds, Pretex.Payments.Refund)

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def payment_flows, do: @payment_flows

  def creation_changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :order_id,
      :payment_provider_id,
      :payment_method,
      :flow,
      :amount_cents,
      :currency,
      :expires_at
    ])
    |> validate_required([:order_id, :payment_provider_id, :payment_method, :flow, :amount_cents])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:flow, @payment_flows)
    |> validate_number(:amount_cents, greater_than_or_equal_to: 0)
    |> put_change(:status, "pending")
  end

  def gateway_changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :external_ref,
      :redirect_url,
      :qr_code_text,
      :qr_code_image_base64,
      :expires_at
    ])
  end

  def note_changeset(payment, attrs) do
    payment
    |> cast(attrs, [:transfer_note])
    |> validate_length(:transfer_note, max: 1000)
  end

  def confirm_changeset(payment, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    payment
    |> cast(attrs, [:external_ref])
    |> put_change(:status, "confirmed")
    |> put_change(:settled_at, now)
  end

  def fail_changeset(payment, reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    payment
    |> change()
    |> put_change(:status, "failed")
    |> put_change(:failure_reason, reason)
    |> put_change(:settled_at, now)
  end

  def refund_changeset(payment) do
    payment
    |> change()
    |> put_change(:status, "refunded")
  end

  def cancel_changeset(payment) do
    payment
    |> change()
    |> put_change(:status, "cancelled")
  end
end
