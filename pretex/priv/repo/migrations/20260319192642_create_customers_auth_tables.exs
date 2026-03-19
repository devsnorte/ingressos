defmodule Pretex.Repo.Migrations.CreateCustomersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:customers) do
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:customers, [:email])

    create table(:customers_tokens) do
      add :customer_id, references(:customers, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:customers_tokens, [:customer_id])
    create unique_index(:customers_tokens, [:context, :token])
  end
end
