defmodule Pretex.Catalog.QuestionOption do
  use Ecto.Schema
  import Ecto.Changeset

  schema "question_options" do
    field(:label, :string)
    field(:position, :integer, default: 0)

    belongs_to(:question, Pretex.Catalog.Question)

    timestamps(type: :utc_datetime)
  end

  def changeset(option, attrs) do
    option
    |> cast(attrs, [:label, :position])
    |> validate_required([:label])
    |> validate_length(:label, min: 1, max: 255)
  end
end
