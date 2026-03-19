defmodule Pretex.Orders.CartSession do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(active checked_out expired)

  schema "cart_sessions" do
    field(:session_token, :string)
    field(:expires_at, :utc_datetime)
    field(:status, :string, default: "active")

    belongs_to(:event, Pretex.Events.Event)
    has_many(:cart_items, Pretex.Orders.CartItem)

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(cart, attrs) do
    cart
    |> cast(attrs, [:session_token, :expires_at, :status])
    |> validate_required([:session_token, :expires_at])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:session_token)
  end
end
