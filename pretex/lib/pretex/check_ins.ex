defmodule Pretex.CheckIns do
  @moduledoc "Manages event check-in operations."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.CheckIns.CheckIn
  alias Pretex.CheckIns.{CheckInList, CheckInListItem, Gate, GateCheckInList}
  alias Pretex.Orders.{Order, OrderItem}

  def checkin_topic(event_id), do: "checkins:event:#{event_id}"

  def check_in_by_ticket_code(event_id, ticket_code, operator_id) do
    order_item =
      OrderItem
      |> join(:inner, [oi], o in Order, on: oi.order_id == o.id)
      |> where([oi, _o], oi.ticket_code == ^ticket_code)
      |> preload([oi, o], order: o)
      |> Repo.one()

    case order_item do
      nil ->
        {:error, :invalid_ticket}

      %{order: %{event_id: ^event_id}} = oi ->
        validate_and_check_in(oi, event_id, operator_id)

      _wrong_event ->
        {:error, :wrong_event}
    end
  end

  defp validate_and_check_in(%{order: %{status: status}}, _event_id, _operator_id)
       when status != "confirmed" do
    {:error, :ticket_cancelled}
  end

  defp validate_and_check_in(order_item, event_id, operator_id) do
    existing =
      CheckIn
      |> where(
        [c],
        c.order_item_id == ^order_item.id and c.event_id == ^event_id and is_nil(c.annulled_at)
      )
      |> Repo.one()

    case existing do
      nil ->
        insert_check_in(order_item.id, event_id, operator_id)

      _already ->
        {:error, :already_checked_in}
    end
  end

  defp insert_check_in(order_item_id, event_id, operator_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    result =
      %CheckIn{}
      |> CheckIn.changeset(%{checked_in_at: now})
      |> Ecto.Changeset.put_change(:order_item_id, order_item_id)
      |> Ecto.Changeset.put_change(:event_id, event_id)
      |> Ecto.Changeset.put_change(:checked_in_by_id, operator_id)
      |> Repo.insert()

    case result do
      {:ok, check_in} ->
        broadcast_check_in_update(event_id)
        {:ok, check_in}

      {:error, changeset} ->
        if has_unique_constraint_error?(changeset) do
          {:error, :already_checked_in}
        else
          {:error, changeset}
        end
    end
  end

  defp has_unique_constraint_error?(changeset) do
    Enum.any?(changeset.errors, fn
      {_field, {_msg, opts}} when is_list(opts) -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end)
  end

  def annul_check_in(check_in_id, operator_id) do
    check_in = Repo.get!(CheckIn, check_in_id)

    if check_in.annulled_at do
      {:error, :already_annulled}
    else
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      result =
        check_in
        |> Ecto.Changeset.change(annulled_at: now, annulled_by_id: operator_id)
        |> Repo.update()

      case result do
        {:ok, annulled} ->
          broadcast_check_in_update(annulled.event_id)
          {:ok, annulled}

        error ->
          error
      end
    end
  end

  def search_attendees(event_id, query) do
    term = "%#{query}%"

    OrderItem
    |> join(:inner, [oi], o in Order, on: oi.order_id == o.id)
    |> where([oi, o], o.event_id == ^event_id and o.status == "confirmed")
    |> where(
      [oi, o],
      ilike(oi.attendee_name, ^term) or ilike(oi.attendee_email, ^term) or
        ilike(o.name, ^term) or ilike(o.email, ^term)
    )
    |> preload([oi, o], order: o, item: [])
    |> Repo.all()
  end

  def get_check_in_count(event_id) do
    CheckIn
    |> where([c], c.event_id == ^event_id and is_nil(c.annulled_at))
    |> Repo.aggregate(:count)
  end

  def get_total_tickets(event_id) do
    OrderItem
    |> join(:inner, [oi], o in Order, on: oi.order_id == o.id)
    |> where([oi, o], o.event_id == ^event_id and o.status == "confirmed")
    |> Repo.aggregate(:sum, :quantity) || 0
  end

  def get_active_check_in(order_item_id, event_id) do
    CheckIn
    |> where(
      [c],
      c.order_item_id == ^order_item_id and c.event_id == ^event_id and is_nil(c.annulled_at)
    )
    |> Repo.one()
  end

  # ---------------------------------------------------------------------------
  # Check-in Lists CRUD
  # ---------------------------------------------------------------------------

  def create_check_in_list(event_id, attrs) do
    item_ids = Map.get(attrs, :item_ids) || Map.get(attrs, "item_ids") || []

    if item_ids == [] do
      {:error, :no_items}
    else
      Repo.transaction(fn ->
        changeset =
          %CheckInList{}
          |> CheckInList.changeset(attrs)
          |> Ecto.Changeset.put_change(:event_id, event_id)

        list =
          case Repo.insert(changeset) do
            {:ok, l} -> l
            {:error, cs} -> Repo.rollback(cs)
          end

        Enum.each(item_ids, fn item_id ->
          %CheckInListItem{}
          |> Ecto.Changeset.change(%{check_in_list_id: list.id, item_id: item_id})
          |> Repo.insert!()
        end)

        list
      end)
    end
  end

  def update_check_in_list(list_id, attrs) do
    list = Repo.get!(CheckInList, list_id)
    item_ids = Map.get(attrs, :item_ids) || Map.get(attrs, "item_ids")

    Repo.transaction(fn ->
      updated =
        case list |> CheckInList.changeset(attrs) |> Repo.update() do
          {:ok, l} -> l
          {:error, cs} -> Repo.rollback(cs)
        end

      if item_ids do
        CheckInListItem
        |> where([cli], cli.check_in_list_id == ^list.id)
        |> Repo.delete_all()

        Enum.each(item_ids, fn item_id ->
          %CheckInListItem{}
          |> Ecto.Changeset.change(%{check_in_list_id: list.id, item_id: item_id})
          |> Repo.insert!()
        end)
      end

      updated
    end)
  end

  def delete_check_in_list(list_id) do
    list = Repo.get!(CheckInList, list_id)
    Repo.delete(list)
  end

  def list_check_in_lists(event_id) do
    CheckInList
    |> where([l], l.event_id == ^event_id)
    |> preload(:check_in_list_items)
    |> order_by([l], asc: l.name)
    |> Repo.all()
  end

  def get_check_in_list!(id) do
    CheckInList
    |> preload(:check_in_list_items)
    |> Repo.get!(id)
  end

  # ---------------------------------------------------------------------------
  # Gates CRUD
  # ---------------------------------------------------------------------------

  def create_gate(event_id, attrs) do
    list_ids = Map.get(attrs, :check_in_list_ids) || Map.get(attrs, "check_in_list_ids") || []

    if list_ids == [] do
      {:error, :no_check_in_lists}
    else
      Repo.transaction(fn ->
        changeset =
          %Gate{}
          |> Gate.changeset(attrs)
          |> Ecto.Changeset.put_change(:event_id, event_id)

        gate =
          case Repo.insert(changeset) do
            {:ok, g} -> g
            {:error, cs} -> Repo.rollback(cs)
          end

        Enum.each(list_ids, fn list_id ->
          %GateCheckInList{}
          |> Ecto.Changeset.change(%{gate_id: gate.id, check_in_list_id: list_id})
          |> Repo.insert!()
        end)

        gate
      end)
    end
  end

  def update_gate(gate_id, attrs) do
    gate = Repo.get!(Gate, gate_id)
    list_ids = Map.get(attrs, :check_in_list_ids) || Map.get(attrs, "check_in_list_ids")

    Repo.transaction(fn ->
      updated =
        case gate |> Gate.changeset(attrs) |> Repo.update() do
          {:ok, g} -> g
          {:error, cs} -> Repo.rollback(cs)
        end

      if list_ids do
        GateCheckInList
        |> where([gcl], gcl.gate_id == ^gate.id)
        |> Repo.delete_all()

        Enum.each(list_ids, fn list_id ->
          %GateCheckInList{}
          |> Ecto.Changeset.change(%{gate_id: gate.id, check_in_list_id: list_id})
          |> Repo.insert!()
        end)
      end

      updated
    end)
  end

  def delete_gate(gate_id) do
    gate = Repo.get!(Gate, gate_id)
    Repo.delete(gate)
  end

  def list_gates(event_id) do
    Gate
    |> where([g], g.event_id == ^event_id)
    |> preload(:check_in_lists)
    |> order_by([g], asc: g.name)
    |> Repo.all()
  end

  def get_gate!(id) do
    Gate
    |> preload(check_in_lists: :check_in_list_items)
    |> Repo.get!(id)
  end

  defp broadcast_check_in_update(event_id) do
    count = get_check_in_count(event_id)
    Phoenix.PubSub.broadcast(Pretex.PubSub, checkin_topic(event_id), {:check_in_updated, count})
  end
end
