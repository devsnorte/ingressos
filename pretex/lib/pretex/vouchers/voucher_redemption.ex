defmodule Pretex.Vouchers.VoucherRedemption do
  use Ecto.Schema
  import Ecto.Changeset

  schema "voucher_redemptions" do
    field(:discount_cents, :integer, default: 0)

    belongs_to(:voucher, Pretex.Vouchers.Voucher)
    belongs_to(:order, Pretex.Orders.Order)

    timestamps(type: :utc_datetime)
  end

  def changeset(r, attrs) do
    r
    |> cast(attrs, [:discount_cents, :voucher_id, :order_id])
    |> validate_required([:voucher_id, :order_id])
    |> unique_constraint(:order_id, name: :voucher_redemptions_order_id_index)
  end
end
