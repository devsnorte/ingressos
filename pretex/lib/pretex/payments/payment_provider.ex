defmodule Pretex.Payments.PaymentProvider do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_types ~w(manual woovi stripe abacatepay asaas)

  schema "payment_providers" do
    field :organization_id, :integer
    field :type, :string
    field :name, :string
    # Custom Ecto type
    field :credentials, Pretex.Payments.EncryptedMap
    field :is_active, :boolean, default: false
    field :is_default, :boolean, default: false
    field :webhook_token, :string
    field :last_validated_at, :utc_datetime
    field :validation_status, :string, default: "pending"

    timestamps(type: :utc_datetime)
  end

  def creation_changeset(provider, attrs) do
    provider
    |> cast(attrs, [:organization_id, :type, :name, :credentials, :is_default])
    |> validate_required([:organization_id, :type, :name, :credentials])
    |> validate_inclusion(:type, @valid_types)
    |> validate_length(:name, min: 1, max: 100)
    |> put_webhook_token()
    |> unique_constraint([:organization_id, :type, :name], name: :payment_providers_org_type_name)
    |> unique_constraint(:webhook_token)
  end

  def update_changeset(provider, attrs) do
    provider
    |> cast(attrs, [:name, :credentials, :is_default, :is_active])
    |> validate_length(:name, min: 1, max: 100)
  end

  def validation_changeset(provider, attrs) do
    provider
    |> cast(attrs, [:validation_status, :last_validated_at, :is_active])
  end

  def valid_types, do: @valid_types

  defp put_webhook_token(changeset) do
    if get_field(changeset, :webhook_token) do
      changeset
    else
      put_change(changeset, :webhook_token, generate_webhook_token())
    end
  end

  defp generate_webhook_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
