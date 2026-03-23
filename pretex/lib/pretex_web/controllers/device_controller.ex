defmodule PretexWeb.DeviceController do
  use PretexWeb, :controller

  alias Pretex.Devices

  def provision(conn, %{"token" => token, "device_name" => device_name}) do
    case Devices.provision_device(token, device_name) do
      {:ok, %{device: device, api_token: api_token}} ->
        device = Pretex.Repo.preload(device, :organization)

        conn
        |> put_status(:created)
        |> json(%{
          device_id: device.id,
          api_token: api_token,
          organization_name: device.organization.name
        })

      {:error, :invalid_token} ->
        conn |> put_status(:not_found) |> json(%{error: "Token inválido"})

      {:error, :token_expired} ->
        conn |> put_status(:gone) |> json(%{error: "Token expirado"})

      {:error, :token_already_used} ->
        conn |> put_status(:conflict) |> json(%{error: "Token já utilizado"})
    end
  end

  def provision(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Parâmetros token e device_name são obrigatórios"})
  end
end
