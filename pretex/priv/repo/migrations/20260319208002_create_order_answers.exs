defmodule Pretex.Repo.Migrations.CreateOrderAnswers do
  use Ecto.Migration

  def change do
    create table(:order_answers) do
      add(:order_item_id, references(:order_items, on_delete: :delete_all), null: false)
      add(:question_id, references(:questions, on_delete: :restrict), null: false)
      add(:answer, :text)
      timestamps(type: :utc_datetime)
    end

    create(index(:order_answers, [:order_item_id]))
  end
end
