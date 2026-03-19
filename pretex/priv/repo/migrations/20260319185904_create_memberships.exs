defmodule Pretex.Repo.Migrations.CreateMemberships do
  use Ecto.Migration

  def change do
    create table(:memberships) do
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:role, :string, null: false)
      add(:is_active, :boolean, default: true, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:memberships, [:organization_id]))
    create(index(:memberships, [:user_id]))
    create(unique_index(:memberships, [:organization_id, :user_id]))
  end
end
