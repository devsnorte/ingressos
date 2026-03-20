defmodule PretexWeb.Admin.OrderLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Orders
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    orders = Orders.search_orders_for_event(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:orders, orders)
      |> assign(:search, "")
      |> assign(:status_filter, "")
      |> assign(:page_title, "Pedidos — #{event.name}")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Pedidos — #{socket.assigns.event.name}")
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    order = Orders.get_order_with_details!(id)

    socket
    |> assign(:page_title, "Pedido ##{order.confirmation_code}")
    |> assign(:order, order)
  end

  defp apply_action(socket, :new_manual, _params) do
    assign(socket, :page_title, "Novo Pedido Manual")
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    orders =
      Orders.search_orders_for_event(socket.assigns.event,
        search: query,
        status: socket.assigns.status_filter
      )

    {:noreply,
     socket
     |> assign(:search, query)
     |> assign(:orders, orders)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    orders =
      Orders.search_orders_for_event(socket.assigns.event,
        search: socket.assigns.search,
        status: status
      )

    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign(:orders, orders)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    orders = Orders.search_orders_for_event(socket.assigns.event)

    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:status_filter, "")
     |> assign(:orders, orders)}
  end
end
