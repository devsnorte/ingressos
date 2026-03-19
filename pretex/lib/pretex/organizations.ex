defmodule Pretex.Organizations do
  @moduledoc """
  The Organizations context manages multi-tenant organization lifecycle.
  """

  import Ecto.Query
  alias Pretex.Repo
  alias Pretex.Organizations.Organization

  def list_organizations do
    Organization
    |> order_by(asc: :name)
    |> Repo.all()
  end

  def get_organization!(id), do: Repo.get!(Organization, id)

  def get_organization_by_slug!(slug) do
    Repo.get_by!(Organization, slug: slug)
  end

  def create_organization(attrs \\ %{}) do
    %Organization{}
    |> Organization.creation_changeset(attrs)
    |> Repo.insert()
  end

  def update_organization(%Organization{} = organization, attrs) do
    organization
    |> Organization.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_organization(%Organization{} = organization) do
    Repo.delete(organization)
  end

  def change_organization(%Organization{} = organization, attrs \\ %{}) do
    Organization.creation_changeset(organization, attrs)
  end

  def count_organizations do
    Repo.aggregate(Organization, :count)
  end

  @doc "Sets or clears the require_2fa flag for an organization."
  def set_require_2fa(%Organization{} = org, required) when is_boolean(required) do
    org
    |> Ecto.Changeset.change(require_2fa: required)
    |> Repo.update()
  end
end
