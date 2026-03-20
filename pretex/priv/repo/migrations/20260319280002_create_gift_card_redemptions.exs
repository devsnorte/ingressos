defmodule Pretex.Repo.Migrations.CreateGiftCardRedemptions do
  use Ecto.Migration

  def change do
    create table(:gift_card_redemptions) do
      add(:amount_cents, :integer, null: false, default: 0)
      add(:kind, :string, null: false, default: "debit")
      add(:note, :string)
      add(:gift_card_id, references(:gift_cards, on_delete: :delete_all), null: false)
      add(:order_id, references(:orders, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:gift_card_redemptions, [:gift_card_id]))
    create(index(:gift_card_redemptions, [:order_id]))
  end
end
