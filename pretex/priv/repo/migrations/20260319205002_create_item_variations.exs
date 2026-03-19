defmodule Pretex.Repo.Migrations.CreateItemVariations do
  use Ecto.Migration

  def change do
    create table(:item_variations) do
      add(:item_id, references(:items, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:price_cents, :integer, null: false, default: 0)
      add(:stock, :integer)
      add(:status, :string, default: "active", null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:item_variations, [:item_id]))
  end
end
