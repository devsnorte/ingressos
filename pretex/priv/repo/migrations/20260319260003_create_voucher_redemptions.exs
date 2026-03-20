defmodule Pretex.Repo.Migrations.CreateVoucherRedemptions do
  use Ecto.Migration

  def change do
    create table(:voucher_redemptions) do
      add(:discount_cents, :integer, null: false, default: 0)
      add(:voucher_id, references(:vouchers, on_delete: :nilify_all), null: true)
      add(:order_id, references(:orders, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(
      unique_index(:voucher_redemptions, [:order_id], name: :voucher_redemptions_order_id_index)
    )
  end
end
