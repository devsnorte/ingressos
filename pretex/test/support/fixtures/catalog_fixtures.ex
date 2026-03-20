defmodule Pretex.CatalogFixtures do
  alias Pretex.Catalog

  def item_fixture(event, attrs \\ %{}) do
    {:ok, item} =
      Catalog.create_item(
        event,
        Enum.into(attrs, %{
          name: "Test Item #{System.unique_integer([:positive])}",
          price_cents: 5000
        })
      )

    item
  end

  def category_fixture(event, attrs \\ %{}) do
    {:ok, category} =
      Catalog.create_category(
        event,
        Enum.into(attrs, %{
          name: "Test Category #{System.unique_integer([:positive])}"
        })
      )

    category
  end

  def variation_fixture(item, attrs \\ %{}) do
    {:ok, variation} =
      Catalog.create_variation(
        item,
        Enum.into(attrs, %{
          name: "Test Variation #{System.unique_integer([:positive])}",
          price_cents: 6000
        })
      )

    variation
  end

  def quota_fixture(event, attrs \\ %{}) do
    {:ok, quota} =
      Catalog.create_quota(
        event,
        Enum.into(attrs, %{
          name: "Test Quota #{System.unique_integer([:positive])}",
          capacity: 100
        })
      )

    quota
  end
end
