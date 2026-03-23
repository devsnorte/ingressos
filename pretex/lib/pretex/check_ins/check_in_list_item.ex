defmodule Pretex.CheckIns.CheckInListItem do
  use Ecto.Schema

  schema "check_in_list_items" do
    belongs_to(:check_in_list, Pretex.CheckIns.CheckInList)
    belongs_to(:item, Pretex.Catalog.Item)
    belongs_to(:item_variation, Pretex.Catalog.ItemVariation)
  end
end
