defmodule Pretex.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :totp_secret, :binary
    field :totp_enabled_at, :utc_datetime

    has_many :memberships, Pretex.Teams.Membership
    has_many :recovery_codes, Pretex.Accounts.UserRecoveryCode
    has_many :webauthn_credentials, Pretex.Accounts.UserWebAuthnCredential

    timestamps type: :utc_datetime
  end

  def totp_enabled?(%__MODULE__{totp_enabled_at: ts}), do: not is_nil(ts)

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required([:email, :name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email address")
    |> unique_constraint(:email)
  end
end
