defmodule PretexWeb.Admin.CatalogLive.ItemForm do
  use PretexWeb, :live_view

  alias Pretex.Catalog
  alias Pretex.Catalog.Item
  alias Pretex.Catalog.ItemVariation
  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id} = params, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)

    {item, page_title} =
      case params do
        %{"id" => id} ->
          item = Catalog.get_item!(id)
          {item, "Edit Item — #{item.name}"}

        _ ->
          {%Item{variations: []}, "New Item"}
      end

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:item, item)
      |> assign(:page_title, page_title)
      |> assign(:form, to_form(Catalog.change_item(item)))
      |> assign(:variation_form, to_form(Catalog.change_variation(%ItemVariation{})))
      |> assign(:show_variation_form, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"item" => params}, socket) do
    changeset =
      socket.assigns.item
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

  def handle_event("show_variation_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_variation_form, true)
     |> assign(:variation_form, to_form(Catalog.change_variation(%ItemVariation{})))}
  end

  def handle_event("hide_variation_form", _params, socket) do
    {:noreply, assign(socket, :show_variation_form, false)}
  end

  def handle_event("validate_variation", %{"item_variation" => params}, socket) do
    changeset =
      %ItemVariation{}
      |> Catalog.change_variation(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :variation_form, to_form(changeset))}
  end

  def handle_event("add_variation", %{"item_variation" => params}, socket) do
    item = socket.assigns.item

    case Catalog.create_variation(item, params) do
      {:ok, _variation} ->
        updated_item = Catalog.get_item!(item.id)

        {:noreply,
         socket
         |> assign(:item, updated_item)
         |> assign(:show_variation_form, false)
         |> assign(:variation_form, to_form(Catalog.change_variation(%ItemVariation{})))
         |> put_flash(:info, "Variation added.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :variation_form, to_form(changeset))}
    end
  end

  def handle_event("delete_variation", %{"id" => id}, socket) do
    variation = Catalog.get_variation!(id)

    case Catalog.delete_variation(variation) do
      {:ok, _} ->
        updated_item = Catalog.get_item!(socket.assigns.item.id)

        {:noreply,
         socket
         |> assign(:item, updated_item)
         |> put_flash(:info, "Variation removed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove variation.")}
    end
  end

  defp do_create(socket, params) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Catalog.create_item(event, params) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Item created successfully.")
         |> push_navigate(to: ~p"/admin/organizations/#{org}/events/#{event}/catalog")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    item = socket.assigns.item
    org = socket.assigns.org
    event = socket.assigns.event

    case Catalog.update_item(item, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:item, updated)
         |> put_flash(:info, "Item updated successfully.")
         |> push_navigate(to: ~p"/admin/organizations/#{org}/events/#{event}/catalog")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp format_price(cents) when is_integer(cents) do
    "R$ #{:erlang.float_to_binary(cents / 100, decimals: 2)}"
  end

  defp format_price(_), do: "R$ 0,00"
end
