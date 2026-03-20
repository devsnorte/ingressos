defmodule Pretex.Repo.Migrations.CreateMembershipBenefits do
  use Ecto.Migration

  def change do
    create table(:membership_benefits) do
      add(:benefit_type, :string, null: false)
      add(:value, :integer)
      add(:membership_type_id, references(:membership_types, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:membership_benefits, [:membership_type_id]))
  end
end
