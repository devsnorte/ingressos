defmodule PretexWeb.EventsLive.Checkout do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <.customer_layout
      current_scope={@current_scope}
      current_path={"/events/#{@event.slug}/checkout"}
      flash={@flash}
    >
      <div class="mx-auto max-w-3xl">
        <%!-- Step indicator --%>
        <div class="mb-8">
          <nav class="flex items-center justify-center gap-4">
            <div class={[
              "flex items-center gap-2 text-sm font-medium",
              if(@live_action == :info, do: "text-primary", else: "text-base-content/40")
            ]}>
              <span class={[
                "flex size-7 items-center justify-center rounded-full text-xs font-bold",
                if(@live_action == :info,
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 text-base-content/40"
                )
              ]}>
                1
              </span>
              Informações
            </div>

            <div class="h-px w-12 bg-base-200" />

            <div class={[
              "flex items-center gap-2 text-sm font-medium",
              if(@live_action == :summary, do: "text-primary", else: "text-base-content/40")
            ]}>
              <span class={[
                "flex size-7 items-center justify-center rounded-full text-xs font-bold",
                if(@live_action == :summary,
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 text-base-content/40"
                )
              ]}>
                2
              </span>
              Pagamento
            </div>
          </nav>
        </div>

        <%!-- Info step --%>
        <div
          :if={@live_action == :info}
          class="rounded-2xl border border-base-200 bg-base-100 shadow-sm p-6"
        >
          <h2 class="text-xl font-bold text-base-content mb-6">Suas Informações</h2>

          <.form
            for={@form}
            id="checkout-info-form"
            phx-submit="submit_info"
            phx-change="validate_info"
            class="space-y-5"
          >
            <.input
              field={@form[:name]}
              type="text"
              label="Nome Completo"
              placeholder="Seu nome completo"
              required
            />
            <.input
              field={@form[:email]}
              type="email"
              label="E-mail"
              placeholder="voce@exemplo.com"
              required
            />

            <div class="pt-4 flex gap-3">
              <button
                type="button"
                phx-click="back_to_event"
                class="btn btn-ghost flex-1"
              >
                <.icon name="hero-arrow-left" class="size-4" /> Voltar
              </button>
              <button type="submit" class="btn btn-primary flex-1">
                Continuar <.icon name="hero-arrow-right" class="size-4" />
              </button>
            </div>
          </.form>
        </div>

        <%!-- Summary step --%>
        <div :if={@live_action == :summary} class="space-y-6">
          <%!-- Order summary --%>
          <div class="rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden">
            <div class="p-5 border-b border-base-200 bg-base-200/30">
              <h2 class="text-lg font-bold text-base-content">Resumo do Pedido</h2>
            </div>
            <div class="p-5 space-y-3">
              <div class="text-sm text-base-content/60 mb-3">
                <span class="font-medium text-base-content">{@event.name}</span>
              </div>

              <div
                :for={cart_item <- @cart.cart_items}
                class="flex justify-between items-center text-sm py-2 border-b border-base-100 last:border-0"
              >
                <div>
                  <p class="font-medium text-base-content">{cart_item.item.name}</p>
                  <p :if={cart_item.item_variation} class="text-xs text-base-content/50">
                    {cart_item.item_variation.name}
                  </p>
                  <p class="text-xs text-base-content/50 mt-0.5">
                    Qtd: {cart_item.quantity}
                  </p>
                </div>
                <span class="font-semibold text-base-content">
                  {format_price(cart_item.quantity * item_unit_price(cart_item))}
                </span>
              </div>

              <div class="flex justify-between items-center pt-3 mt-2 border-t-2 border-base-200">
                <span class="font-bold text-base-content">Total</span>
                <span class="text-xl font-bold text-primary">{format_price(@cart_total)}</span>
              </div>
            </div>
          </div>

          <%!-- Attendee info --%>
          <div class="rounded-2xl border border-base-200 bg-base-100 shadow-sm p-5">
            <div class="flex justify-between items-center mb-3">
              <h3 class="font-semibold text-base-content">Dados do Participante</h3>
              <button
                phx-click="back_to_info"
                class="btn btn-ghost btn-xs text-primary"
              >
                Editar
              </button>
            </div>
            <div class="text-sm text-base-content/70 space-y-1">
              <p><span class="font-medium text-base-content">Nome:</span> {@attendee_name}</p>
              <p><span class="font-medium text-base-content">E-mail:</span> {@attendee_email}</p>
            </div>
          </div>

          <%!-- Payment method --%>
          <div class="rounded-2xl border border-base-200 bg-base-100 shadow-sm p-5">
            <h3 class="font-semibold text-base-content mb-4">Forma de Pagamento</h3>
            <div class="grid grid-cols-2 gap-3">
              <button
                :for={{method, label, icon} <- payment_methods()}
                id={"pay-#{method}"}
                phx-click="select_payment"
                phx-value-method={method}
                class={[
                  "flex items-center gap-3 rounded-xl border-2 p-4 text-sm font-medium transition-all duration-150 text-left",
                  if(@payment_method == method,
                    do: "border-primary bg-primary/5 text-primary",
                    else:
                      "border-base-200 bg-base-100 text-base-content/70 hover:border-primary/40 hover:bg-primary/5"
                  )
                ]}
              >
                <.icon name={icon} class="size-5 shrink-0" />
                <span>{label}</span>
                <.icon
                  :if={@payment_method == method}
                  name="hero-check-circle"
                  class="size-4 ml-auto text-primary"
                />
              </button>
            </div>
          </div>

          <%!-- Place order --%>
          <div class="flex gap-3">
            <button
              phx-click="back_to_info"
              class="btn btn-ghost flex-1"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Voltar
            </button>
            <button
              id="place-order-btn"
              phx-click="place_order"
              disabled={is_nil(@payment_method)}
              class="btn btn-primary flex-1 gap-2"
            >
              <.icon name="hero-lock-closed" class="size-4" /> Concluir Pedido
            </button>
          </div>
        </div>
      </div>
    </.customer_layout>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    event = Events.get_event_by_slug!(slug)

    socket =
      socket
      |> assign(:page_title, "Checkout – #{event.name}")
      |> assign(:event, event)
      |> assign(:cart, nil)
      |> assign(:cart_total, 0)
      |> assign(:payment_method, nil)
      |> assign(:attendee_name, "")
      |> assign(:attendee_email, "")
      |> assign(:form, to_form(%{"name" => "", "email" => ""}, as: :checkout))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    cart_token = Map.get(params, "cart_token")

    socket =
      if cart_token do
        case Orders.get_cart_by_token(cart_token) do
          nil ->
            socket
            |> put_flash(:error, "Cart not found. Please add items first.")
            |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")

          cart ->
            if cart.event_id == socket.assigns.event.id && cart.status == "active" do
              socket
              |> assign(:cart, cart)
              |> assign(:cart_total, Orders.cart_total(cart))
            else
              socket
              |> put_flash(:error, "Your cart has expired. Please start again.")
              |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")
            end
        end
      else
        socket
        |> put_flash(:error, "No cart found. Please add items first.")
        |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_info", %{"checkout" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: :checkout))}
  end

  def handle_event("submit_info", %{"checkout" => %{"name" => name, "email" => email}}, socket) do
    cond do
      String.trim(name) == "" ->
        {:noreply,
         assign(socket, :form, to_form(%{"name" => name, "email" => email}, as: :checkout))}

      String.trim(email) == "" ->
        {:noreply,
         assign(socket, :form, to_form(%{"name" => name, "email" => email}, as: :checkout))}

      true ->
        cart = socket.assigns.cart

        socket =
          socket
          |> assign(:attendee_name, name)
          |> assign(:attendee_email, email)
          |> push_patch(
            to:
              ~p"/events/#{socket.assigns.event.slug}/checkout/summary?cart_token=#{cart.session_token}",
            replace: false
          )

        {:noreply, socket}
    end
  end

  def handle_event("select_payment", %{"method" => method}, socket) do
    {:noreply, assign(socket, :payment_method, method)}
  end

  def handle_event("back_to_event", _params, socket) do
    cart = socket.assigns.cart
    event = socket.assigns.event

    path =
      if cart do
        ~p"/events/#{event.slug}?cart_token=#{cart.session_token}"
      else
        ~p"/events/#{event.slug}"
      end

    {:noreply, push_navigate(socket, to: path)}
  end

  def handle_event("back_to_info", _params, socket) do
    cart = socket.assigns.cart
    event = socket.assigns.event

    {:noreply,
     push_patch(socket,
       to: ~p"/events/#{event.slug}/checkout?cart_token=#{cart.session_token}",
       replace: false
     )}
  end

  def handle_event("place_order", _params, socket) do
    cart = socket.assigns.cart
    payment_method = socket.assigns.payment_method
    name = socket.assigns.attendee_name
    email = socket.assigns.attendee_email

    if is_nil(payment_method) do
      {:noreply, put_flash(socket, :error, "Please select a payment method.")}
    else
      attrs = %{
        name: name,
        email: email,
        payment_method: payment_method
      }

      case Orders.create_order_from_cart(cart, attrs) do
        {:ok, order} ->
          {:noreply,
           push_navigate(socket,
             to: ~p"/events/#{socket.assigns.event.slug}/orders/#{order.confirmation_code}"
           )}

        {:error, :cart_expired} ->
          {:noreply,
           socket
           |> put_flash(:error, "Your cart has expired. Please start over.")
           |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")}

        {:error, :cart_not_active} ->
          {:noreply,
           socket
           |> put_flash(:error, "Your cart is no longer active.")
           |> push_navigate(to: ~p"/events/#{socket.assigns.event.slug}")}

        {:error, changeset} ->
          errors =
            Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
              Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
              end)
            end)

          error_msg =
            errors
            |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
            |> Enum.join("; ")

          {:noreply, put_flash(socket, :error, "Could not place order: #{error_msg}")}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp payment_methods do
    [
      {"credit_card", "Cartão de Crédito", "hero-credit-card"},
      {"pix", "Pix", "hero-qr-code"},
      {"boleto", "Boleto", "hero-document-text"},
      {"bank_transfer", "Transferência", "hero-building-library"}
    ]
  end

  defp format_price(nil), do: "Free"
  defp format_price(0), do: "Free"

  defp format_price(cents) do
    dollars = div(cents, 100)
    cents_part = rem(cents, 100)
    "R$ #{dollars},#{String.pad_leading(Integer.to_string(cents_part), 2, "0")}"
  end

  defp item_unit_price(%{item_variation: %{price_cents: price}}) when not is_nil(price), do: price
  defp item_unit_price(%{item: %{price_cents: price}}), do: price
  defp item_unit_price(_), do: 0
end
