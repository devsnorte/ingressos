defmodule Pretex.Repo.Migrations.CreateFeeRules do
  use Ecto.Migration

  def change do
    create table(:fee_rules) do
      add(:name, :string, null: false)
      add(:fee_type, :string, null: false, default: "service")
      add(:value_type, :string, null: false, default: "fixed")
      add(:value, :integer, null: false, default: 0)
      add(:apply_mode, :string, null: false, default: "automatic")
      add(:description, :string)
      add(:active, :boolean, null: false, default: true)
      add(:event_id, references(:events, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:fee_rules, [:event_id]))
    create(index(:fee_rules, [:event_id, :apply_mode]))
    create(index(:fee_rules, [:event_id, :active]))
  end
end
