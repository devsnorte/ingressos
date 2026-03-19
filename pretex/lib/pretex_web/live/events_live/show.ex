defmodule PretexWeb.EventsLive.Show do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Catalog
  alias Pretex.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <%!-- Event header --%>
        <div
          class="relative rounded-2xl overflow-hidden mb-8 p-8 text-white"
          style={"background: linear-gradient(135deg, #{@event.primary_color || "#6366f1"}, #{@event.accent_color || "#f43f5e"})"}
        >
          <div class="relative z-10">
            <%= if @event.organization do %>
              <p class="text-sm font-medium text-white/70 uppercase tracking-widest mb-2">
                {@event.organization.name}
              </p>
            <% end %>
            <h1 class="text-3xl sm:text-4xl font-bold tracking-tight mb-4">{@event.name}</h1>

            <div class="flex flex-wrap gap-4 text-sm text-white/80">
              <div class="flex items-center gap-2">
                <.icon name="hero-calendar-days" class="size-4" />
                <span>
                  {Calendar.strftime(@event.starts_at, "%B %d, %Y")}
                  <%= if @event.ends_at do %>
                    – {Calendar.strftime(@event.ends_at, "%B %d, %Y")}
                  <% end %>
                </span>
              </div>
              <%= if @event.venue do %>
                <div class="flex items-center gap-2">
                  <.icon name="hero-map-pin" class="size-4" />
                  <span>{@event.venue}</span>
                </div>
              <% end %>
            </div>

            <%= if @event.description do %>
              <p class="mt-4 text-white/80 max-w-2xl leading-relaxed">{@event.description}</p>
            <% end %>
          </div>
        </div>

        <div class="flex flex-col lg:flex-row gap-8">
          <%!-- Items section --%>
          <div class="flex-1 min-w-0">
            <%= if @items_by_category == [] do %>
              <div class="text-center py-16 rounded-2xl border border-dashed border-base-300">
                <.icon name="hero-ticket" class="size-12 text-base-content/30 mx-auto mb-3" />
                <p class="text-base-content/60">No tickets available yet.</p>
              </div>
            <% else %>
              <%= for {category, items} <- @items_by_category do %>
                <div
                  class="mb-8"
                  id={"category-#{if category, do: category.id, else: "uncategorized"}"}
                >
                  <%= if category do %>
                    <h2 class="text-lg font-semibold text-base-content mb-3 pb-2 border-b border-base-200">
                      {category.name}
                    </h2>
                  <% end %>

                  <div class="space-y-3">
                    <%= for item <- items do %>
                      <div
                        id={"item-#{item.id}"}
                        class="flex items-start gap-4 rounded-xl border border-base-200 bg-base-100 p-4 shadow-sm hover:shadow-md transition-shadow"
                      >
                        <div class="flex-1 min-w-0">
                          <div class="flex items-start justify-between gap-3">
                            <div>
                              <h3 class="font-semibold text-base-content">{item.name}</h3>
                              <%= if item.description do %>
                                <p class="mt-1 text-sm text-base-content/60 leading-relaxed">
                                  {item.description}
                                </p>
                              <% end %>
                            </div>
                            <div class="shrink-0 text-right">
                              <span class="text-lg font-bold text-primary">
                                {format_price(item.price_cents)}
                              </span>
                            </div>
                          </div>

                          <div class="mt-3 flex items-center gap-3">
                            <div class="flex items-center gap-2">
                              <label class="text-sm text-base-content/60">Qty:</label>
                              <select
                                id={"qty-#{item.id}"}
                                class="select select-sm select-bordered w-20"
                              >
                                <%= for n <- 1..max_quantity(item) do %>
                                  <option value={n}>{n}</option>
                                <% end %>
                              </select>
                            </div>

                            <button
                              id={"add-#{item.id}"}
                              phx-click="add_to_cart"
                              phx-value-item_id={item.id}
                              class="btn btn-primary btn-sm gap-1"
                            >
                              <.icon name="hero-plus" class="size-4" /> Add to Cart
                            </button>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <%!-- Cart sidebar --%>
          <div class="lg:w-80 shrink-0">
            <div
              id="cart-sidebar"
              class="sticky top-4 rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden"
            >
              <div class="p-4 border-b border-base-200 bg-base-200/40">
                <div class="flex items-center gap-2">
                  <.icon name="hero-shopping-cart" class="size-5 text-primary" />
                  <h2 class="font-semibold text-base-content">Your Cart</h2>
                  <%= if @cart && @cart.cart_items != [] do %>
                    <span class="ml-auto badge badge-primary badge-sm">
                      {length(@cart.cart_items)}
                    </span>
                  <% end %>
                </div>
              </div>

              <div class="p-4">
                <%= if is_nil(@cart) || @cart.cart_items == [] do %>
                  <div class="text-center py-8">
                    <.icon
                      name="hero-shopping-cart"
                      class="size-10 text-base-content/20 mx-auto mb-2"
                    />
                    <p class="text-sm text-base-content/50">Your cart is empty</p>
                    <p class="text-xs text-base-content/40 mt-1">Add tickets to get started</p>
                  </div>
                <% else %>
                  <div id="cart-items" class="space-y-3 mb-4">
                    <%= for cart_item <- @cart.cart_items do %>
                      <div
                        id={"cart-item-#{cart_item.id}"}
                        class="flex items-start gap-2 text-sm"
                      >
                        <div class="flex-1 min-w-0">
                          <p class="font-medium text-base-content truncate">
                            {cart_item.item.name}
                          </p>
                          <%= if cart_item.item_variation do %>
                            <p class="text-xs text-base-content/50">
                              {cart_item.item_variation.name}
                            </p>
                          <% end %>
                          <p class="text-xs text-base-content/60 mt-0.5">
                            {cart_item.quantity} × {format_price(item_unit_price(cart_item))}
                          </p>
                        </div>
                        <div class="shrink-0 flex items-center gap-1">
                          <span class="font-semibold text-base-content">
                            {format_price(cart_item.quantity * item_unit_price(cart_item))}
                          </span>
                          <button
                            id={"remove-#{cart_item.id}"}
                            phx-click="remove_from_cart"
                            phx-value-cart_item_id={cart_item.id}
                            class="btn btn-ghost btn-xs text-error hover:bg-error/10"
                          >
                            <.icon name="hero-x-mark" class="size-3" />
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>

                  <div class="border-t border-base-200 pt-3 mb-4">
                    <div class="flex justify-between items-center">
                      <span class="text-sm font-medium text-base-content/70">Total</span>
                      <span class="text-lg font-bold text-primary">
                        {format_price(@cart_total)}
                      </span>
                    </div>
                  </div>

                  <.link
                    navigate={~p"/events/#{@event.slug}/checkout?cart_token=#{@cart.session_token}"}
                    class="btn btn-primary w-full gap-2"
                  >
                    <.icon name="hero-arrow-right" class="size-4" /> Checkout
                  </.link>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    event = Events.get_event_by_slug!(slug)
    items = Catalog.list_items(event)
    categories = Catalog.list_categories(event)

    items_by_category = group_items_by_category(items, categories)

    socket =
      socket
      |> assign(:page_title, event.name)
      |> assign(:event, event)
      |> assign(:items_by_category, items_by_category)
      |> assign(:cart, nil)
      |> assign(:cart_total, 0)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    cart_token = Map.get(params, "cart_token")

    socket =
      if cart_token do
        case Orders.get_cart_by_token(cart_token) do
          nil ->
            assign(socket, cart: nil, cart_total: 0)

          cart ->
            if cart.event_id == socket.assigns.event.id && cart.status == "active" do
              socket
              |> assign(:cart, cart)
              |> assign(:cart_total, Orders.cart_total(cart))
            else
              assign(socket, cart: nil, cart_total: 0)
            end
        end
      else
        assign(socket, cart: nil, cart_total: 0)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_to_cart", %{"item_id" => item_id_str}, socket) do
    event = socket.assigns.event
    item_id = String.to_integer(item_id_str)

    item =
      socket.assigns.items_by_category
      |> Enum.flat_map(fn {_cat, items} -> items end)
      |> Enum.find(&(&1.id == item_id))

    if is_nil(item) do
      {:noreply, put_flash(socket, :error, "Item not found.")}
    else
      cart =
        case socket.assigns.cart do
          nil ->
            case Orders.create_cart(event) do
              {:ok, new_cart} -> new_cart
              {:error, _} -> nil
            end

          existing ->
            existing
        end

      if is_nil(cart) do
        {:noreply, put_flash(socket, :error, "Could not create cart.")}
      else
        case Orders.add_to_cart(cart, item) do
          {:ok, _cart_item} ->
            updated_cart = Orders.get_cart_by_token(cart.session_token)

            socket =
              socket
              |> assign(:cart, updated_cart)
              |> assign(:cart_total, Orders.cart_total(updated_cart))
              |> push_patch(
                to: ~p"/events/#{event.slug}?cart_token=#{cart.session_token}",
                replace: true
              )

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not add item to cart.")}
        end
      end
    end
  end

  def handle_event("remove_from_cart", %{"cart_item_id" => cart_item_id_str}, socket) do
    cart = socket.assigns.cart

    if is_nil(cart) do
      {:noreply, socket}
    else
      cart_item_id = String.to_integer(cart_item_id_str)

      case Orders.remove_from_cart(cart, cart_item_id) do
        {:ok, _} ->
          updated_cart = Orders.get_cart_by_token(cart.session_token)

          socket =
            socket
            |> assign(:cart, updated_cart)
            |> assign(:cart_total, Orders.cart_total(updated_cart))

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not remove item.")}
      end
    end
  end

  def handle_event("update_quantity", %{"cart_item_id" => _id, "quantity" => _qty}, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp group_items_by_category(items, categories) do
    category_map = Map.new(categories, &{&1.id, &1})

    categorized =
      items
      |> Enum.group_by(& &1.category_id)
      |> Enum.map(fn {cat_id, cat_items} ->
        {Map.get(category_map, cat_id), cat_items}
      end)
      |> Enum.sort_by(fn
        {nil, _} -> 9999
        {cat, _} -> cat.position
      end)

    categorized
  end

  defp format_price(nil), do: "Free"
  defp format_price(0), do: "Free"

  defp format_price(cents) do
    dollars = div(cents, 100)
    cents_part = rem(cents, 100)
    "R$ #{dollars},#{String.pad_leading(Integer.to_string(cents_part), 2, "0")}"
  end

  defp max_quantity(%{max_per_order: nil}), do: 10
  defp max_quantity(%{max_per_order: max}) when max > 0, do: min(max, 10)
  defp max_quantity(_), do: 10

  defp item_unit_price(%{item_variation: %{price_cents: price}}) when not is_nil(price),
    do: price

  defp item_unit_price(%{item: %{price_cents: price}}), do: price
  defp item_unit_price(_), do: 0
end
