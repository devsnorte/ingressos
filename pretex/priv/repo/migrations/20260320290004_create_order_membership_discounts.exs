defmodule Pretex.Repo.Migrations.CreateOrderMembershipDiscounts do
  use Ecto.Migration

  def change do
    create table(:order_membership_discounts) do
      add(:name, :string, null: false)
      add(:discount_cents, :integer, null: false, default: 0)
      add(:value_type, :string, null: false)
      add(:value, :integer, null: false)
      add(:order_id, references(:orders, on_delete: :delete_all), null: false)
      add(:membership_id, references(:customer_memberships, on_delete: :restrict), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:order_membership_discounts, [:order_id]))
    create(index(:order_membership_discounts, [:membership_id]))
  end
end
