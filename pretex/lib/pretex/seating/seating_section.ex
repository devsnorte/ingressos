defmodule Pretex.Seating.SeatingSection do
  @moduledoc """
  A named section within a seating plan (e.g. "Orchestra", "Balcony").

  Sections contain individual seats and may be mapped to a catalog item and optional
  item variation, allowing organizers to sell different ticket types per section.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          row_count: integer() | nil,
          capacity: integer() | nil,
          seating_plan_id: integer() | nil,
          item_id: integer() | nil,
          item_variation_id: integer() | nil,
          seating_plan: Pretex.Seating.SeatingPlan.t() | Ecto.Association.NotLoaded.t(),
          seats: [Pretex.Seating.Seat.t()] | Ecto.Association.NotLoaded.t(),
          item: Pretex.Catalog.Item.t() | nil | Ecto.Association.NotLoaded.t(),
          item_variation: Pretex.Catalog.ItemVariation.t() | nil | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "seating_sections" do
    field :name, :string
    field :row_count, :integer
    field :capacity, :integer

    belongs_to :seating_plan, Pretex.Seating.SeatingPlan
    belongs_to :item, Pretex.Catalog.Item
    belongs_to :item_variation, Pretex.Catalog.ItemVariation

    has_many :seats, Pretex.Seating.Seat

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a seating section."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(section, attrs) do
    section
    |> cast(attrs, [:name, :row_count, :capacity, :seating_plan_id, :item_id, :item_variation_id])
    |> validate_required([:name, :capacity, :seating_plan_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:capacity, greater_than: 0)
  end

  @doc "Changeset for mapping a section to a catalog item and optional variation."
  @spec mapping_changeset(t(), map()) :: Ecto.Changeset.t()
  def mapping_changeset(section, attrs) do
    section
    |> cast(attrs, [:item_id, :item_variation_id])
  end
end
