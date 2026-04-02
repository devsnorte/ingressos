defmodule PretexWeb.SyncController do
  use PretexWeb, :controller

  alias Pretex.Sync

  def manifest(conn, params) do
    device = conn.assigns.current_device
    since = parse_since(params["since"])

    {:ok, manifest} = Sync.build_manifest(device.id, since)

    json(conn, manifest)
  end

  def upload(conn, %{"checkins" => checkins}) do
    device = conn.assigns.current_device

    results =
      Enum.map(checkins, fn entry ->
        %{
          ticket_code: entry["ticket_code"],
          event_id: entry["event_id"],
          checked_in_at: parse_datetime!(entry["checked_in_at"])
        }
      end)

    {:ok, summary} = Sync.process_upload(device.id, results)

    json(conn, summary)
  end

  def upload(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Parâmetro checkins é obrigatório"})
  end

  defp parse_since(nil), do: nil

  defp parse_since(since_str) do
    case DateTime.from_iso8601(since_str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime!(str) do
    {:ok, dt, _} = DateTime.from_iso8601(str)
    dt
  end
end
