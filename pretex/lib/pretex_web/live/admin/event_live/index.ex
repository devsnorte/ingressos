defmodule PretexWeb.Admin.EventLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    events = Events.list_events(org)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:page_title, "Events — #{org.name}")
      |> stream(:events, events)

    {:ok, socket}
  end

  @impl true
  def handle_event("publish", %{"id" => id}, socket) do
    event = Events.get_event!(id)

    case Events.publish_event(event) do
      {:ok, updated_event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento publicado com sucesso.")
         |> stream_insert(:events, updated_event)}

      {:error, :no_catalog_items} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Adicione pelo menos um item no catálogo antes de publicar."
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível publicar o evento.")}
    end
  end

  @impl true
  def handle_event("complete", %{"id" => id}, socket) do
    event = Events.get_event!(id)

    case Events.complete_event(event) do
      {:ok, updated_event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento marcado como concluído.")
         |> stream_insert(:events, updated_event)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível concluir o evento.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    event = Events.get_event!(id)

    case Events.delete_event(event) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento excluído.")
         |> stream_delete(:events, event)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível excluir o evento.")}
    end
  end

  @impl true
  def handle_event("clone", %{"id" => id}, socket) do
    event = Events.get_event!(id)

    case Events.clone_event(event) do
      {:ok, new_event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento clonado com sucesso.")
         |> stream_insert(:events, new_event, at: 0)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível clonar o evento.")}
    end
  end
end
