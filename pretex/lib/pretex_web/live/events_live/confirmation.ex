defmodule PretexWeb.EventsLive.Confirmation do
  use PretexWeb, :live_view

  alias Pretex.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <.customer_layout current_scope={@current_scope} current_path="" flash={@flash}>
      <div class="mx-auto max-w-2xl">
        <%!-- Success hero --%>
        <div class="text-center mb-8">
          <div class="flex justify-center mb-4">
            <div class="rounded-full bg-success/10 p-5">
              <.icon name="hero-check-circle" class="size-16 text-success" />
            </div>
          </div>
          <h1 class="text-3xl font-bold text-base-content tracking-tight">Pedido Confirmado!</h1>
          <p class="mt-2 text-base text-base-content/60">
            Obrigado pela sua compra. Seus ingressos estão prontos.
          </p>
        </div>

        <%!-- Order details card --%>
        <div class="rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden mb-6">
          <%!-- Confirmation code banner --%>
          <div class="bg-success/10 border-b border-success/20 px-6 py-4 text-center">
            <p class="text-xs font-semibold uppercase tracking-widest text-success/70 mb-1">
              Código de Confirmação
            </p>
            <p class="text-3xl font-mono font-bold text-success tracking-widest">
              {@order.confirmation_code}
            </p>
          </div>

          <div class="p-6 space-y-5">
            <%!-- Event info --%>
            <div>
              <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/50 mb-2">
                Evento
              </h2>
              <div class="flex items-start gap-3">
                <.icon name="hero-calendar-days" class="size-5 text-primary shrink-0 mt-0.5" />
                <div>
                  <p class="font-semibold text-base-content">{@order.event.name}</p>
                  <p :if={@order.event.starts_at} class="text-sm text-base-content/60 mt-0.5">
                    {Calendar.strftime(@order.event.starts_at, "%B %d, %Y")}
                  </p>
                  <p :if={@order.event.venue} class="text-sm text-base-content/60">
                    {@order.event.venue}
                  </p>
                </div>
              </div>
            </div>

            <div class="h-px bg-base-200" />

            <%!-- Attendee --%>
            <div>
              <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/50 mb-2">
                Participante
              </h2>
              <div class="text-sm text-base-content/80 space-y-1">
                <div class="flex items-center gap-2">
                  <.icon name="hero-user" class="size-4 text-base-content/40 shrink-0" />
                  <span>{@order.name}</span>
                </div>
                <div class="flex items-center gap-2">
                  <.icon name="hero-envelope" class="size-4 text-base-content/40 shrink-0" />
                  <span>{@order.email}</span>
                </div>
              </div>
            </div>

            <div class="h-px bg-base-200" />

            <%!-- Items purchased --%>
            <div>
              <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/50 mb-3">
                Ingressos Adquiridos
              </h2>
              <div class="space-y-3">
                <div
                  :for={order_item <- @order.order_items}
                  id={"order-item-#{order_item.id}"}
                  class="flex items-start justify-between gap-3 rounded-xl bg-base-200/40 px-4 py-3"
                >
                  <div class="min-w-0 flex-1">
                    <p class="font-medium text-base-content text-sm">{order_item.item.name}</p>
                    <p :if={order_item.item_variation} class="text-xs text-base-content/50 mt-0.5">
                      {order_item.item_variation.name}
                    </p>
                    <p class="text-xs text-base-content/50 mt-1">
                      Qtd: {order_item.quantity} × {format_price(order_item.unit_price_cents)}
                    </p>
                    <p :if={order_item.ticket_code} class="text-xs font-mono text-primary/70 mt-1">
                      # {order_item.ticket_code}
                    </p>
                  </div>
                  <div class="shrink-0 text-right">
                    <span class="font-semibold text-base-content text-sm">
                      {format_price(order_item.quantity * order_item.unit_price_cents)}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <div class="h-px bg-base-200" />

            <%!-- Total --%>
            <div class="flex justify-between items-center">
              <span class="font-bold text-base-content">Total Pago</span>
              <span class="text-xl font-bold text-primary">{format_price(@order.total_cents)}</span>
            </div>

            <%!-- Status --%>
            <div class="flex items-center justify-between">
              <span class="text-sm text-base-content/60">Status do Pedido</span>
              <span class={[
                "badge badge-sm font-semibold",
                case @order.status do
                  "confirmed" -> "badge-success"
                  "pending" -> "badge-warning"
                  "cancelled" -> "badge-error"
                  "expired" -> "badge-ghost"
                  _ -> "badge-ghost"
                end
              ]}>
                {String.capitalize(@order.status)}
              </span>
            </div>
          </div>
        </div>

        <%!-- Actions --%>
        <div class="flex flex-col sm:flex-row gap-3 justify-center">
          <.link
            navigate={~p"/events"}
            class="btn btn-primary gap-2"
          >
            <.icon name="hero-magnifying-glass" class="size-4" /> Explorar Mais Eventos
          </.link>

          <.link
            :if={@current_scope && @current_scope.customer}
            navigate={~p"/account/orders"}
            class="btn btn-ghost gap-2"
          >
            <.icon name="hero-ticket" class="size-4" /> Ver Meus Pedidos
          </.link>
        </div>
      </div>
    </.customer_layout>
    """
  end

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    case Orders.get_order_by_confirmation_code(code) do
      {:ok, order} ->
        socket =
          socket
          |> assign(:page_title, "Order Confirmed – #{order.confirmation_code}")
          |> assign(:order, order)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Order not found.")
         |> push_navigate(to: ~p"/events")}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp format_price(nil), do: "Free"
  defp format_price(0), do: "Free"

  defp format_price(cents) do
    dollars = div(cents, 100)
    cents_part = rem(cents, 100)
    "R$ #{dollars},#{String.pad_leading(Integer.to_string(cents_part), 2, "0")}"
  end
end
