defmodule Pretex.Orders.OrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_items" do
    field(:quantity, :integer, default: 1)
    field(:unit_price_cents, :integer)
    field(:attendee_name, :string)
    field(:attendee_email, :string)
    field(:ticket_code, :string)

    belongs_to(:order, Pretex.Orders.Order)
    belongs_to(:item, Pretex.Catalog.Item)
    belongs_to(:item_variation, Pretex.Catalog.ItemVariation)
    has_many(:answers, Pretex.Orders.OrderAnswer)

    timestamps(type: :utc_datetime)
  end

  def changeset(order_item, attrs) do
    order_item
    |> cast(attrs, [:quantity, :unit_price_cents, :attendee_name, :attendee_email])
    |> validate_required([:quantity, :unit_price_cents])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price_cents, greater_than_or_equal_to: 0)
  end
end
