defmodule Pretex.Repo.Migrations.CreateQuestions do
  use Ecto.Migration

  def change do
    create table(:questions) do
      add(:event_id, references(:events, on_delete: :delete_all), null: false)
      add(:label, :string, null: false)
      add(:question_type, :string, null: false)
      add(:is_required, :boolean, default: false, null: false)
      add(:position, :integer, default: 0)
      timestamps(type: :utc_datetime)
    end

    create(index(:questions, [:event_id]))
  end
end
