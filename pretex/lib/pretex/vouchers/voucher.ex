defmodule Pretex.Vouchers.Voucher do
  use Ecto.Schema
  import Ecto.Changeset

  @effects ~w(fixed_discount percentage_discount custom_price reveal grant_access)

  schema "vouchers" do
    field(:code, :string)
    field(:effect, :string, default: "fixed_discount")
    field(:value, :integer, default: 0)
    field(:max_uses, :integer)
    field(:max_uses_per_code, :integer, default: 1)
    field(:used_count, :integer, default: 0)
    field(:valid_until, :utc_datetime)
    field(:active, :boolean, default: true)
    field(:tag, :string)

    belongs_to(:event, Pretex.Events.Event)
    has_many(:scoped_items, Pretex.Vouchers.VoucherItem)
    has_many(:redemptions, Pretex.Vouchers.VoucherRedemption)

    timestamps(type: :utc_datetime)
  end

  def effects, do: @effects

  def changeset(voucher, attrs) do
    voucher
    |> cast(attrs, [
      :code,
      :effect,
      :value,
      :max_uses,
      :max_uses_per_code,
      :valid_until,
      :active,
      :tag,
      :event_id
    ])
    |> validate_required([:code, :effect])
    |> validate_inclusion(:effect, @effects)
    |> validate_number(:value, greater_than_or_equal_to: 0)
    |> validate_length(:code, min: 1, max: 64)
    |> update_change(:code, &String.upcase(String.trim(&1)))
    |> unique_constraint(:code, name: :vouchers_event_id_code_index)
  end
end
