defmodule Pretex.Seating.SeatReservation do
  @moduledoc """
  Tracks seat reservation state for a specific event.

  A reservation moves through three states:
  - `held`      — temporarily reserved during checkout; expires at `held_until`
  - `confirmed` — permanently assigned to an order item after payment
  - `released`  — freed (cart expired, order cancelled, or manual release)

  The partial unique index on `[seat_id, event_id]` where `status != 'released'`
  enforces that only one active reservation exists per seat per event at any time.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(held confirmed released)

  @type t :: %__MODULE__{
          id: integer() | nil,
          status: String.t() | nil,
          held_until: DateTime.t() | nil,
          seat_id: integer() | nil,
          event_id: integer() | nil,
          order_item_id: integer() | nil,
          cart_session_id: integer() | nil,
          seat: Pretex.Seating.Seat.t() | Ecto.Association.NotLoaded.t(),
          event: Pretex.Events.Event.t() | Ecto.Association.NotLoaded.t(),
          order_item: Pretex.Orders.OrderItem.t() | nil | Ecto.Association.NotLoaded.t(),
          cart_session: Pretex.Orders.CartSession.t() | nil | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "seat_reservations" do
    field :status, :string, default: "held"
    field :held_until, :utc_datetime

    belongs_to :seat, Pretex.Seating.Seat
    belongs_to :event, Pretex.Events.Event
    belongs_to :order_item, Pretex.Orders.OrderItem
    belongs_to :cart_session, Pretex.Orders.CartSession

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a held reservation during checkout."
  @spec hold_changeset(t(), map()) :: Ecto.Changeset.t()
  def hold_changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:seat_id, :event_id, :cart_session_id, :held_until, :status])
    |> validate_required([:seat_id, :event_id, :cart_session_id, :held_until])
    |> put_change(:status, "held")
    |> unique_constraint([:seat_id, :event_id],
      name: :seat_reservations_seat_id_event_id_active_index,
      message: "assento já reservado para este evento"
    )
  end

  @doc "Changeset for confirming a reservation after order payment."
  @spec confirm_changeset(t(), map()) :: Ecto.Changeset.t()
  def confirm_changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:order_item_id])
    |> validate_required([:order_item_id])
    |> put_change(:status, "confirmed")
    |> put_change(:held_until, nil)
    |> put_change(:cart_session_id, nil)
  end

  @doc "Changeset for directly assigning a confirmed reservation (organizer manual assignment)."
  @spec assign_changeset(t(), map()) :: Ecto.Changeset.t()
  def assign_changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:seat_id, :event_id, :order_item_id])
    |> validate_required([:seat_id, :event_id, :order_item_id])
    |> put_change(:status, "confirmed")
    |> unique_constraint([:seat_id, :event_id],
      name: :seat_reservations_seat_id_event_id_active_index,
      message: "assento já reservado para este evento"
    )
  end

  @doc "Changeset for releasing a reservation (cart expired or order cancelled)."
  @spec release_changeset(t()) :: Ecto.Changeset.t()
  def release_changeset(reservation) do
    change(reservation, status: "released", held_until: nil)
  end

  @doc "Returns the list of valid reservation statuses."
  @spec statuses() :: [String.t()]
  def statuses, do: @statuses
end
