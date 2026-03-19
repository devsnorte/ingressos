defmodule Pretex.Repo.Migrations.CreateAttendeeFieldConfigs do
  use Ecto.Migration

  def change do
    create table(:attendee_field_configs) do
      add(:event_id, references(:events, on_delete: :delete_all), null: false)
      add(:field_name, :string, null: false)
      add(:is_enabled, :boolean, default: true, null: false)
      add(:is_required, :boolean, default: false, null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:attendee_field_configs, [:event_id]))
    create(unique_index(:attendee_field_configs, [:event_id, :field_name]))
  end
end
