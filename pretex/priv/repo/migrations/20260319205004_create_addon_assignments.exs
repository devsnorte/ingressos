defmodule Pretex.Repo.Migrations.CreateAddonAssignments do
  use Ecto.Migration

  def change do
    create table(:addon_assignments) do
      add(:item_id, references(:items, on_delete: :delete_all), null: false)
      add(:parent_item_id, references(:items, on_delete: :delete_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:addon_assignments, [:item_id, :parent_item_id]))
  end
end
