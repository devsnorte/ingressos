defmodule Pretex.CheckIns.CheckInList do
  use Ecto.Schema
  import Ecto.Changeset

  schema "check_in_lists" do
    field(:name, :string)
    field(:starts_at_time, :time)
    field(:ends_at_time, :time)

    belongs_to(:event, Pretex.Events.Event)
    has_many(:check_in_list_items, Pretex.CheckIns.CheckInListItem)
    many_to_many(:gates, Pretex.CheckIns.Gate, join_through: "gate_check_in_lists")

    timestamps(type: :utc_datetime)
  end

  def changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :starts_at_time, :ends_at_time])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_time_window()
  end

  defp validate_time_window(changeset) do
    starts = get_field(changeset, :starts_at_time)
    ends = get_field(changeset, :ends_at_time)

    if starts && ends && Time.compare(ends, starts) != :gt do
      add_error(changeset, :ends_at_time, "must be after start time")
    else
      changeset
    end
  end
end
