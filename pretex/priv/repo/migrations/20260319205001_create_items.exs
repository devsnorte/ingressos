defmodule Pretex.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add(:event_id, references(:events, on_delete: :delete_all), null: false)
      add(:category_id, references(:item_categories, on_delete: :nilify_all))
      add(:name, :string, null: false)
      add(:description, :string)
      add(:price_cents, :integer, null: false, default: 0)
      add(:available_quantity, :integer)
      add(:item_type, :string, null: false, default: "ticket")
      add(:is_addon, :boolean, default: false, null: false)
      add(:require_voucher, :boolean, default: false, null: false)
      add(:min_per_order, :integer, default: 1)
      add(:max_per_order, :integer)
      add(:status, :string, default: "active", null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:items, [:event_id]))
    create(index(:items, [:category_id]))
  end
end
