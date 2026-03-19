defmodule Pretex.Catalog.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @item_types ~w(ticket merchandise addon)
  @statuses ~w(active inactive)

  schema "items" do
    field(:name, :string)
    field(:description, :string)
    field(:price_cents, :integer, default: 0)
    field(:available_quantity, :integer)
    field(:item_type, :string, default: "ticket")
    field(:is_addon, :boolean, default: false)
    field(:require_voucher, :boolean, default: false)
    field(:min_per_order, :integer, default: 1)
    field(:max_per_order, :integer)
    field(:status, :string, default: "active")

    belongs_to(:event, Pretex.Events.Event)
    belongs_to(:category, Pretex.Catalog.ItemCategory)
    has_many(:variations, Pretex.Catalog.ItemVariation)
    has_many(:quota_items, Pretex.Catalog.QuotaItem)

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :name,
      :description,
      :price_cents,
      :available_quantity,
      :item_type,
      :is_addon,
      :require_voucher,
      :min_per_order,
      :max_per_order,
      :status,
      :category_id
    ])
    |> validate_required([:name, :price_cents, :item_type, :status])
    |> validate_length(:name, min: 2, max: 255)
    |> validate_number(:price_cents, greater_than_or_equal_to: 0)
    |> validate_inclusion(:item_type, @item_types)
    |> validate_inclusion(:status, @statuses)
  end
end
