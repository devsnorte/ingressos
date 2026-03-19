defmodule Pretex.Organizations.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organizations" do
    field :name, :string
    field :slug, :string
    field :display_name, :string
    field :description, :string
    field :logo_url, :string
    field :is_active, :boolean, default: true
    field :require_2fa, :boolean, default: false

    timestamps type: :utc_datetime
  end

  def creation_changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug, :display_name, :description, :logo_url])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:slug, min: 2, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9-]*[a-z0-9]$/,
      message: "must be lowercase alphanumeric with hyphens, cannot start or end with a hyphen"
    )
    |> unique_constraint(:slug)
  end

  def update_changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :display_name, :description, :logo_url])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
  end
end
