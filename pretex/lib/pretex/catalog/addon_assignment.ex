defmodule Pretex.Catalog.AddonAssignment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "addon_assignments" do
    belongs_to(:item, Pretex.Catalog.Item)
    belongs_to(:parent_item, Pretex.Catalog.Item, foreign_key: :parent_item_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(addon_assignment, attrs) do
    addon_assignment
    |> cast(attrs, [:item_id, :parent_item_id])
    |> validate_required([:item_id, :parent_item_id])
    |> unique_constraint([:item_id, :parent_item_id])
  end
end
