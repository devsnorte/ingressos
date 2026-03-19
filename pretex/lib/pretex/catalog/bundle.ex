defmodule Pretex.Catalog.Bundle do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(active inactive)

  schema "bundles" do
    field(:name, :string)
    field(:description, :string)
    field(:price_cents, :integer, default: 0)
    field(:status, :string, default: "active")

    belongs_to(:event, Pretex.Events.Event)
    many_to_many(:items, Pretex.Catalog.Item, join_through: "bundle_items")

    timestamps(type: :utc_datetime)
  end

  def changeset(bundle, attrs) do
    bundle
    |> cast(attrs, [:name, :description, :price_cents, :status])
    |> validate_required([:name, :price_cents, :status])
    |> validate_length(:name, min: 2, max: 255)
    |> validate_number(:price_cents, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, @statuses)
  end
end
