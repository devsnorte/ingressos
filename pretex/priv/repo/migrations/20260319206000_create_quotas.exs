defmodule Pretex.Repo.Migrations.CreateQuotas do
  use Ecto.Migration

  def change do
    create table(:quotas) do
      add(:event_id, references(:events, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:capacity, :integer, null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:quotas, [:event_id]))
  end
end
