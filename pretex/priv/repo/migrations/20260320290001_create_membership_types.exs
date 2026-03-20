defmodule Pretex.Repo.Migrations.CreateMembershipTypes do
  use Ecto.Migration

  def change do
    create table(:membership_types) do
      add(:name, :string, null: false)
      add(:description, :string)
      add(:validity_days, :integer, null: false)
      add(:active, :boolean, null: false, default: true)
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:membership_types, [:organization_id]))
    create(index(:membership_types, [:organization_id, :active]))
  end
end
