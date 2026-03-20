defmodule Pretex.Memberships.MembershipType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "membership_types" do
    field(:name, :string)
    field(:description, :string)
    field(:validity_days, :integer)
    field(:active, :boolean, default: true)

    belongs_to(:organization, Pretex.Organizations.Organization)
    has_many(:benefits, Pretex.Memberships.MembershipBenefit)
    has_many(:memberships, Pretex.Memberships.Membership)

    timestamps(type: :utc_datetime)
  end

  def changeset(membership_type, attrs) do
    membership_type
    |> cast(attrs, [:name, :description, :validity_days, :active, :organization_id])
    |> validate_required([:name, :validity_days])
    |> validate_length(:name, min: 2, max: 255)
    |> validate_number(:validity_days, greater_than: 0)
  end
end
