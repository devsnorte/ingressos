defmodule Pretex.Seating.SeatingPlan do
  @moduledoc """
  Represents a venue seating plan consisting of named sections, rows, and seats.

  A seating plan belongs to an organization and may be assigned to multiple events.
  The `layout` field stores the original uploaded JSON structure for reference.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          layout: map() | nil,
          organization_id: integer() | nil,
          sections: [Pretex.Seating.SeatingSection.t()] | Ecto.Association.NotLoaded.t(),
          events: [Pretex.Events.Event.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "seating_plans" do
    field :name, :string
    field :layout, :map

    belongs_to :organization, Pretex.Organizations.Organization
    has_many :sections, Pretex.Seating.SeatingSection
    has_many :events, Pretex.Events.Event

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating or updating a seating plan."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [:name, :layout, :organization_id])
    |> validate_required([:name, :layout, :organization_id])
    |> validate_length(:name, min: 2, max: 255)
  end
end
