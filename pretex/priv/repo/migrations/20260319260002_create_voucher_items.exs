defmodule Pretex.Repo.Migrations.CreateVoucherItems do
  use Ecto.Migration

  def change do
    create table(:voucher_items) do
      add(:voucher_id, references(:vouchers, on_delete: :delete_all), null: false)
      add(:item_id, references(:items, on_delete: :delete_all))
      add(:item_variation_id, references(:item_variations, on_delete: :delete_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:voucher_items, [:voucher_id]))
    create(index(:voucher_items, [:item_id]))
    create(index(:voucher_items, [:item_variation_id]))
  end
end
