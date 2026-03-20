defmodule Pretex.Vouchers.VoucherItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "voucher_items" do
    belongs_to(:voucher, Pretex.Vouchers.Voucher)
    belongs_to(:item, Pretex.Catalog.Item)
    belongs_to(:item_variation, Pretex.Catalog.ItemVariation)

    timestamps(type: :utc_datetime)
  end

  def changeset(vi, attrs) do
    vi
    |> cast(attrs, [:voucher_id, :item_id, :item_variation_id])
    |> validate_required([:voucher_id])
  end
end
