defmodule Pretex.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :venue, :string
      add :status, :string, default: "draft", null: false
      add :logo_url, :string
      add :banner_url, :string
      add :primary_color, :string, default: "#6366f1"
      add :accent_color, :string, default: "#f43f5e"
      timestamps type: :utc_datetime
    end

    create index(:events, [:organization_id])
    create index(:events, [:status])
    create unique_index(:events, [:organization_id, :slug])
  end
end
