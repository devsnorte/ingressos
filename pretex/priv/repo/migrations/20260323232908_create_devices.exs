defmodule Pretex.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:device_init_tokens) do
      add :token_hash, :string, null: false
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :restrict), null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_init_tokens, [:token_hash])
    create index(:device_init_tokens, [:organization_id])

    create table(:devices) do
      add :name, :string, null: false
      add :api_token_hash, :string, null: false
      add :status, :string, null: false, default: "active"
      add :last_seen_at, :utc_datetime
      add :provisioned_at, :utc_datetime, null: false
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :provisioned_by_id, references(:users, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:devices, [:api_token_hash])
    create index(:devices, [:organization_id])
  end
end
