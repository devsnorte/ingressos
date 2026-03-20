defmodule Pretex.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments) do
      add(:order_id, references(:orders, on_delete: :restrict), null: false)
      add(:payment_provider_id, references(:payment_providers, on_delete: :restrict), null: false)
      # "pending", "confirmed", "failed", "refunded", "cancelled"
      add(:status, :string, default: "pending", null: false)
      # "credit_card", "pix", "boleto", "bank_transfer", etc.
      add(:payment_method, :string, null: false)
      # "inline", "redirect", "async"
      add(:flow, :string, null: false)
      # External reference from the gateway (payment intent id, charge id, etc.)
      add(:external_ref, :string)
      # Amount in cents
      add(:amount_cents, :integer, null: false)
      add(:currency, :string, default: "BRL", null: false)
      # For redirect-based flows (PayPal, Mercado Pago)
      add(:redirect_url, :text)
      # For Pix QR code flows
      add(:qr_code_text, :text)
      add(:qr_code_image_base64, :text)
      # When this payment intent expires (e.g. Pix 15 min window)
      add(:expires_at, :utc_datetime)
      # When the payment was confirmed or failed
      add(:settled_at, :utc_datetime)
      # Human-readable failure reason
      add(:failure_reason, :string)

      timestamps(type: :utc_datetime)
    end

    create(index(:payments, [:order_id]))
    create(index(:payments, [:payment_provider_id]))
    create(index(:payments, [:status]))

    create(
      unique_index(:payments, [:external_ref, :payment_provider_id],
        name: :payments_external_ref_provider_unique,
        where: "external_ref IS NOT NULL"
      )
    )
  end
end
