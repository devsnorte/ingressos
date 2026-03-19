defmodule Pretex.Customers.CustomerRecoveryCode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "customer_recovery_codes" do
    field :code_hash, :string
    field :used_at, :utc_datetime
    belongs_to :customer, Pretex.Customers.Customer
    timestamps type: :utc_datetime
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:code_hash, :used_at])
    |> validate_required([:code_hash])
  end
end
