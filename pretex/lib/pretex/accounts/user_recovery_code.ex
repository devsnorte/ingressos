defmodule Pretex.Accounts.UserRecoveryCode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_recovery_codes" do
    field :code_hash, :string
    field :used_at, :utc_datetime
    belongs_to :user, Pretex.Accounts.User
    timestamps type: :utc_datetime
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:code_hash, :used_at])
    |> validate_required([:code_hash])
  end
end
