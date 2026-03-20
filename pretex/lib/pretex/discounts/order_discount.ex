defmodule Pretex.Discounts.OrderDiscount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_discounts" do
    field(:name, :string)
    field(:discount_cents, :integer, default: 0)
    field(:value_type, :string)
    field(:value, :integer)

    belongs_to(:order, Pretex.Orders.Order)
    belongs_to(:discount_rule, Pretex.Discounts.DiscountRule)

    timestamps(type: :utc_datetime)
  end

  def changeset(od, attrs) do
    od
    |> cast(attrs, [:name, :discount_cents, :value_type, :value, :order_id, :discount_rule_id])
    |> validate_required([:name, :discount_cents])
    |> validate_number(:discount_cents, greater_than_or_equal_to: 0)
  end
end
