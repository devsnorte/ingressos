defmodule Pretex.Devices.Device do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(active revoked)

  schema "devices" do
    field(:name, :string)
    field(:api_token_hash, :string)
    field(:status, :string, default: "active")
    field(:last_seen_at, :utc_datetime)
    field(:provisioned_at, :utc_datetime)

    belongs_to(:organization, Pretex.Organizations.Organization)
    belongs_to(:provisioned_by, Pretex.Accounts.User, foreign_key: :provisioned_by_id)

    has_many(:device_assignments, Pretex.Devices.DeviceAssignment)

    timestamps(type: :utc_datetime)
  end

  def changeset(device, attrs) do
    device
    |> cast(attrs, [:name, :status, :last_seen_at])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:status, @statuses)
  end
end
