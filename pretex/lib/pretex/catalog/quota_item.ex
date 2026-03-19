defmodule Pretex.Catalog.QuotaItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quota_items" do
    belongs_to(:quota, Pretex.Catalog.Quota)
    belongs_to(:item, Pretex.Catalog.Item)
    belongs_to(:item_variation, Pretex.Catalog.ItemVariation)

    timestamps(type: :utc_datetime)
  end

  def changeset(quota_item, attrs) do
    quota_item
    |> cast(attrs, [:quota_id, :item_id, :item_variation_id])
    |> validate_required([:quota_id])
    |> validate_item_or_variation()
  end

  defp validate_item_or_variation(changeset) do
    item_id = get_field(changeset, :item_id)
    variation_id = get_field(changeset, :item_variation_id)

    if is_nil(item_id) and is_nil(variation_id) do
      add_error(changeset, :item_id, "must assign either an item or a variation")
    else
      changeset
    end
  end
end
