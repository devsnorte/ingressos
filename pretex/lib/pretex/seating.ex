defmodule Pretex.Seating do
  @moduledoc """
  Context for managing venue seating plans, sections, seats, and reservations.

  ## Seating Plan Lifecycle

  1. Organizer uploads a JSON layout via `create_seating_plan/2`.
  2. `parse_layout/1` validates the JSON structure and returns a list of section
     maps, each containing a list of seat maps ready for bulk insertion.
  3. The plan is assigned to an event via `assign_plan_to_event/2`.
  4. Sections are mapped to catalog items via `map_section_to_item/3`.

  ## Seat Reservation Lifecycle

  During checkout: `hold_seat/3` creates a temporary held reservation linked to
  the cart session. On cart expiry: `release_seat/2` frees the seat. On order
  confirmation: `confirm_seat/3` upgrades the reservation to confirmed and links
  it to the order item.

  ## Concurrency

  Concurrent hold attempts on the same seat are safely rejected by the partial
  unique database index on `[seat_id, event_id]` where `status != 'released'`.
  The caller receives `{:error, :already_reserved}` in that case.
  """

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Seating.Seat
  alias Pretex.Seating.SeatingPlan
  alias Pretex.Seating.SeatingSection
  alias Pretex.Seating.SeatReservation
  alias Pretex.Events.Event

  # ---------------------------------------------------------------------------
  # Seating Plans
  # ---------------------------------------------------------------------------

  @doc """
  Returns all seating plans belonging to an organization, ordered by name.
  """
  @spec list_seating_plans(integer()) :: [SeatingPlan.t()]
  def list_seating_plans(org_id) do
    SeatingPlan
    |> where([p], p.organization_id == ^org_id)
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  @doc """
  Fetches a seating plan by id, raising if not found.
  Preloads sections and their seats.
  """
  @spec get_seating_plan!(integer()) :: SeatingPlan.t()
  def get_seating_plan!(id) do
    SeatingPlan
    |> preload(sections: [:seats, :item, :item_variation])
    |> Repo.get!(id)
  end

  @doc """
  Creates a seating plan for an organization by parsing the given JSON layout.

  The `layout` key in `attrs` must be a map conforming to the expected JSON
  structure (see `parse_layout/1`). Sections and seats are inserted within a
  single database transaction.

  Returns `{:ok, seating_plan}` on success, or `{:error, reason}` where reason
  is either an `Ecto.Changeset` or `:invalid_layout`.
  """
  @spec create_seating_plan(integer(), map()) ::
          {:ok, SeatingPlan.t()} | {:error, Ecto.Changeset.t() | :invalid_layout}
  def create_seating_plan(org_id, attrs) do
    layout = Map.get(attrs, :layout, Map.get(attrs, "layout"))

    with {:ok, sections_data} <- parse_layout(layout) do
      Repo.transaction(fn ->
        plan_attrs = Map.put(attrs, :organization_id, org_id)

        plan =
          case %SeatingPlan{}
               |> SeatingPlan.changeset(plan_attrs)
               |> Repo.insert() do
            {:ok, p} -> p
            {:error, cs} -> Repo.rollback(cs)
          end

        Enum.each(sections_data, fn section_data ->
          {seats_data, section_attrs} = Map.pop!(section_data, :seats)

          section =
            %SeatingSection{}
            |> SeatingSection.changeset(Map.put(section_attrs, :seating_plan_id, plan.id))
            |> Repo.insert!()

          now = DateTime.utc_now() |> DateTime.truncate(:second)

          seat_rows =
            Enum.map(seats_data, fn seat ->
              seat
              |> Map.put(:seating_section_id, section.id)
              |> Map.put(:inserted_at, now)
              |> Map.put(:updated_at, now)
            end)

          Repo.insert_all(Seat, seat_rows)
        end)

        get_seating_plan!(plan.id)
      end)
    end
  end

  @doc """
  Updates an existing seating plan's name.
  """
  @spec update_seating_plan(SeatingPlan.t(), map()) ::
          {:ok, SeatingPlan.t()} | {:error, Ecto.Changeset.t()}
  def update_seating_plan(%SeatingPlan{} = plan, attrs) do
    plan
    |> SeatingPlan.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a seating plan. Cascades to sections and seats via DB constraints.
  """
  @spec delete_seating_plan(SeatingPlan.t()) ::
          {:ok, SeatingPlan.t()} | {:error, Ecto.Changeset.t()}
  def delete_seating_plan(%SeatingPlan{} = plan) do
    Repo.delete(plan)
  end

  @doc """
  Returns a changeset for a seating plan without persisting it.
  """
  @spec change_seating_plan(SeatingPlan.t(), map()) :: Ecto.Changeset.t()
  def change_seating_plan(%SeatingPlan{} = plan, attrs \\ %{}) do
    SeatingPlan.changeset(plan, attrs)
  end

  # ---------------------------------------------------------------------------
  # Layout Parsing
  # ---------------------------------------------------------------------------

  @doc """
  Parses a JSON layout map into a list of section data maps, each containing
  pre-built seat maps ready for insertion.

  Expected input structure:

      %{
        "sections" => [
          %{
            "name" => "Orchestra",
            "rows" => [
              %{"label" => "A", "seats" => 20},
              %{"label" => "B", "seats" => 20}
            ]
          }
        ]
      }

  Returns `{:ok, sections}` where each section map has the shape:

      %{name: "Orchestra", capacity: 40, row_count: 2, seats: [...]}

  Returns `{:error, :invalid_layout}` when the structure is missing required
  keys or contains invalid values.
  """
  @spec parse_layout(map() | nil) :: {:ok, [map()]} | {:error, :invalid_layout}
  def parse_layout(nil), do: {:error, :invalid_layout}

  def parse_layout(%{"sections" => sections}) when is_list(sections) and sections != [] do
    sections
    |> Enum.reduce_while({:ok, []}, fn section, {:ok, acc} ->
      case parse_section(section) do
        {:ok, parsed} -> {:cont, {:ok, acc ++ [parsed]}}
        :error -> {:halt, {:error, :invalid_layout}}
      end
    end)
  end

  def parse_layout(_), do: {:error, :invalid_layout}

  defp parse_section(%{"name" => name, "rows" => rows})
       when is_binary(name) and name != "" and is_list(rows) and rows != [] do
    rows
    |> Enum.reduce_while({:ok, []}, fn row, {:ok, acc} ->
      case parse_row(row) do
        {:ok, seats} -> {:cont, {:ok, acc ++ seats}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, seats} ->
        {:ok,
         %{
           name: name,
           row_count: length(rows),
           capacity: length(seats),
           seats: seats
         }}

      :error ->
        :error
    end
  end

  defp parse_section(_), do: :error

  defp parse_row(%{"label" => label, "seats" => count})
       when is_binary(label) and label != "" and is_integer(count) and count > 0 do
    seats =
      Enum.map(1..count, fn n ->
        %{
          label: "#{label}-#{n}",
          row: label,
          number: n,
          status: "available"
        }
      end)

    {:ok, seats}
  end

  defp parse_row(_), do: :error

  # ---------------------------------------------------------------------------
  # Plan–Event Assignment
  # ---------------------------------------------------------------------------

  @doc """
  Assigns a seating plan to an event by setting the `seating_plan_id` foreign key.
  """
  @spec assign_plan_to_event(integer(), integer()) ::
          {:ok, Event.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def assign_plan_to_event(event_id, plan_id) do
    case Repo.get(Event, event_id) do
      nil ->
        {:error, :not_found}

      event ->
        event
        |> Ecto.Changeset.change(seating_plan_id: plan_id)
        |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # Section–Item Mapping
  # ---------------------------------------------------------------------------

  @doc """
  Maps a seating section to a catalog item and optional item variation.
  Pass `nil` for `variation_id` to clear the variation mapping.
  """
  @spec map_section_to_item(integer(), integer(), integer() | nil) ::
          {:ok, SeatingSection.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def map_section_to_item(section_id, item_id, variation_id \\ nil) do
    case Repo.get(SeatingSection, section_id) do
      nil ->
        {:error, :not_found}

      section ->
        section
        |> SeatingSection.mapping_changeset(%{item_id: item_id, item_variation_id: variation_id})
        |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # Seat Availability
  # ---------------------------------------------------------------------------

  @doc """
  Returns all seats in a section that are available for a given event —
  i.e. not blocked and without an active (held or confirmed) reservation.
  """
  @spec available_seats(integer(), integer()) :: [Seat.t()]
  def available_seats(event_id, section_id) do
    active_seat_ids =
      SeatReservation
      |> where([r], r.event_id == ^event_id and r.status != "released")
      |> select([r], r.seat_id)

    Seat
    |> where([s], s.seating_section_id == ^section_id)
    |> where([s], s.status == "available")
    |> where([s], s.id not in subquery(active_seat_ids))
    |> order_by([s], asc: s.row, asc: s.number)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Seat Reservation Operations
  # ---------------------------------------------------------------------------

  @doc """
  Temporarily holds a seat for a cart session during checkout.

  The hold expires at `held_until`. Returns `{:error, :already_reserved}` if
  the seat already has an active (held or confirmed) reservation for the event.
  """
  @spec hold_seat(integer(), integer(), integer()) ::
          {:ok, SeatReservation.t()} | {:error, :already_reserved | Ecto.Changeset.t()}
  def hold_seat(seat_id, event_id, cart_session_id) do
    held_until = DateTime.add(DateTime.utc_now(), 15 * 60, :second) |> DateTime.truncate(:second)

    %SeatReservation{}
    |> SeatReservation.hold_changeset(%{
      seat_id: seat_id,
      event_id: event_id,
      cart_session_id: cart_session_id,
      held_until: held_until
    })
    |> Repo.insert()
    |> case do
      {:ok, reservation} -> {:ok, reservation}
      {:error, changeset} -> handle_reservation_conflict(changeset)
    end
  end

  @doc """
  Upgrades a held reservation to confirmed, linking it to an order item.

  Returns `{:error, :not_found}` if no active reservation exists for the seat
  and event combination.
  """
  @spec confirm_seat(integer(), integer(), integer()) ::
          {:ok, SeatReservation.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def confirm_seat(seat_id, event_id, order_item_id) do
    case get_active_reservation(seat_id, event_id) do
      nil ->
        {:error, :not_found}

      reservation ->
        reservation
        |> SeatReservation.confirm_changeset(%{order_item_id: order_item_id})
        |> Repo.update()
    end
  end

  @doc """
  Releases a held or confirmed reservation, making the seat available again.

  Returns `{:error, :not_found}` if no active reservation exists.
  """
  @spec release_seat(integer(), integer()) ::
          {:ok, SeatReservation.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def release_seat(seat_id, event_id) do
    case get_active_reservation(seat_id, event_id) do
      nil -> {:error, :not_found}
      reservation -> reservation |> SeatReservation.release_changeset() |> Repo.update()
    end
  end

  @doc """
  Manually assigns a seat to an order item, bypassing the cart hold flow.
  Used by organizers for manual seat assignment.

  Returns `{:error, :already_reserved}` if the seat is already taken.
  """
  @spec assign_seat(integer(), integer(), integer()) ::
          {:ok, SeatReservation.t()} | {:error, :already_reserved | Ecto.Changeset.t()}
  def assign_seat(seat_id, event_id, order_item_id) do
    %SeatReservation{}
    |> SeatReservation.assign_changeset(%{
      seat_id: seat_id,
      event_id: event_id,
      order_item_id: order_item_id
    })
    |> Repo.insert()
    |> case do
      {:ok, reservation} -> {:ok, reservation}
      {:error, changeset} -> handle_reservation_conflict(changeset)
    end
  end

  @doc """
  Reassigns a seat from one seat to another for an existing order item.

  If the attendee for the order item has already checked in, the function
  still performs the reassignment but returns `{:ok, reservation, :checked_in_warning}`
  to alert the caller.

  Returns `{:error, :not_found}` if the old seat has no active reservation for
  the event, or `{:error, :already_reserved}` if the new seat is taken.
  """
  @spec reassign_seat(integer(), integer(), integer(), integer()) ::
          {:ok, SeatReservation.t()}
          | {:ok, SeatReservation.t(), :checked_in_warning}
          | {:error, :not_found | :already_reserved | Ecto.Changeset.t()}
  def reassign_seat(old_seat_id, new_seat_id, event_id, order_item_id) do
    with {:old, reservation} when not is_nil(reservation) <-
           {:old, get_active_reservation(old_seat_id, event_id)},
         {:new_free} <- check_seat_free(new_seat_id, event_id) do
      checked_in? = has_check_in?(reservation.order_item_id)

      Repo.transaction(fn ->
        reservation |> SeatReservation.release_changeset() |> Repo.update!()

        new_reservation =
          %SeatReservation{}
          |> Ecto.Changeset.change(%{
            seat_id: new_seat_id,
            event_id: event_id,
            order_item_id: order_item_id,
            status: "confirmed"
          })
          |> Repo.insert!()

        {new_reservation, checked_in?}
      end)
      |> case do
        {:ok, {reservation, true}} -> {:ok, reservation, :checked_in_warning}
        {:ok, {reservation, false}} -> {:ok, reservation}
        {:error, reason} -> {:error, reason}
      end
    else
      {:old, nil} -> {:error, :not_found}
      {:new_taken} -> {:error, :already_reserved}
    end
  end

  @doc """
  Releases all held reservations whose `held_until` timestamp is in the past.

  Intended to be called periodically (e.g. via an Oban worker or scheduled task).
  Returns the count of reservations released.
  """
  @spec release_expired_holds() :: {integer(), nil}
  def release_expired_holds do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    SeatReservation
    |> where([r], r.status == "held" and r.held_until < ^now)
    |> Repo.update_all(set: [status: "released", held_until: nil])
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp get_active_reservation(seat_id, event_id) do
    SeatReservation
    |> where([r], r.seat_id == ^seat_id and r.event_id == ^event_id and r.status != "released")
    |> Repo.one()
  end

  defp check_seat_free(seat_id, event_id) do
    case get_active_reservation(seat_id, event_id) do
      nil -> {:new_free}
      _reservation -> {:new_taken}
    end
  end

  defp has_check_in?(nil), do: false

  defp has_check_in?(order_item_id) do
    Repo.exists?(
      from c in "check_ins",
        where: c.order_item_id == ^order_item_id and is_nil(c.annulled_at)
    )
  end

  defp handle_reservation_conflict(%Ecto.Changeset{} = changeset) do
    if unique_constraint_error?(changeset, :seat_id) do
      {:error, :already_reserved}
    else
      {:error, changeset}
    end
  end

  defp unique_constraint_error?(%Ecto.Changeset{errors: errors}, field) do
    Enum.any?(errors, fn
      {^field, {_msg, opts}} -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end)
  end
end
