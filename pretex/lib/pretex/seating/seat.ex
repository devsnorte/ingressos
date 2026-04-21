defmodule Pretex.Seating.Seat do
  @moduledoc """
  An individual seat within a seating section.

  Seats are identified by their row label and number (e.g. row "A", number 5),
  and carry a human-readable label (e.g. "A-5"). The status field reflects
  whether the seat is available for selection or permanently blocked by the organizer.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(available blocked)

  @type t :: %__MODULE__{
          id: integer() | nil,
          label: String.t() | nil,
          row: String.t() | nil,
          number: integer() | nil,
          status: String.t() | nil,
          seating_section_id: integer() | nil,
          seating_section: Pretex.Seating.SeatingSection.t() | Ecto.Association.NotLoaded.t(),
          reservations: [Pretex.Seating.SeatReservation.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "seats" do
    field :label, :string
    field :row, :string
    field :number, :integer
    field :status, :string, default: "available"

    belongs_to :seating_section, Pretex.Seating.SeatingSection
    has_many :reservations, Pretex.Seating.SeatReservation

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a seat."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(seat, attrs) do
    seat
    |> cast(attrs, [:label, :row, :number, :status, :seating_section_id])
    |> validate_required([:label, :row, :number, :status, :seating_section_id])
    |> validate_length(:label, min: 1, max: 20)
    |> validate_length(:row, min: 1, max: 10)
    |> validate_number(:number, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:seating_section_id, :row, :number])
  end

  @doc "Returns the list of valid seat statuses."
  @spec statuses() :: [String.t()]
  def statuses, do: @statuses
end
