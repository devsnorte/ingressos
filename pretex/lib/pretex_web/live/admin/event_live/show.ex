defmodule PretexWeb.Admin.EventLive.Show do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "id" => id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(id)
    ticket_count = Events.count_ticket_types(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:ticket_count, ticket_count)
      |> assign(:page_title, event.name)

    {:ok, socket}
  end

  @impl true
  def handle_event("publish", _params, socket) do
    event = socket.assigns.event

    case Events.publish_event(event) do
      {:ok, updated_event} ->
        {:noreply,
         socket
         |> assign(:event, updated_event)
         |> put_flash(:info, "Event published successfully.")}

      {:error, :no_ticket_types} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This event needs at least one ticket type before publishing."
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not publish event.")}
    end
  end

  @impl true
  def handle_event("complete", _params, socket) do
    event = socket.assigns.event

    case Events.complete_event(event) do
      {:ok, updated_event} ->
        {:noreply,
         socket
         |> assign(:event, updated_event)
         |> put_flash(:info, "Event marked as completed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not complete event.")}
    end
  end

  @impl true
  def handle_event("clone", _params, socket) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Events.clone_event(event) do
      {:ok, new_event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event cloned successfully.")
         |> push_navigate(to: ~p"/admin/organizations/#{org}/events/#{new_event}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not clone event.")}
    end
  end
end
