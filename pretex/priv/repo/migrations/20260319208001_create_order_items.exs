defmodule Pretex.Repo.Migrations.CreateOrderItems do
  use Ecto.Migration

  def change do
    create table(:order_items) do
      add(:order_id, references(:orders, on_delete: :delete_all), null: false)
      add(:item_id, references(:items, on_delete: :restrict), null: false)
      add(:item_variation_id, references(:item_variations, on_delete: :restrict))
      add(:quantity, :integer, default: 1, null: false)
      add(:unit_price_cents, :integer, null: false)
      add(:attendee_name, :string)
      add(:attendee_email, :string)
      add(:ticket_code, :string)
      timestamps(type: :utc_datetime)
    end

    create(index(:order_items, [:order_id]))
    create(index(:order_items, [:item_id]))
    create(unique_index(:order_items, [:ticket_code]))
  end
end
