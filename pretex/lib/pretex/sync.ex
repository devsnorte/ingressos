defmodule Pretex.Sync do
  @moduledoc "Builds sync manifests and processes offline check-in uploads."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Devices.DeviceAssignment
  alias Pretex.Orders.{Order, OrderItem}
  alias Pretex.CheckIns.CheckIn

  def build_manifest(device_id, since) do
    event_ids = assigned_event_ids(device_id)
    server_timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

    events =
      Enum.map(event_ids, fn event_id ->
        event = Repo.get!(Pretex.Events.Event, event_id)
        attendees = fetch_attendees(event_id, since)
        removed = if since, do: fetch_removed_ticket_codes(event_id, since), else: []

        %{
          id: event.id,
          name: event.name,
          starts_at: event.starts_at,
          ends_at: event.ends_at,
          multi_entry: event.multi_entry,
          attendees: attendees,
          removed_ticket_codes: removed
        }
      end)

    {:ok, %{events: events, server_timestamp: server_timestamp}}
  end

  def process_upload(device_id, results) do
    allowed_event_ids = MapSet.new(assigned_event_ids(device_id))

    summary =
      Enum.reduce(
        results,
        %{processed: 0, inserted: 0, conflicts_resolved: 0, skipped: 0, errors: 0},
        fn entry, acc ->
          acc = %{acc | processed: acc.processed + 1}

          if entry.event_id not in allowed_event_ids do
            %{acc | errors: acc.errors + 1}
          else
            case process_single_checkin(device_id, entry) do
              :inserted -> %{acc | inserted: acc.inserted + 1}
              :conflict_resolved -> %{acc | conflicts_resolved: acc.conflicts_resolved + 1}
              :skipped -> %{acc | skipped: acc.skipped + 1}
              :error -> %{acc | errors: acc.errors + 1}
            end
          end
        end
      )

    {:ok, summary}
  end

  defp assigned_event_ids(device_id) do
    DeviceAssignment
    |> where([a], a.device_id == ^device_id)
    |> select([a], a.event_id)
    |> Repo.all()
  end

  defp fetch_attendees(event_id, nil) do
    build_attendee_query(event_id)
    |> Repo.all()
    |> Enum.map(&format_attendee(event_id, &1))
  end

  defp fetch_attendees(event_id, since) do
    build_attendee_query(event_id)
    |> where([oi, _o], oi.updated_at > ^since)
    |> Repo.all()
    |> Enum.map(&format_attendee(event_id, &1))
  end

  defp build_attendee_query(event_id) do
    OrderItem
    |> join(:inner, [oi], o in Order, on: oi.order_id == o.id)
    |> where([oi, o], o.event_id == ^event_id and o.status == "confirmed")
    |> preload([oi, o], [:item, order: o])
  end

  defp format_attendee(event_id, order_item) do
    check_in =
      CheckIn
      |> where(
        [c],
        c.order_item_id == ^order_item.id and
          c.event_id == ^event_id and
          is_nil(c.annulled_at)
      )
      |> Repo.one()

    %{
      ticket_code: order_item.ticket_code,
      attendee_name: order_item.attendee_name || order_item.order.name,
      attendee_email: order_item.attendee_email || order_item.order.email,
      item_name: order_item.item.name,
      checked_in_at: if(check_in, do: check_in.checked_in_at)
    }
  end

  defp fetch_removed_ticket_codes(event_id, since) do
    OrderItem
    |> join(:inner, [oi], o in Order, on: oi.order_id == o.id)
    |> where(
      [oi, o],
      o.event_id == ^event_id and
        o.status == "cancelled" and
        o.updated_at > ^since
    )
    |> select([oi, _o], oi.ticket_code)
    |> Repo.all()
  end

  defp process_single_checkin(device_id, %{
         ticket_code: ticket_code,
         event_id: event_id,
         checked_in_at: checked_in_at
       }) do
    order_item =
      OrderItem
      |> join(:inner, [oi], o in Order, on: oi.order_id == o.id)
      |> where(
        [oi, o],
        oi.ticket_code == ^ticket_code and o.event_id == ^event_id and o.status == "confirmed"
      )
      |> Repo.one()

    case order_item do
      nil -> :error
      oi -> upsert_check_in(oi.id, event_id, device_id, checked_in_at)
    end
  end

  defp upsert_check_in(order_item_id, event_id, device_id, checked_in_at) do
    {s, _precision} = checked_in_at.microsecond
    checked_in_at = %{checked_in_at | microsecond: {s, 6}}

    existing =
      CheckIn
      |> where(
        [c],
        c.order_item_id == ^order_item_id and
          c.event_id == ^event_id and
          is_nil(c.annulled_at)
      )
      |> Repo.one()

    case existing do
      nil ->
        %CheckIn{}
        |> CheckIn.changeset(%{checked_in_at: checked_in_at, device_id: device_id})
        |> Ecto.Changeset.put_change(:order_item_id, order_item_id)
        |> Ecto.Changeset.put_change(:event_id, event_id)
        |> Repo.insert!()

        :inserted

      check_in ->
        if DateTime.compare(checked_in_at, check_in.checked_in_at) == :lt do
          check_in
          |> Ecto.Changeset.change(checked_in_at: checked_in_at, device_id: device_id)
          |> Repo.update!()

          :conflict_resolved
        else
          :skipped
        end
    end
  end
end
