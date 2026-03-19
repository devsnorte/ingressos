defmodule Pretex.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending confirmed cancelled expired)
  @payment_methods ~w(credit_card boleto bank_transfer pix)

  schema "orders" do
    field(:status, :string, default: "pending")
    field(:total_cents, :integer, default: 0)
    field(:email, :string)
    field(:name, :string)
    field(:expires_at, :utc_datetime)
    field(:payment_method, :string)
    field(:confirmation_code, :string)

    belongs_to(:event, Pretex.Events.Event)
    belongs_to(:customer, Pretex.Customers.Customer)
    has_many(:order_items, Pretex.Orders.OrderItem)

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def payment_methods, do: @payment_methods

  def changeset(order, attrs) do
    order
    |> cast(attrs, [:email, :name, :payment_method, :expires_at])
    |> validate_required([:email, :name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:name, min: 2, max: 255)
    |> validate_inclusion(:payment_method, @payment_methods,
      message: "is not a valid payment method"
    )
  end
end
