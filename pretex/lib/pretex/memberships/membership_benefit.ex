defmodule Pretex.Memberships.MembershipBenefit do
  use Ecto.Schema
  import Ecto.Changeset

  @benefit_types ~w(percentage_discount fixed_discount item_access)

  schema "membership_benefits" do
    field(:benefit_type, :string)
    field(:value, :integer)

    belongs_to(:membership_type, Pretex.Memberships.MembershipType)

    timestamps(type: :utc_datetime)
  end

  def benefit_types, do: @benefit_types

  def changeset(benefit, attrs) do
    benefit
    |> cast(attrs, [:benefit_type, :value, :membership_type_id])
    |> validate_required([:benefit_type])
    |> validate_inclusion(:benefit_type, @benefit_types)
    |> validate_discount_value()
  end

  defp validate_discount_value(changeset) do
    case get_field(changeset, :benefit_type) do
      "percentage_discount" ->
        changeset
        |> validate_required([:value])
        |> validate_number(:value, greater_than: 0, less_than_or_equal_to: 10_000)

      "fixed_discount" ->
        changeset
        |> validate_required([:value])
        |> validate_number(:value, greater_than: 0)

      "item_access" ->
        changeset

      _ ->
        changeset
    end
  end
end
