defmodule Pretex.CheckIns.CheckIn do
  use Ecto.Schema
  import Ecto.Changeset

  schema "check_ins" do
    field(:checked_in_at, :utc_datetime_usec)
    field(:annulled_at, :utc_datetime_usec)

    belongs_to(:order_item, Pretex.Orders.OrderItem)
    belongs_to(:event, Pretex.Events.Event)
    belongs_to(:checked_in_by, Pretex.Accounts.User, foreign_key: :checked_in_by_id)
    belongs_to(:annulled_by, Pretex.Accounts.User, foreign_key: :annulled_by_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(check_in, attrs) do
    check_in
    |> cast(attrs, [:checked_in_at, :annulled_at])
    |> validate_required([:checked_in_at])
  end
end
