defmodule Pretex.Repo.Migrations.CreateMemberships do
  use Ecto.Migration

  def change do
    create table(:customer_memberships) do
      add(:starts_at, :utc_datetime, null: false)
      add(:expires_at, :utc_datetime, null: false)
      add(:status, :string, null: false, default: "active")
      add(:membership_type_id, references(:membership_types, on_delete: :restrict), null: false)
      add(:customer_id, references(:customers, on_delete: :delete_all), null: false)
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:source_order_id, references(:orders, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:customer_memberships, [:customer_id]))
    create(index(:customer_memberships, [:organization_id]))
    create(index(:customer_memberships, [:membership_type_id]))
    create(index(:customer_memberships, [:customer_id, :organization_id, :status]))
  end
end
