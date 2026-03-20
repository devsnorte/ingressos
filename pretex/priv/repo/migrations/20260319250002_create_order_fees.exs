defmodule Pretex.Repo.Migrations.CreateOrderFees do
  use Ecto.Migration

  def change do
    create table(:order_fees) do
      add(:name, :string, null: false)
      add(:fee_type, :string)
      add(:amount_cents, :integer, null: false, default: 0)
      add(:value_type, :string)
      add(:value, :integer, default: 0)
      add(:order_id, references(:orders, on_delete: :delete_all), null: false)
      add(:fee_rule_id, references(:fee_rules, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:order_fees, [:order_id]))
    create(index(:order_fees, [:fee_rule_id]))
  end
end
