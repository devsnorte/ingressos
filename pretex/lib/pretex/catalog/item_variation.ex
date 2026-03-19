defmodule Pretex.Catalog.ItemVariation do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(active inactive)

  schema "item_variations" do
    field(:name, :string)
    field(:price_cents, :integer, default: 0)
    field(:stock, :integer)
    field(:status, :string, default: "active")

    belongs_to(:item, Pretex.Catalog.Item)
    has_many(:quota_items, Pretex.Catalog.QuotaItem)

    timestamps(type: :utc_datetime)
  end

  def changeset(variation, attrs) do
    variation
    |> cast(attrs, [:name, :price_cents, :stock, :status])
    |> validate_required([:name, :price_cents, :status])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_number(:price_cents, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, @statuses)
  end
end
