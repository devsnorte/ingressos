defmodule Pretex.Catalog.Question do
  use Ecto.Schema
  import Ecto.Changeset

  @question_types ~w(text multiline number yes_no single_choice multiple_choice file_upload date time phone country)

  schema "questions" do
    field(:label, :string)
    field(:question_type, :string)
    field(:is_required, :boolean, default: false)
    field(:position, :integer, default: 0)

    belongs_to(:event, Pretex.Events.Event)
    has_many(:options, Pretex.Catalog.QuestionOption, foreign_key: :question_id)
    many_to_many(:scoped_items, Pretex.Catalog.Item, join_through: "question_item_scopes")

    timestamps(type: :utc_datetime)
  end

  def question_types, do: @question_types

  def changeset(question, attrs) do
    question
    |> cast(attrs, [:label, :question_type, :is_required, :position])
    |> validate_required([:label, :question_type])
    |> validate_length(:label, min: 2, max: 255)
    |> validate_inclusion(:question_type, @question_types)
  end
end
