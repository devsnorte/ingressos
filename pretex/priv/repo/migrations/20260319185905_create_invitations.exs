defmodule Pretex.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    create table(:invitations) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :invited_by_id, references(:users, on_delete: :delete_all), null: false
      add :email, :citext, null: false
      add :role, :string, null: false
      add :token, :string, null: false
      add :accepted_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:invitations, [:organization_id])
    create index(:invitations, [:invited_by_id])
    create unique_index(:invitations, [:token])

    create unique_index(:invitations, [:organization_id, :email],
             where: "accepted_at IS NULL",
             name: :invitations_organization_id_email_pending_index
           )
  end
end
