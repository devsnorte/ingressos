defmodule Pretex.CheckIns do
  @moduledoc "Manages event check-in operations."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.CheckIns.CheckIn
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
      [oi, _o],
      ilike(oi.attendee_name, ^term) or ilike(oi.attendee_email, ^term)
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

  defp broadcast_check_in_update(event_id) do
    count = get_check_in_count(event_id)
    Phoenix.PubSub.broadcast(Pretex.PubSub, checkin_topic(event_id), {:check_in_updated, count})
  end
end
