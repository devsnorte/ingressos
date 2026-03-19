defmodule PretexWeb.EventsLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:px-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold tracking-tight text-base-content">Upcoming Events</h1>
          <p class="mt-2 text-base text-base-content/60">
            Discover and get tickets for the best events near you.
          </p>
        </div>

        <div id="events-empty" class="hidden only:block text-center py-20">
          <div class="flex justify-center mb-4">
            <div class="rounded-full bg-base-200 p-6">
              <.icon name="hero-calendar" class="size-12 text-base-content/30" />
            </div>
          </div>
          <h2 class="text-xl font-semibold text-base-content">No events available</h2>
          <p class="mt-2 text-base-content/60">Check back later for upcoming events.</p>
        </div>

        <div
          id="events"
          phx-update="stream"
          class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3"
        >
          <div
            :for={{id, event} <- @streams.events}
            id={id}
            class="group flex flex-col rounded-2xl border border-base-200 bg-base-100 shadow-sm hover:shadow-md transition-all duration-200 overflow-hidden"
          >
            <div
              class="h-2 w-full"
              style={"background-color: #{event.primary_color || "#6366f1"}"}
            />
            <div class="flex flex-col flex-1 p-5 gap-3">
              <div class="flex-1">
                <h2 class="text-lg font-bold text-base-content group-hover:text-primary transition-colors line-clamp-2">
                  {event.name}
                </h2>
                <%= if event.organization do %>
                  <p class="mt-1 text-xs font-medium text-base-content/50 uppercase tracking-wide">
                    {event.organization.name}
                  </p>
                <% end %>
              </div>

              <div class="space-y-1.5 text-sm text-base-content/70">
                <div class="flex items-center gap-2">
                  <.icon name="hero-calendar-days" class="size-4 shrink-0 text-primary" />
                  <span>{Calendar.strftime(event.starts_at, "%B %d, %Y")}</span>
                </div>
                <%= if event.venue do %>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-map-pin" class="size-4 shrink-0 text-primary" />
                    <span class="truncate">{event.venue}</span>
                  </div>
                <% end %>
              </div>

              <div class="pt-2">
                <.link
                  navigate={~p"/events/#{event.slug}"}
                  class="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-content shadow-sm hover:brightness-110 active:scale-95 transition-all duration-150"
                >
                  <.icon name="hero-ticket" class="size-4" /> Get Tickets
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
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
