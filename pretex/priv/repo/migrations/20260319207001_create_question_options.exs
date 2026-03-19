defmodule Pretex.Repo.Migrations.CreateQuestionOptions do
  use Ecto.Migration

  def change do
    create table(:question_options) do
      add(:question_id, references(:questions, on_delete: :delete_all), null: false)
      add(:label, :string, null: false)
      add(:position, :integer, default: 0)
      timestamps(type: :utc_datetime)
    end

    create(index(:question_options, [:question_id]))
  end
end
