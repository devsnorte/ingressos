defmodule PretexWeb.Admin.EventLive.Edit do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "id" => id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(id)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:page_title, "Edit — #{event.name}")
      |> assign(:form, to_form(Events.change_event(event)))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    changeset =
      socket.assigns.event
      |> Events.change_event(event_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"event" => event_params}, socket) do
    org = socket.assigns.org
    event = socket.assigns.event

    case Events.update_event(event, event_params) do
      {:ok, updated_event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event updated successfully.")
         |> push_navigate(to: ~p"/admin/organizations/#{org}/events/#{updated_event}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
