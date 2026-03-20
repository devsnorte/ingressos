defmodule PretexWeb.CustomerLive.Orders do
  use PretexWeb, :live_view

  alias Pretex.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <.customer_layout current_scope={@current_scope} current_path="/account/orders" flash={@flash}>
      <div class="mx-auto max-w-3xl">
        <div class="mb-8">
          <h1 class="text-2xl font-bold tracking-tight text-base-content">Meus Pedidos</h1>
          <p class="mt-1 text-sm text-base-content/60">
            Histórico de compras de ingressos.
          </p>
        </div>

        <div :if={@orders == []} class="text-center py-20 space-y-6">
          <div class="flex justify-center">
            <div class="rounded-full bg-base-200 p-6">
              <.icon name="hero-ticket" class="size-16 text-base-content/40" />
            </div>
          </div>

          <div class="space-y-2">
            <h2 class="text-xl font-semibold text-base-content">Você ainda não tem pedidos</h2>
            <p class="text-base text-base-content/60 max-w-sm mx-auto">
              Explore os próximos eventos para começar. Seus ingressos e histórico de pedidos aparecerão aqui após a compra.
            </p>
          </div>

          <div class="pt-2">
            <.link
              navigate={~p"/events"}
              class="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-sm font-semibold text-primary-content shadow-sm hover:brightness-110 transition-all duration-150"
            >
              <.icon name="hero-magnifying-glass" class="size-4" /> Explorar Eventos
            </.link>
          </div>
        </div>

        <div :if={@orders != []} id="orders-list" class="space-y-4">
          <div
            :for={order <- @orders}
            id={"order-#{order.id}"}
            class="rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden hover:shadow-md transition-shadow"
          >
            <div class="flex items-center justify-between px-5 py-4 border-b border-base-200 bg-base-200/30">
              <div>
                <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50 mb-0.5">
                  Código de Confirmação
                </p>
                <p class="text-lg font-mono font-bold text-primary tracking-widest">
                  {order.confirmation_code}
                </p>
              </div>
              <span class={[
                "badge badge-sm font-semibold",
                case order.status do
                  "confirmed" -> "badge-success"
                  "pending" -> "badge-warning"
                  "cancelled" -> "badge-error"
                  "expired" -> "badge-ghost"
                  _ -> "badge-ghost"
                end
              ]}>
                {String.capitalize(order.status)}
              </span>
            </div>

            <div class="px-5 py-4 space-y-3">
              <div class="flex items-start gap-3">
                <.icon name="hero-calendar-days" class="size-5 text-primary shrink-0 mt-0.5" />
                <div>
                  <p class="font-semibold text-base-content">
                    {order.event.name}
                  </p>
                  <p :if={order.event.starts_at} class="text-sm text-base-content/60 mt-0.5">
                    {Calendar.strftime(order.event.starts_at, "%B %d, %Y")}
                  </p>
                </div>
              </div>

              <div class="flex items-center justify-between text-sm">
                <div class="flex items-center gap-2 text-base-content/60">
                  <.icon name="hero-ticket" class="size-4 shrink-0" />
                  <span>
                    {length(order.order_items)}
                    {if length(order.order_items) == 1, do: "ingresso", else: "ingressos"}
                  </span>
                </div>
                <span class="font-bold text-base-content">
                  {format_price(order.total_cents)}
                </span>
              </div>

              <div class="flex items-center gap-2 text-xs text-base-content/40">
                <.icon name="hero-clock" class="size-3.5 shrink-0" />
                <span>
                  Pedido em {Calendar.strftime(order.inserted_at, "%d/%m/%Y às %H:%M")}
                </span>
              </div>
            </div>

            <div class="px-5 pb-4">
              <.link
                navigate={~p"/events/#{order.event.slug}/orders/#{order.confirmation_code}"}
                class="btn btn-ghost btn-sm gap-2 w-full"
              >
                <.icon name="hero-eye" class="size-4" /> Ver Detalhes
              </.link>
            </div>
          </div>
        </div>
      </div>
    </.customer_layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    customer = socket.assigns.current_scope.customer
    orders = Orders.list_orders_for_customer(customer.id)

    socket =
      socket
      |> assign(:page_title, "My Orders")
      |> assign(:orders, orders)

    {:ok, socket}
  end

  defp format_price(nil), do: "Free"
  defp format_price(0), do: "Free"

  defp format_price(cents) do
    dollars = div(cents, 100)
    cents_part = rem(cents, 100)
    "R$ #{dollars},#{String.pad_leading(Integer.to_string(cents_part), 2, "0")}"
  end
end
