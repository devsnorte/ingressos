defmodule Pretex.OrganizationsTest do
  use Pretex.DataCase, async: true

  alias Pretex.Organizations
  alias Pretex.Organizations.Organization

  describe "organizations" do
    @valid_attrs %{
      name: "Devs Norte",
      slug: "devs-norte",
      display_name: "Devs Norte Community",
      description: "A developer community in Northern Brazil"
    }
    @update_attrs %{name: "Devs Norte Updated", display_name: "Updated Display Name"}
    @invalid_attrs %{name: nil, slug: nil}

    defp organization_fixture(attrs \\ %{}) do
      {:ok, organization} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Organizations.create_organization()

      organization
    end

    test "list_organizations/0 returns all organizations ordered by name" do
      org1 = organization_fixture(%{name: "Zebra Org", slug: "zebra-org"})
      org2 = organization_fixture(%{name: "Alpha Org", slug: "alpha-org"})

      organizations = Organizations.list_organizations()
      assert [^org2, ^org1] = organizations
    end

    test "list_organizations/0 returns empty list when no organizations exist" do
      assert Organizations.list_organizations() == []
    end

    test "get_organization!/1 returns the organization with given id" do
      organization = organization_fixture()
      assert Organizations.get_organization!(organization.id) == organization
    end

    test "get_organization!/1 raises when organization does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Organizations.get_organization!(0)
      end
    end

    test "get_organization_by_slug!/1 returns organization by slug" do
      organization = organization_fixture()
      assert Organizations.get_organization_by_slug!(organization.slug) == organization
    end

    test "create_organization/1 with valid data creates an organization" do
      assert {:ok, %Organization{} = organization} =
               Organizations.create_organization(@valid_attrs)

      assert organization.name == "Devs Norte"
      assert organization.slug == "devs-norte"
      assert organization.display_name == "Devs Norte Community"
      assert organization.is_active == true
    end

    test "create_organization/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Organizations.create_organization(@invalid_attrs)
    end

    test "create_organization/1 with duplicate slug returns error" do
      organization_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Organizations.create_organization(@valid_attrs)

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "create_organization/1 with invalid slug format returns error" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Organizations.create_organization(%{name: "Test", slug: "INVALID SLUG!"})

      assert %{slug: [_]} = errors_on(changeset)
    end

    test "create_organization/1 with slug too short returns error" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Organizations.create_organization(%{name: "Test", slug: "a"})

      assert %{slug: [_ | _]} = errors_on(changeset)
    end

    test "update_organization/2 with valid data updates the organization" do
      organization = organization_fixture()

      assert {:ok, %Organization{} = updated} =
               Organizations.update_organization(organization, @update_attrs)

      assert updated.name == "Devs Norte Updated"
      assert updated.display_name == "Updated Display Name"
      # Slug should NOT change on update
      assert updated.slug == organization.slug
    end

    test "update_organization/2 with invalid data returns error changeset" do
      organization = organization_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Organizations.update_organization(organization, @invalid_attrs)

      assert organization == Organizations.get_organization!(organization.id)
    end

    test "delete_organization/1 deletes the organization" do
      organization = organization_fixture()
      assert {:ok, %Organization{}} = Organizations.delete_organization(organization)
      assert_raise Ecto.NoResultsError, fn -> Organizations.get_organization!(organization.id) end
    end

    test "count_organizations/0 returns the count" do
      assert Organizations.count_organizations() == 0
      organization_fixture()
      assert Organizations.count_organizations() == 1
    end

    test "change_organization/1 returns a changeset" do
      organization = organization_fixture()
      assert %Ecto.Changeset{} = Organizations.change_organization(organization)
    end
  end
end
