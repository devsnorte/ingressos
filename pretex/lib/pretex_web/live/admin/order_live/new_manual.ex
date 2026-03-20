defmodule PretexWeb.Admin.OrderLive.NewManual do
  use PretexWeb, :live_view

  alias Pretex.Catalog
  alias Pretex.Events
  alias Pretex.Orders
  alias Pretex.Organizations

  @empty_item %{"item_id" => "", "quantity" => "1", "unit_price_cents" => "0"}

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    items_catalog = Catalog.list_items(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:items_catalog, items_catalog)
      |> assign(:page_title, "Novo Pedido Manual — #{event.name}")
      |> assign(:order_params, %{"name" => "", "email" => "", "status" => "paid"})
      |> assign(:order_items_params, [Map.put(@empty_item, "_key", 0)])
      |> assign(:next_key, 1)
      |> assign(:errors, %{})

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_item", _params, socket) do
    key = socket.assigns.next_key
    new_item = Map.put(@empty_item, "_key", key)
    items = socket.assigns.order_items_params ++ [new_item]

    {:noreply,
     socket
     |> assign(:order_items_params, items)
     |> assign(:next_key, key + 1)}
  end

  @impl true
  def handle_event("remove_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    items = List.delete_at(socket.assigns.order_items_params, index)

    {socket, items} =
      if items == [] do
        key = socket.assigns.next_key
        next_key = key + 1
        updated_socket = assign(socket, :next_key, next_key)
        {updated_socket, [Map.put(@empty_item, "_key", key)]}
      else
        {socket, items}
      end

    {:noreply, assign(socket, :order_items_params, items)}
  end

  @impl true
  def handle_event("validate", %{"order" => params}, socket) do
    order_params = Map.take(params, ["name", "email", "status"])
    items_params = parse_items_params(params)

    {:noreply,
     socket
     |> assign(:order_params, order_params)
     |> assign(:order_items_params, items_params)}
  end

  @impl true
  def handle_event("save", %{"order" => params}, socket) do
    order_params = Map.take(params, ["name", "email", "status"])
    items_params = parse_items_params(params)

    event = socket.assigns.event
    org = socket.assigns.org

    items =
      Enum.map(items_params, fn item ->
        %{
          item_id: item["item_id"],
          quantity: parse_int(item["quantity"]),
          unit_price_cents: parse_int(item["unit_price_cents"])
        }
      end)

    attrs = %{
      name: order_params["name"],
      email: order_params["email"],
      status: order_params["status"] || "paid",
      items: items
    }

    case Orders.create_manual_order(event, attrs) do
      {:ok, _order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pedido manual criado com sucesso.")
         |> push_navigate(to: ~p"/admin/organizations/#{org}/events/#{event}/orders")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        {:noreply,
         socket
         |> assign(:order_params, order_params)
         |> assign(:order_items_params, items_params)
         |> assign(:errors, errors)
         |> put_flash(:error, "Erro ao criar pedido. Verifique os campos.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:order_params, order_params)
         |> assign(:order_items_params, items_params)
         |> put_flash(:error, "Não foi possível criar o pedido. Tente novamente.")}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp parse_items_params(params) do
    items_raw = Map.get(params, "items", %{})

    case items_raw do
      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
        |> Enum.map(fn {_k, v} -> v end)

      _ ->
        [Map.put(@empty_item, "_key", 0)]
    end
  end

  defp parse_int(nil), do: 0
  defp parse_int(""), do: 0
  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> 0
    end
  end
end
