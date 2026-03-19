defmodule PretexWeb.Admin.CatalogLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Catalog
  alias Pretex.Catalog.Item
  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    items = Catalog.list_items(event)
    bundles = Catalog.list_bundles(event)
    categories = Catalog.list_categories(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:categories, categories)
      |> assign(:bundles, bundles)
      |> assign(:page_title, "Item Catalog — #{event.name}")
      |> stream(:items, items)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Item Catalog — #{socket.assigns.event.name}")
    |> assign(:form, nil)
    |> assign(:editing_item, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Item")
    |> assign(:editing_item, %Item{})
    |> assign(:form, to_form(Catalog.change_item(%Item{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    item = Catalog.get_item!(id)

    socket
    |> assign(:page_title, "Edit Item")
    |> assign(:editing_item, item)
    |> assign(:form, to_form(Catalog.change_item(item)))
  end

  @impl true
  def handle_event("validate", %{"item" => params}, socket) do
    changeset =
      socket.assigns.editing_item
      |> Catalog.change_item(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"item" => params}, socket) do
    case socket.assigns.live_action do
      :new -> do_create(socket, params)
      :edit -> do_update(socket, params)
    end
  end

  def handle_event("cancel", _params, socket) do
    org = socket.assigns.org
    event = socket.assigns.event

    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/events/#{event}/catalog")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    item = Catalog.get_item!(id)

    case Catalog.delete_item(item) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Item deleted.")
         |> stream_delete(:items, item)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete item.")}
    end
  end

  defp do_create(socket, params) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Catalog.create_item(event, params) do
      {:ok, item} ->
        preloaded = Catalog.get_item!(item.id)

        {:noreply,
         socket
         |> put_flash(:info, "Item created successfully.")
         |> stream_insert(:items, preloaded)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/catalog")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    item = socket.assigns.editing_item
    org = socket.assigns.org
    event = socket.assigns.event

    case Catalog.update_item(item, params) do
      {:ok, updated} ->
        preloaded = Catalog.get_item!(updated.id)

        {:noreply,
         socket
         |> put_flash(:info, "Item updated successfully.")
         |> stream_insert(:items, preloaded)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/catalog")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp format_price(cents) when is_integer(cents) do
    "R$ #{:erlang.float_to_binary(cents / 100, decimals: 2)}"
  end

  defp format_price(_), do: "R$ 0,00"
end
