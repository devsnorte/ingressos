defmodule PretexWeb.CustomerLive.Orders do
  use PretexWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-16">
        <div class="text-center space-y-6">
          <div class="flex justify-center">
            <div class="rounded-full bg-base-200 p-6">
              <.icon name="hero-ticket" class="size-16 text-base-content/40" />
            </div>
          </div>

          <div class="space-y-2">
            <h1 class="text-2xl font-bold tracking-tight text-base-content">
              No orders yet
            </h1>
            <p class="text-base text-base-content/60 max-w-sm mx-auto">
              Browse upcoming events to get started. Your tickets and order history will appear here once you make a purchase.
            </p>
          </div>

          <div class="pt-2">
            <.link
              navigate={~p"/"}
              class="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-sm font-semibold text-primary-content shadow-sm hover:brightness-110 transition-all duration-150"
            >
              <.icon name="hero-magnifying-glass" class="size-4" /> Browse upcoming events
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "My Orders")}
  end
end
