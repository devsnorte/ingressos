defmodule Pretex.Teams.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invitations" do
    belongs_to(:organization, Pretex.Organizations.Organization)
    belongs_to(:invited_by, Pretex.Accounts.User)

    field(:email, :string)
    field(:role, :string)
    field(:token, :string)
    field(:accepted_at, :utc_datetime)
    field(:expires_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @valid_roles ~w(admin event_manager checkin_operator)

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :role])
    |> validate_required([:email, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email address")
    |> validate_inclusion(:role, @valid_roles,
      message: "must be one of: admin, event_manager, checkin_operator"
    )
    |> unique_constraint([:organization_id, :email],
      name: :invitations_organization_id_email_pending_index,
      message: "an invitation for this email already exists in this organization"
    )
  end
end
