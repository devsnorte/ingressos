defmodule Pretex.Discounts.DiscountRuleItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "discount_rule_items" do
    belongs_to(:discount_rule, Pretex.Discounts.DiscountRule)
    belongs_to(:item, Pretex.Catalog.Item)
    belongs_to(:item_variation, Pretex.Catalog.ItemVariation)

    timestamps(type: :utc_datetime)
  end

  def changeset(dri, attrs) do
    dri
    |> cast(attrs, [:discount_rule_id, :item_id, :item_variation_id])
    |> validate_required([:discount_rule_id])
  end
end
