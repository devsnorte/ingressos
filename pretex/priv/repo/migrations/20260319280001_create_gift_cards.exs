defmodule Pretex.Repo.Migrations.CreateGiftCards do
  use Ecto.Migration

  def change do
    create table(:gift_cards) do
      add(:code, :string, null: false)
      add(:balance_cents, :integer, null: false, default: 0)
      add(:initial_balance_cents, :integer, null: false, default: 0)
      add(:expires_at, :utc_datetime)
      add(:active, :boolean, null: false, default: true)
      add(:note, :string)
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:source_order_id, references(:orders, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:gift_cards, [:code], name: :gift_cards_code_index))
    create(index(:gift_cards, [:organization_id]))
    create(index(:gift_cards, [:source_order_id]))
  end
end
