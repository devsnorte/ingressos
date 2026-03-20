defmodule Pretex.Repo.Migrations.CreateOrderDiscounts do
  use Ecto.Migration

  def change do
    create table(:order_discounts) do
      add(:name, :string, null: false)
      add(:discount_cents, :integer, null: false, default: 0)
      add(:value_type, :string)
      add(:value, :integer, default: 0)

      add(:order_id, references(:orders, on_delete: :delete_all), null: false)
      add(:discount_rule_id, references(:discount_rules, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:order_discounts, [:order_id]))
    create(index(:order_discounts, [:discount_rule_id]))
  end
end
