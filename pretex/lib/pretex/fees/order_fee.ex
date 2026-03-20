defmodule Pretex.Fees.OrderFee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_fees" do
    field(:name, :string)
    field(:fee_type, :string)
    field(:amount_cents, :integer)
    field(:value_type, :string)
    field(:value, :integer)

    belongs_to(:order, Pretex.Orders.Order)
    belongs_to(:fee_rule, Pretex.Fees.FeeRule)

    timestamps(type: :utc_datetime)
  end

  def changeset(order_fee, attrs) do
    order_fee
    |> cast(attrs, [:name, :fee_type, :amount_cents, :value_type, :value, :order_id, :fee_rule_id])
    |> validate_required([:name, :fee_type, :amount_cents, :value_type, :value])
    |> validate_number(:amount_cents, greater_than_or_equal_to: 0)
  end
end
