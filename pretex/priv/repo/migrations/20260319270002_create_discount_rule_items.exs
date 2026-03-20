defmodule Pretex.Repo.Migrations.CreateDiscountRuleItems do
  use Ecto.Migration

  def change do
    create table(:discount_rule_items) do
      add(:discount_rule_id, references(:discount_rules, on_delete: :delete_all), null: false)
      add(:item_id, references(:items, on_delete: :delete_all))
      add(:item_variation_id, references(:item_variations, on_delete: :delete_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:discount_rule_items, [:discount_rule_id]))
    create(index(:discount_rule_items, [:item_id]))
    create(index(:discount_rule_items, [:item_variation_id]))
  end
end
