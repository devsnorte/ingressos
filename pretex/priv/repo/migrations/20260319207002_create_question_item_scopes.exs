defmodule Pretex.Repo.Migrations.CreateQuestionItemScopes do
  use Ecto.Migration

  def change do
    create table(:question_item_scopes) do
      add(:question_id, references(:questions, on_delete: :delete_all), null: false)
      add(:item_id, references(:items, on_delete: :delete_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:question_item_scopes, [:question_id, :item_id]))
  end
end
