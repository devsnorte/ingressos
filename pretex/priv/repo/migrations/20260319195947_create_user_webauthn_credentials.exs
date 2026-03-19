defmodule Pretex.Repo.Migrations.CreateUserWebauthnCredentials do
  use Ecto.Migration

  def change do
    create table(:user_webauthn_credentials) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :credential_id, :binary, null: false
      add :public_key_cbor, :binary, null: false
      add :sign_count, :integer, default: 0, null: false
      add :label, :string
      add :last_used_at, :utc_datetime
      timestamps type: :utc_datetime
    end

    create index(:user_webauthn_credentials, [:user_id])
    create unique_index(:user_webauthn_credentials, [:credential_id])
  end
end
