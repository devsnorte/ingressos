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

    case parse_checkins(checkins) do
      {:ok, results} ->
        {:ok, summary} = Sync.process_upload(device.id, results)
        json(conn, summary)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  def upload(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Parâmetro checkins é obrigatório"})
  end

  defp parse_checkins(checkins) do
    results =
      Enum.reduce_while(checkins, {:ok, []}, fn entry, {:ok, acc} ->
        case DateTime.from_iso8601(entry["checked_in_at"] || "") do
          {:ok, dt, _} ->
            {:cont,
             {:ok,
              [
                %{
                  ticket_code: entry["ticket_code"],
                  event_id: entry["event_id"],
                  checked_in_at: dt
                }
                | acc
              ]}}

          {:error, _} ->
            {:halt, {:error, "checked_in_at inválido: #{entry["checked_in_at"]}"}}
        end
      end)

    case results do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end

  defp parse_since(nil), do: nil

  defp parse_since(since_str) do
    case DateTime.from_iso8601(since_str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
