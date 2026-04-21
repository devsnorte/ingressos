defmodule PretexWeb.Plugs.DeviceAuth do
  @moduledoc "Authenticates device API requests via Bearer token."

  import Plug.Conn

  alias Pretex.Devices

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, device} <- Devices.authenticate_device(token) do
      assign(conn, :current_device, device)
    else
      _ ->
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{error: "Dispositivo não autenticado"})
        |> halt()
    end
  end
end
