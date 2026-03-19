defmodule Pretex.Repo.Migrations.CreateSubEvents do
  use Ecto.Migration

  def change do
    create table(:sub_events) do
      add(:parent_event_id, references(:events, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:slug, :string, null: false)
      add(:description, :string)
      add(:starts_at, :utc_datetime)
      add(:ends_at, :utc_datetime)
      add(:venue, :string)
      add(:status, :string, default: "draft", null: false)
      add(:capacity, :integer)

      timestamps(type: :utc_datetime)
    end

    create(index(:sub_events, [:parent_event_id]))
    create(unique_index(:sub_events, [:parent_event_id, :slug]))
  end
end
