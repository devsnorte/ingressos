defmodule Pretex.GiftCards.GiftCard do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gift_cards" do
    field(:code, :string)
    field(:balance_cents, :integer, default: 0)
    field(:initial_balance_cents, :integer, default: 0)
    field(:expires_at, :utc_datetime)
    field(:active, :boolean, default: true)
    field(:note, :string)

    belongs_to(:organization, Pretex.Organizations.Organization)
    belongs_to(:source_order, Pretex.Orders.Order, foreign_key: :source_order_id)
    has_many(:redemptions, Pretex.GiftCards.GiftCardRedemption)

    timestamps(type: :utc_datetime)
  end

  def changeset(gc, attrs) do
    gc
    |> cast(attrs, [
      :code,
      :balance_cents,
      :initial_balance_cents,
      :expires_at,
      :active,
      :note,
      :organization_id,
      :source_order_id
    ])
    |> validate_required([:code, :balance_cents])
    |> validate_number(:balance_cents, greater_than_or_equal_to: 0)
    |> validate_number(:initial_balance_cents, greater_than_or_equal_to: 0)
    |> validate_length(:code, min: 1, max: 64)
    |> update_change(:code, &String.upcase(String.trim(&1)))
    |> unique_constraint(:code, name: :gift_cards_code_index)
  end
end
