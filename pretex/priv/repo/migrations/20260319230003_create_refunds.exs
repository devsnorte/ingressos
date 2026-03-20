defmodule Pretex.Repo.Migrations.CreateRefunds do
  use Ecto.Migration

  def change do
    create table(:refunds) do
      add(:payment_id, references(:payments, on_delete: :restrict), null: false)
      add(:order_id, references(:orders, on_delete: :restrict), null: false)
      # Amount refunded in cents
      add(:amount_cents, :integer, null: false)
      # "pending", "processing", "completed", "failed"
      add(:status, :string, default: "pending", null: false)
      # Reference from the payment provider
      add(:provider_ref, :string)
      # Human-readable reason (e.g. "late payment – sold out", "attendee request")
      add(:reason, :string)
      add(:initiated_at, :utc_datetime)
      add(:completed_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(index(:refunds, [:payment_id]))
    create(index(:refunds, [:order_id]))
    create(index(:refunds, [:status]))
  end
end
