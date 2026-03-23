defmodule Pretex.Devices.DeviceInitToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_init_tokens" do
    field(:token_hash, :string)
    field(:expires_at, :utc_datetime)
    field(:used_at, :utc_datetime)

    belongs_to(:organization, Pretex.Organizations.Organization)
    belongs_to(:created_by, Pretex.Accounts.User, foreign_key: :created_by_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:expires_at, :used_at])
    |> validate_required([:expires_at])
  end
end
