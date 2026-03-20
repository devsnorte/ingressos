defmodule Pretex.OrganizationsFixtures do
  alias Pretex.Organizations

  def unique_org_slug, do: "org-#{System.unique_integer([:positive])}"

  def org_fixture(attrs \\ %{}) do
    {:ok, org} =
      attrs
      |> Enum.into(%{
        name: "Test Org #{System.unique_integer([:positive])}",
        slug: unique_org_slug(),
        display_name: "Test Organization"
      })
      |> Organizations.create_organization()

    org
  end
end
