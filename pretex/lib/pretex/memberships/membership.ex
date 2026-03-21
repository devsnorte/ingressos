defmodule Pretex.Memberships.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(active expired cancelled)

  schema "customer_memberships" do
    field(:starts_at, :utc_datetime)
    field(:expires_at, :utc_datetime)
    field(:status, :string, default: "active")

    belongs_to(:membership_type, Pretex.Memberships.MembershipType)
    belongs_to(:customer, Pretex.Customers.Customer)
    belongs_to(:organization, Pretex.Organizations.Organization)
    belongs_to(:source_order, Pretex.Orders.Order, foreign_key: :source_order_id)

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [
      :starts_at,
      :expires_at,
      :status,
      :membership_type_id,
      :customer_id,
      :organization_id,
      :source_order_id
    ])
    |> validate_required([
      :starts_at,
      :expires_at,
      :status,
      :membership_type_id,
      :customer_id,
      :organization_id
    ])
    |> validate_inclusion(:status, @statuses)
  end
end
