defmodule PretexWeb.Admin.DeviceLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Devices
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    devices = Devices.list_devices(org.id)
    events = Devices.list_org_events(org.id)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:devices, devices)
      |> assign(:events, events)
      |> assign(:generated_token, nil)
      |> assign(:page_title, "Dispositivos — #{org.name}")

    {:ok, socket}
  end

  @impl true
  def handle_event("generate_token", _, socket) do
    org = socket.assigns.org
    user_id = socket.assigns.current_user.id

    case Devices.generate_init_token(org.id, user_id) do
      {:ok, token_code} ->
        {:noreply, assign(socket, :generated_token, token_code)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao gerar token.")}
    end
  end

  @impl true
  def handle_event("dismiss_token", _, socket) do
    {:noreply, assign(socket, :generated_token, nil)}
  end

  @impl true
  def handle_event("revoke_device", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)

    case Devices.revoke_device(id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:devices, Devices.list_devices(socket.assigns.org.id))
         |> put_flash(:info, "Acesso do dispositivo revogado.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao revogar dispositivo.")}
    end
  end

  @impl true
  def handle_event(
        "assign_event",
        %{"device_id" => device_id_str, "event_id" => event_id_str},
        socket
      ) do
    device_id = String.to_integer(device_id_str)
    event_id = String.to_integer(event_id_str)

    case Devices.assign_device_to_event(device_id, event_id) do
      {:ok, _} ->
        {:noreply, assign(socket, :devices, Devices.list_devices(socket.assigns.org.id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Dispositivo já atribuído a este evento.")}
    end
  end

  @impl true
  def handle_event(
        "unassign_event",
        %{"device_id" => device_id_str, "event_id" => event_id_str},
        socket
      ) do
    device_id = String.to_integer(device_id_str)
    event_id = String.to_integer(event_id_str)

    Devices.unassign_device_from_event(device_id, event_id)
    {:noreply, assign(socket, :devices, Devices.list_devices(socket.assigns.org.id))}
  end

  defp time_ago(nil), do: "Nunca"

  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "há #{diff}s"
      diff < 3600 -> "há #{div(diff, 60)}min"
      diff < 86400 -> "há #{div(diff, 3600)}h"
      true -> "há #{div(diff, 86400)}d"
    end
  end
end
