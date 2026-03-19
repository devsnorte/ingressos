defmodule Pretex.Repo.Migrations.CreateQuotaItems do
  use Ecto.Migration

  def change do
    create table(:quota_items) do
      add(:quota_id, references(:quotas, on_delete: :delete_all), null: false)
      add(:item_id, references(:items, on_delete: :delete_all))
      add(:item_variation_id, references(:item_variations, on_delete: :delete_all))
      timestamps(type: :utc_datetime)
    end

    create(index(:quota_items, [:quota_id]))
    create(index(:quota_items, [:item_id]))
    create(index(:quota_items, [:item_variation_id]))
    # At least one of item_id or item_variation_id must be set (enforced at app level)
  end
end
