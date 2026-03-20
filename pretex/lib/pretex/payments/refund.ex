defmodule Pretex.Payments.Refund do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending processing completed failed)

  schema "refunds" do
    field(:payment_id, :integer)
    field(:order_id, :integer)
    field(:amount_cents, :integer)
    field(:status, :string, default: "pending")
    field(:provider_ref, :string)
    field(:reason, :string)
    field(:initiated_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def creation_changeset(refund, attrs) do
    refund
    |> cast(attrs, [:payment_id, :order_id, :amount_cents, :reason])
    |> validate_required([:payment_id, :order_id, :amount_cents])
    |> validate_number(:amount_cents, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
    |> put_change(:status, "pending")
    |> put_change(:initiated_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def status_changeset(refund, attrs) do
    refund
    |> cast(attrs, [:status, :provider_ref, :completed_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
  end
end
