defmodule Pretex.Catalog.Quota do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quotas" do
    field(:name, :string)
    field(:capacity, :integer)
    field(:sold_count, :integer, default: 0)

    belongs_to(:event, Pretex.Events.Event)
    has_many(:quota_items, Pretex.Catalog.QuotaItem)

    timestamps(type: :utc_datetime)
  end

  def changeset(quota, attrs) do
    quota
    |> cast(attrs, [:name, :capacity])
    |> validate_required([:name, :capacity])
    |> validate_length(:name, min: 2, max: 255)
    |> validate_number(:capacity, greater_than: 0)
  end
end
