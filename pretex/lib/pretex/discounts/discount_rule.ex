defmodule Pretex.Discounts.DiscountRule do
  use Ecto.Schema
  import Ecto.Changeset

  @condition_types ~w(min_quantity item_combo)
  @value_types ~w(fixed percentage)

  schema "discount_rules" do
    field(:name, :string)
    field(:condition_type, :string, default: "min_quantity")
    field(:min_quantity, :integer, default: 1)
    field(:value_type, :string, default: "percentage")
    field(:value, :integer, default: 0)
    field(:active, :boolean, default: true)
    field(:description, :string)

    belongs_to(:event, Pretex.Events.Event)
    has_many(:scoped_items, Pretex.Discounts.DiscountRuleItem)

    timestamps(type: :utc_datetime)
  end

  def condition_types, do: @condition_types
  def value_types, do: @value_types

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :name,
      :condition_type,
      :min_quantity,
      :value_type,
      :value,
      :active,
      :description,
      :event_id
    ])
    |> validate_required([:name, :condition_type, :value_type, :value])
    |> validate_inclusion(:condition_type, @condition_types)
    |> validate_inclusion(:value_type, @value_types)
    |> validate_number(:value, greater_than_or_equal_to: 0)
    |> validate_number(:min_quantity, greater_than_or_equal_to: 1)
    |> validate_length(:name, min: 2, max: 255)
    |> validate_percentage_max()
  end

  defp validate_percentage_max(changeset) do
    if get_field(changeset, :value_type) == "percentage" do
      validate_number(changeset, :value,
        less_than_or_equal_to: 10_000,
        message: "não pode exceder 100%"
      )
    else
      changeset
    end
  end
end
