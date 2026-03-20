defmodule Pretex.Repo.Migrations.CreateDiscountRules do
  use Ecto.Migration

  def change do
    create table(:discount_rules) do
      add(:name, :string, null: false)
      add(:condition_type, :string, null: false, default: "min_quantity")
      add(:min_quantity, :integer, null: false, default: 1)
      add(:value_type, :string, null: false, default: "percentage")
      add(:value, :integer, null: false, default: 0)
      add(:active, :boolean, null: false, default: true)
      add(:description, :string)

      add(:event_id, references(:events, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:discount_rules, [:event_id]))
    create(index(:discount_rules, [:event_id, :active]))
  end
end
