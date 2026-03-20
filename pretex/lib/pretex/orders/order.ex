defmodule Pretex.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending confirmed cancelled expired)
  @payment_methods ~w(credit_card debit_card boleto bank_transfer pix cash)

  schema "orders" do
    field(:status, :string, default: "pending")
    field(:total_cents, :integer, default: 0)
    field(:email, :string)
    field(:name, :string)
    field(:expires_at, :utc_datetime)
    field(:payment_method, :string)
    field(:confirmation_code, :string)
    field(:payment_provider_id, :integer)
    field(:locked_by_organizer, :boolean, default: false)

    belongs_to(:event, Pretex.Events.Event)
    belongs_to(:customer, Pretex.Customers.Customer)
    has_many(:order_items, Pretex.Orders.OrderItem)
    has_many(:fees, Pretex.Fees.OrderFee)
    has_one(:voucher_redemption, Pretex.Vouchers.VoucherRedemption)
    has_many(:discounts, Pretex.Discounts.OrderDiscount)
    has_many(:gift_card_redemptions, Pretex.GiftCards.GiftCardRedemption)

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def payment_methods, do: @payment_methods

  def changeset(order, attrs) do
    order
    |> cast(attrs, [
      :email,
      :name,
      :payment_method,
      :expires_at,
      :payment_provider_id,
      :locked_by_organizer
    ])
    |> validate_required([:email, :name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:name, min: 2, max: 255)
    |> validate_inclusion(:payment_method, @payment_methods,
      message: "is not a valid payment method"
    )
  end
end
