defmodule Pretex.Repo.Migrations.CreateDeviceAssignmentsAndSync do
  use Ecto.Migration

  def change do
    create table(:device_assignments) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_assignments, [:device_id, :event_id])
    create index(:device_assignments, [:event_id])

    alter table(:check_ins) do
      add :device_id, references(:devices, on_delete: :nilify_all)
    end

    create index(:check_ins, [:device_id])
  end
end
