defmodule Pretex.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"

    create table(:organizations) do
      add :name, :string, null: false
      add :slug, :citext, null: false
      add :display_name, :string
      add :description, :text
      add :logo_url, :string
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:slug])
    create index(:organizations, [:is_active])
  end
end
