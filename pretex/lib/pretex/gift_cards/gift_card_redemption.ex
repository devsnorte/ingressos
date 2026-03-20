defmodule Pretex.GiftCards.GiftCardRedemption do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(debit credit)

  schema "gift_card_redemptions" do
    field(:amount_cents, :integer, default: 0)
    field(:kind, :string, default: "debit")
    field(:note, :string)

    belongs_to(:gift_card, Pretex.GiftCards.GiftCard)
    belongs_to(:order, Pretex.Orders.Order)

    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds

  def changeset(r, attrs) do
    r
    |> cast(attrs, [:amount_cents, :kind, :note, :gift_card_id, :order_id])
    |> validate_required([:amount_cents, :kind, :gift_card_id])
    |> validate_inclusion(:kind, @kinds)
    |> validate_number(:amount_cents, greater_than: 0)
  end
end
