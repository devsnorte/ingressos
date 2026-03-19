defmodule Pretex.Repo.Migrations.CreateBundles do
  use Ecto.Migration

  def change do
    create table(:bundles) do
      add(:event_id, references(:events, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:description, :string)
      add(:price_cents, :integer, null: false, default: 0)
      add(:status, :string, default: "active", null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:bundles, [:event_id]))

    create table(:bundle_items) do
      add(:bundle_id, references(:bundles, on_delete: :delete_all), null: false)
      add(:item_id, references(:items, on_delete: :restrict), null: false)
    end

    create(index(:bundle_items, [:bundle_id]))
    create(unique_index(:bundle_items, [:bundle_id, :item_id]))
  end
end
