defmodule Pretex.Orders.CartItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cart_items" do
    field(:quantity, :integer, default: 1)

    belongs_to(:cart_session, Pretex.Orders.CartSession)
    belongs_to(:item, Pretex.Catalog.Item)
    belongs_to(:item_variation, Pretex.Catalog.ItemVariation)

    timestamps(type: :utc_datetime)
  end

  def changeset(cart_item, attrs) do
    cart_item
    |> cast(attrs, [:quantity, :item_id, :item_variation_id])
    |> validate_required([:quantity, :item_id])
    |> validate_number(:quantity, greater_than: 0)
  end
end
