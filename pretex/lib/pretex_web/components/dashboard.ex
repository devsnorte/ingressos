defmodule PretexWeb.Components.Dashboard do
  @moduledoc """
  Dashboard layout and navigation components.
  Pure function components — no state, no queries.
  """
  use Phoenix.Component
  import PretexWeb.CoreComponents, only: [icon: 1]
  import PretexWeb.Layouts, only: [flash_group: 1]

  # 1. dashboard_layout/1
  # Shell wrapping sidebar + content area
  # Uses daisyUI drawer with lg:drawer-open
  attr :current_path, :string, required: true
  attr :org, :map, required: true
  slot :inner_block, required: true

  def dashboard_layout(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="sidebar-toggle" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content bg-base-200 min-h-screen">
        <div class="navbar lg:hidden bg-base-100 border-b border-base-300">
          <label for="sidebar-toggle" class="btn btn-ghost btn-square">
            <.icon name="hero-bars-3" />
          </label>
          <span class="font-semibold text-base-content">{@org.display_name || @org.name}</span>
        </div>
        <div class="p-6 lg:p-8 max-w-6xl">
          {render_slot(@inner_block)}
        </div>
      </div>
      <div class="drawer-side z-40">
        <label for="sidebar-toggle" aria-label="close sidebar" class="drawer-overlay"></label>
        <.sidebar current_path={@current_path} org={@org} />
      </div>
    </div>
    """
  end

  # 2. sidebar/1
  # Logo + nav items + org name
  attr :current_path, :string, required: true
  attr :org, :map, required: true

  def sidebar(assigns) do
    nav_items = [
      %{icon: "hero-home", label: "Dashboard", path: "/admin/organizations/#{assigns.org.id}"},
      %{
        icon: "hero-calendar-days",
        label: "Events",
        path: "/admin/organizations/#{assigns.org.id}/events"
      },
      %{icon: "hero-users", label: "Teams", path: "/admin/organizations/#{assigns.org.id}/teams"},
      %{
        icon: "hero-ticket",
        label: "Catalog",
        path: "/admin/organizations/#{assigns.org.id}/catalog"
      },
      %{
        icon: "hero-rectangle-stack",
        label: "Quotas",
        path: "/admin/organizations/#{assigns.org.id}/quotas"
      },
      %{
        icon: "hero-question-mark-circle",
        label: "Questions",
        path: "/admin/organizations/#{assigns.org.id}/questions"
      },
      %{icon: "hero-chart-bar", label: "Reports", path: "#", disabled: true},
      %{icon: "hero-cog-6-tooth", label: "Settings", path: "#", disabled: true}
    ]

    assigns = assign(assigns, :nav_items, nav_items)

    ~H"""
    <aside class="bg-base-100 w-64 min-h-screen border-r border-base-300 flex flex-col">
      <div class="p-4 flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-primary flex items-center justify-center">
          <.icon name="hero-ticket" class="w-5 h-5 text-primary-content" />
        </div>
        <div>
          <div class="font-bold text-base-content text-sm">Pretex</div>
          <div class="text-xs text-base-content/50">{@org.display_name || @org.name}</div>
        </div>
      </div>

      <div class="px-4 pt-4 pb-2">
        <span class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
          Main Navigation
        </span>
      </div>

      <nav class="flex-1 flex flex-col gap-0.5 px-2">
        <.sidebar_item
          :for={item <- @nav_items}
          icon={item.icon}
          label={item.label}
          path={item.path}
          active={active?(@current_path, item.path)}
          disabled={Map.get(item, :disabled, false)}
        />
      </nav>

      <div class="p-4 mt-auto">
        <div class="rounded-xl bg-primary/5 p-4">
          <div class="text-sm font-semibold text-base-content">Need Help?</div>
          <div class="text-xs text-base-content/60 mt-1">
            Check our documentation for guides and tutorials.
          </div>
          <a href="#" class="btn btn-primary btn-sm btn-outline mt-3 w-full">View Docs</a>
        </div>
      </div>
    </aside>
    """
  end

  # 3. sidebar_item/1
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :active, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :badge, :integer, default: nil

  def sidebar_item(assigns) do
    ~H"""
    <a
      href={@path}
      class={[
        if(@disabled, do: "sidebar-item sidebar-item-disabled", else: "sidebar-item"),
        @active && "sidebar-item-active"
      ]}
    >
      <.icon name={@icon} class="w-5 h-5 shrink-0" />
      <span class="flex-1">{@label}</span>
      <span :if={@badge} class="badge badge-primary badge-sm">{@badge}</span>
    </a>
    """
  end

  # 4. breadcrumb/1
  # items: [{"Events", "/path"}, {"Manage Event", nil}]
  attr :items, :list, required: true

  def breadcrumb(assigns) do
    ~H"""
    <div class="breadcrumbs text-sm text-base-content/50">
      <ul>
        <li :for={{label, path} <- @items}>
          <a :if={path} href={path} class="hover:text-primary">{label}</a>
          <span :if={!path}>{label}</span>
        </li>
      </ul>
    </div>
    """
  end

  # 5. page_header/1
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="flex items-start justify-between gap-4 mb-6">
      <div>
        <h1 class="text-2xl font-bold text-base-content">{@title}</h1>
        <p :if={@subtitle} class="text-sm text-base-content/60 mt-1">{@subtitle}</p>
      </div>
      <div :if={@actions != []} class="flex items-center gap-2">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  # 6. step_tabs/1
  attr :steps, :list, required: true
  # steps: [%{id: :team, icon: "hero-user-group", label: "Team"}, ...]
  attr :current, :atom, required: true

  def step_tabs(assigns) do
    ~H"""
    <div class="border-b border-base-300 mb-6 overflow-x-auto">
      <div class="flex gap-0 min-w-max">
        <.step_tab
          :for={step <- @steps}
          id={step.id}
          icon={step.icon}
          label={step.label}
          state={step_state(step.id, @current, @steps)}
        />
      </div>
    </div>
    """
  end

  # 7. step_tab/1
  attr :id, :atom, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :state, :atom, required: true

  def step_tab(assigns) do
    ~H"""
    <div class={[
      "step-tab",
      @state == :active && "step-tab-active",
      @state == :completed && "step-tab-completed"
    ]}>
      <.icon
        :if={@state != :completed}
        name={@icon}
        class="w-5 h-5"
      />
      <.icon
        :if={@state == :completed}
        name="hero-check-circle-solid"
        class="w-5 h-5 text-success"
      />
      <span>{@label}</span>
    </div>
    """
  end

  # 8. item_card/1
  attr :class, :string, default: nil
  slot :leading
  slot :inner_block, required: true
  slot :trailing

  def item_card(assigns) do
    ~H"""
    <div class={["bg-base-100 rounded-xl border border-base-300 p-4 flex items-start gap-4", @class]}>
      <div :if={@leading != []} class="shrink-0">
        {render_slot(@leading)}
      </div>
      <div class="flex-1 min-w-0">
        {render_slot(@inner_block)}
      </div>
      <div :if={@trailing != []} class="shrink-0 text-right">
        {render_slot(@trailing)}
      </div>
    </div>
    """
  end

  # 9. date_badge/1
  attr :month, :string, required: true
  attr :day, :integer, required: true

  def date_badge(assigns) do
    ~H"""
    <div class="date-badge">
      <span class="date-badge-month">{@month}</span>
      <span class="date-badge-day">{@day}</span>
    </div>
    """
  end

  # 10. progress_bar/1
  attr :current, :integer, required: true
  attr :total, :integer, required: true

  def progress_bar(assigns) do
    percentage = Float.round(assigns.current / assigns.total * 100, 0) |> trunc()
    assigns = assign(assigns, :percentage, percentage)

    ~H"""
    <div class="flex items-center gap-4">
      <span class="text-sm text-base-content/60 whitespace-nowrap">Step {@current} of {@total}</span>
      <progress class="progress progress-primary flex-1" value={@percentage} max="100"></progress>
    </div>
    """
  end

  # 11. stat_card/1
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :subtitle, :string, default: nil
  attr :icon, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl border border-base-300 p-5">
      <div class="flex items-center justify-between">
        <div>
          <div class="text-sm text-base-content/50">{@title}</div>
          <div class="text-2xl font-bold text-base-content mt-1">{@value}</div>
          <div :if={@subtitle} class="text-xs text-base-content/40 mt-1">{@subtitle}</div>
        </div>
        <div :if={@icon} class="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
          <.icon name={@icon} class="w-5 h-5 text-primary" />
        </div>
      </div>
    </div>
    """
  end

  # ============================================================
  # Customer layout — clean nav for attendee-facing pages
  # ============================================================
  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: ""
  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  def customer_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <%!-- Top navbar --%>
      <nav class="navbar bg-base-100 border-b border-base-300 sticky top-0 z-30">
        <div class="container mx-auto px-4 sm:px-6 lg:px-8 flex items-center justify-between">
          <a href="/" class="flex items-center gap-2">
            <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
              <.icon name="hero-ticket" class="w-4 h-4 text-primary-content" />
            </div>
            <span class="font-bold text-base-content">Pretex</span>
          </a>

          <div class="hidden sm:flex items-center gap-6 text-sm">
            <a
              href="/events"
              class={[
                "hover:text-primary transition-colors",
                @current_path == "/events" && "text-primary font-medium"
              ]}
            >
              Eventos
            </a>
            <a
              :if={@current_scope && @current_scope.customer}
              href="/account/orders"
              class={[
                "hover:text-primary transition-colors",
                String.starts_with?(@current_path, "/account") && "text-primary font-medium"
              ]}
            >
              Minha Conta
            </a>
          </div>

          <div class="flex items-center gap-2">
            <span
              :if={@current_scope && @current_scope.customer}
              class="text-sm text-base-content/60 hidden md:inline"
            >
              {@current_scope.customer.email}
            </span>
            <a
              :if={@current_scope && @current_scope.customer}
              href="/customers/log-out"
              method="delete"
              class="btn btn-ghost btn-sm"
            >
              Sair
            </a>
            <a
              :if={!@current_scope || !@current_scope.customer}
              href="/customers/log-in"
              class="btn btn-ghost btn-sm"
            >
              Entrar
            </a>
            <a
              :if={!@current_scope || !@current_scope.customer}
              href="/customers/register"
              class="btn btn-primary btn-sm"
            >
              Criar Conta
            </a>
          </div>
        </div>
      </nav>

      <%!-- Main content --%>
      <main class="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  # Private helpers

  defp active?(current_path, item_path) do
    item_path != "#" and String.starts_with?(current_path, item_path)
  end

  defp step_state(step_id, current, steps) do
    step_ids = Enum.map(steps, & &1.id)
    current_index = Enum.find_index(step_ids, &(&1 == current))
    step_index = Enum.find_index(step_ids, &(&1 == step_id))

    cond do
      step_id == current -> :active
      step_index < current_index -> :completed
      true -> :pending
    end
  end
end
