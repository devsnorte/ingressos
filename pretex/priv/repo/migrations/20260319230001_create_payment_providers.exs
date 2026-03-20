defmodule Pretex.Repo.Migrations.CreatePaymentProviders do
  use Ecto.Migration

  def change do
    create table(:payment_providers) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      # "manual", "woovi", "stripe", "abacatepay", "asaas"
      add :type, :string, null: false
      # Display name: "Stripe Principal", "Pix Woovi"
      add :name, :string, null: false
      # Encrypted JSON
      add :credentials, :binary, null: false
      add :is_active, :boolean, default: false, null: false
      add :is_default, :boolean, default: false, null: false
      # Unique token for webhook routing
      add :webhook_token, :string, null: false
      add :last_validated_at, :utc_datetime
      # "pending", "valid", "invalid"
      add :validation_status, :string, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:payment_providers, [:organization_id])
    create unique_index(:payment_providers, [:webhook_token])

    create unique_index(:payment_providers, [:organization_id, :type, :name],
             name: :payment_providers_org_type_name
           )
  end
end
