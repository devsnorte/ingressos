defmodule Pretex.Catalog.ItemCategory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "item_categories" do
    field(:name, :string)
    field(:position, :integer, default: 0)

    belongs_to(:event, Pretex.Events.Event)
    has_many(:items, Pretex.Catalog.Item, foreign_key: :category_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :position])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
  end
end
