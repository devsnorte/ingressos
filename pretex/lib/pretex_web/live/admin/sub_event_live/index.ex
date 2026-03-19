defmodule PretexWeb.Admin.SubEventLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Events.SubEvent
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    sub_events = Events.list_sub_events(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:page_title, "Sub-Events — #{event.name}")
      |> stream(:sub_events, sub_events)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Sub-Events — #{socket.assigns.event.name}")
    |> assign(:form, nil)
    |> assign(:editing_sub_event, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Sub-Event")
    |> assign(:editing_sub_event, %SubEvent{})
    |> assign(:form, to_form(Events.change_sub_event(%SubEvent{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    sub_event = Events.get_sub_event!(id)

    socket
    |> assign(:page_title, "Edit Sub-Event")
    |> assign(:editing_sub_event, sub_event)
    |> assign(:form, to_form(Events.change_sub_event(sub_event)))
  end

  @impl true
  def handle_event("enable_series", _params, socket) do
    event = socket.assigns.event

    case Events.enable_series(event) do
      {:ok, updated_event} ->
        {:noreply,
         socket
         |> assign(:event, updated_event)
         |> put_flash(:info, "Series mode enabled.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not enable series mode.")}
    end
  end

  def handle_event("disable_series", _params, socket) do
    event = socket.assigns.event

    case Events.disable_series(event) do
      {:ok, updated_event} ->
        {:noreply,
         socket
         |> assign(:event, updated_event)
         |> put_flash(:info, "Series mode disabled.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not disable series mode.")}
    end
  end

  def handle_event("validate", %{"sub_event" => params}, socket) do
    changeset =
      socket.assigns.editing_sub_event
      |> Events.change_sub_event(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"sub_event" => params}, socket) do
    case socket.assigns.live_action do
      :new -> do_create(socket, params)
      :edit -> do_update(socket, params)
    end
  end

  def handle_event("cancel", _params, socket) do
    org = socket.assigns.org
    event = socket.assigns.event

    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/events/#{event}/sub-events")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    sub_event = Events.get_sub_event!(id)

    case Events.delete_sub_event(sub_event) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sub-event deleted.")
         |> stream_delete(:sub_events, sub_event)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete sub-event.")}
    end
  end

  def handle_event("publish", %{"id" => id}, socket) do
    sub_event = Events.get_sub_event!(id)

    case Events.publish_sub_event(sub_event) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sub-event published.")
         |> stream_insert(:sub_events, updated)}

      {:error, :invalid_status} ->
        {:noreply,
         put_flash(socket, :error, "Sub-event cannot be published from its current status.")}
    end
  end

  def handle_event("hide", %{"id" => id}, socket) do
    sub_event = Events.get_sub_event!(id)

    case Events.hide_sub_event(sub_event) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sub-event hidden.")
         |> stream_insert(:sub_events, updated)}

      {:error, :invalid_status} ->
        {:noreply,
         put_flash(socket, :error, "Sub-event cannot be hidden from its current status.")}
    end
  end

  defp do_create(socket, params) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Events.create_sub_event(event, params) do
      {:ok, sub_event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sub-event created successfully.")
         |> stream_insert(:sub_events, sub_event)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/sub-events")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    sub_event = socket.assigns.editing_sub_event
    org = socket.assigns.org
    event = socket.assigns.event

    case Events.update_sub_event(sub_event, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sub-event updated successfully.")
         |> stream_insert(:sub_events, updated)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/sub-events")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
