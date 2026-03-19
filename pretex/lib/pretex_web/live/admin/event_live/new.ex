defmodule PretexWeb.Admin.EventLive.New do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Events.Event
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:page_title, "New Event")
      |> assign(:form, to_form(Events.change_event(%Event{})))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    changeset =
      %Event{}
      |> Events.change_event(event_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"event" => event_params}, socket) do
    org = socket.assigns.org

    case Events.create_event(org, event_params) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event created successfully.")
         |> push_navigate(to: ~p"/admin/organizations/#{org}/events")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
