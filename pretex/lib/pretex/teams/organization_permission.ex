defmodule Pretex.Teams.OrganizationPermission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organization_permissions" do
    belongs_to(:membership, Pretex.Teams.Membership)

    field(:resource, :string)
    field(:can_read, :boolean, default: true)
    field(:can_write, :boolean, default: false)
    field(:event_id, :integer)

    timestamps(type: :utc_datetime)
  end

  @valid_resources ~w(events orders vouchers reports settings)

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:resource, :can_read, :can_write, :event_id])
    |> validate_required([:resource, :can_read, :can_write])
    |> validate_inclusion(:resource, @valid_resources,
      message: "must be one of: events, orders, vouchers, reports, settings"
    )
    |> unique_constraint([:membership_id, :resource, :event_id],
      name: :organization_permissions_membership_resource_event_index,
      message: "permission for this resource already exists"
    )
  end
end
