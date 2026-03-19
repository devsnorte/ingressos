defmodule Pretex.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add(:event_id, references(:events, on_delete: :restrict), null: false)
      add(:customer_id, references(:customers, on_delete: :nilify_all))
      add(:status, :string, default: "pending", null: false)
      add(:total_cents, :integer, default: 0, null: false)
      add(:email, :string, null: false)
      add(:name, :string, null: false)
      add(:expires_at, :utc_datetime)
      add(:payment_method, :string)
      add(:confirmation_code, :string)
      timestamps(type: :utc_datetime)
    end

    create(index(:orders, [:event_id]))
    create(index(:orders, [:customer_id]))
    create(index(:orders, [:status]))
    create(unique_index(:orders, [:confirmation_code]))
  end
end
