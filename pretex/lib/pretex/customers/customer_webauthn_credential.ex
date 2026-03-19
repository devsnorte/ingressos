defmodule Pretex.Customers.CustomerWebAuthnCredential do
  use Ecto.Schema
  import Ecto.Changeset

  schema "customer_webauthn_credentials" do
    field :credential_id, :binary
    field :public_key_cbor, :binary
    field :sign_count, :integer, default: 0
    field :label, :string
    field :last_used_at, :utc_datetime
    belongs_to :customer, Pretex.Customers.Customer
    timestamps type: :utc_datetime
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:credential_id, :public_key_cbor, :sign_count, :label, :last_used_at])
    |> validate_required([:credential_id, :public_key_cbor])
    |> unique_constraint(:credential_id)
  end
end
