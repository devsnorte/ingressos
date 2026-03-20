defmodule Pretex.Fees.FeeRule do
  use Ecto.Schema
  import Ecto.Changeset

  @fee_types ~w(service handling shipping cancellation custom)
  @apply_modes ~w(automatic manual)
  @value_types ~w(fixed percentage)

  schema "fee_rules" do
    field(:name, :string)
    field(:fee_type, :string, default: "service")
    field(:value_type, :string, default: "fixed")
    field(:value, :integer)
    field(:apply_mode, :string, default: "automatic")
    field(:description, :string)
    field(:active, :boolean, default: true)

    belongs_to(:event, Pretex.Events.Event)

    timestamps(type: :utc_datetime)
  end

  def fee_types, do: @fee_types
  def apply_modes, do: @apply_modes
  def value_types, do: @value_types

  def changeset(fee_rule, attrs) do
    fee_rule
    |> cast(attrs, [
      :name,
      :fee_type,
      :value_type,
      :value,
      :apply_mode,
      :description,
      :active,
      :event_id
    ])
    |> validate_required([:name, :fee_type, :value_type, :value, :apply_mode])
    |> validate_inclusion(:fee_type, @fee_types)
    |> validate_inclusion(:apply_mode, @apply_modes)
    |> validate_inclusion(:value_type, @value_types)
    |> validate_number(:value, greater_than_or_equal_to: 0, message: "must be zero or positive")
    |> validate_percentage_range()
  end

  defp validate_percentage_range(changeset) do
    case get_field(changeset, :value_type) do
      "percentage" ->
        validate_number(changeset, :value,
          less_than_or_equal_to: 10000,
          message: "percentage cannot exceed 100%"
        )

      _ ->
        changeset
    end
  end
end
