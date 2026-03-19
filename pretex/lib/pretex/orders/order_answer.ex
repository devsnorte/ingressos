defmodule Pretex.Orders.OrderAnswer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_answers" do
    field(:answer, :string)

    belongs_to(:order_item, Pretex.Orders.OrderItem)
    belongs_to(:question, Pretex.Catalog.Question)

    timestamps(type: :utc_datetime)
  end

  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [:answer])
    |> validate_required([:answer])
  end
end
