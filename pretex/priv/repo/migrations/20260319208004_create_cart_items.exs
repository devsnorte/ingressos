defmodule Pretex.Repo.Migrations.CreateCartItems do
  use Ecto.Migration

  def change do
    create table(:cart_items) do
      add(:cart_session_id, references(:cart_sessions, on_delete: :delete_all), null: false)
      add(:item_id, references(:items, on_delete: :delete_all), null: false)
      add(:item_variation_id, references(:item_variations, on_delete: :delete_all))
      add(:quantity, :integer, default: 1, null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:cart_items, [:cart_session_id]))
  end
end
