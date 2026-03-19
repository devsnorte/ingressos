defmodule Pretex.Teams.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "memberships" do
    belongs_to(:organization, Pretex.Organizations.Organization)
    belongs_to(:user, Pretex.Accounts.User)

    field(:role, :string)
    field(:is_active, :boolean, default: true)

    has_many(:permissions, Pretex.Teams.OrganizationPermission)

    timestamps(type: :utc_datetime)
  end

  @valid_roles ~w(admin event_manager checkin_operator)

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :is_active])
    |> validate_required([:role])
    |> validate_inclusion(:role, @valid_roles,
      message: "must be one of: admin, event_manager, checkin_operator"
    )
    |> unique_constraint([:organization_id, :user_id],
      name: :memberships_organization_id_user_id_index,
      message: "user is already a member of this organization"
    )
  end
end
