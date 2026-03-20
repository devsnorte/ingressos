defmodule Pretex.Memberships.OrderMembershipDiscount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_membership_discounts" do
    field(:name, :string)
    field(:discount_cents, :integer, default: 0)
    field(:value_type, :string)
    field(:value, :integer)

    belongs_to(:order, Pretex.Orders.Order)
    belongs_to(:membership, Pretex.Memberships.Membership)

    timestamps(type: :utc_datetime)
  end

  def changeset(omd, attrs) do
    omd
    |> cast(attrs, [:name, :discount_cents, :value_type, :value, :order_id, :membership_id])
    |> validate_required([:name, :discount_cents, :value_type, :value])
    |> validate_number(:discount_cents, greater_than_or_equal_to: 0)
  end
end
