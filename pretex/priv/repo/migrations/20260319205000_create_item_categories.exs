defmodule Pretex.Repo.Migrations.CreateItemCategories do
  use Ecto.Migration

  def change do
    create table(:item_categories) do
      add(:event_id, references(:events, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:position, :integer, default: 0)
      timestamps(type: :utc_datetime)
    end

    create(index(:item_categories, [:event_id]))
  end
end
