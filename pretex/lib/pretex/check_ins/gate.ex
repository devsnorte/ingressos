defmodule Pretex.CheckIns.Gate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gates" do
    field(:name, :string)

    belongs_to(:event, Pretex.Events.Event)

    many_to_many(:check_in_lists, Pretex.CheckIns.CheckInList,
      join_through: "gate_check_in_lists"
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(gate, attrs) do
    gate
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
  end
end
