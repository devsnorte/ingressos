defmodule Pretex.Repo.Migrations.CreateOrganizationPermissions do
  use Ecto.Migration

  def change do
    create table(:organization_permissions) do
      add :membership_id, references(:memberships, on_delete: :delete_all), null: false
      add :resource, :string, null: false
      add :can_read, :boolean, default: true, null: false
      add :can_write, :boolean, default: false, null: false
      add :event_id, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:organization_permissions, [:membership_id])

    create unique_index(:organization_permissions, [:membership_id, :resource, :event_id],
             name: :organization_permissions_membership_resource_event_index
           )
  end
end
