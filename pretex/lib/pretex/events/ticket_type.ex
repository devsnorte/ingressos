defmodule Pretex.Events.TicketType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ticket_types" do
    field(:name, :string)
    field(:price_cents, :integer, default: 0)
    field(:quantity, :integer)
    field(:status, :string, default: "active")

    belongs_to(:event, Pretex.Events.Event)

    timestamps(type: :utc_datetime)
  end

  def changeset(ticket_type, attrs) do
    ticket_type
    |> cast(attrs, [:name, :price_cents, :quantity, :status])
    |> validate_required([:name, :price_cents])
    |> validate_number(:price_cents, greater_than_or_equal_to: 0)
  end
end
