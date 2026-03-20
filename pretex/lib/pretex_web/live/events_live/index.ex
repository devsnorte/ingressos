defmodule PretexWeb.EventsLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Events

  @impl true
  def render(assigns) do
    ~H"""
    <.customer_layout current_scope={@current_scope} current_path="/events" flash={@flash}>
      <div class="mb-8">
        <h1 class="text-3xl font-bold tracking-tight text-base-content">Eventos</h1>
        <p class="mt-2 text-base text-base-content/60">
          Descubra eventos da comunidade
        </p>
      </div>

      <div id="events-empty" class="hidden only:block text-center py-20">
        <div class="flex justify-center mb-4">
          <div class="rounded-full bg-base-200 p-6">
            <.icon name="hero-calendar" class="size-12 text-base-content/30" />
          </div>
        </div>
        <h2 class="text-xl font-semibold text-base-content">Nenhum evento disponível</h2>
        <p class="mt-2 text-base-content/60">Volte mais tarde para conferir os próximos eventos.</p>
      </div>

      <div
        id="events"
        phx-update="stream"
        class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3"
      >
        <div
          :for={{id, event} <- @streams.events}
          id={id}
          class="group flex flex-col rounded-2xl border border-base-200 bg-base-100 shadow-sm hover:shadow-md transition-all duration-200 overflow-hidden"
        >
          <div class="h-2 w-full bg-primary rounded-t-2xl" />
          <div class="flex flex-col flex-1 p-5 gap-3">
            <div class="flex-1">
              <h2 class="text-lg font-bold text-base-content group-hover:text-primary transition-colors line-clamp-2">
                {event.name}
              </h2>
              <p
                :if={event.organization}
                class="mt-1 text-xs font-medium text-base-content/50 uppercase tracking-wide"
              >
                {event.organization.name}
              </p>
            </div>

            <div class="space-y-1.5 text-sm text-base-content/70">
              <div class="flex items-center gap-2">
                <.icon name="hero-calendar-days" class="size-4 shrink-0 text-primary" />
                <span>{Calendar.strftime(event.starts_at, "%B %d, %Y")}</span>
              </div>
              <div :if={event.venue} class="flex items-center gap-2">
                <.icon name="hero-map-pin" class="size-4 shrink-0 text-primary" />
                <span class="truncate">{event.venue}</span>
              </div>
            </div>

            <div class="pt-2">
              <.link
                navigate={~p"/events/#{event.slug}"}
                class="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-content shadow-sm hover:brightness-110 active:scale-95 transition-all duration-150"
              >
                <.icon name="hero-ticket" class="size-4" /> Ver Ingressos
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
    events = Events.list_published_events()

    socket =
      socket
      |> assign(:page_title, "Events")
      |> stream(:events, events)

    {:ok, socket}
  end
end
