defmodule PretexWeb.CustomerLive.Memberships do
  use PretexWeb, :live_view

  alias Pretex.Memberships

  @impl true
  def render(assigns) do
    ~H"""
    <.customer_layout current_scope={@current_scope} current_path="/account/memberships" flash={@flash}>
      <div class="mx-auto max-w-3xl">
        <div class="mb-8">
          <h1 class="text-2xl font-bold tracking-tight text-base-content">Minhas Associações</h1>
          <p class="mt-1 text-sm text-base-content/60">
            Associações ativas e seus benefícios.
          </p>
        </div>

        <div :if={@memberships == []} class="text-center py-20 space-y-6">
          <div class="flex justify-center">
            <div class="rounded-full bg-base-200 p-6">
              <.icon name="hero-identification" class="size-16 text-base-content/40" />
            </div>
          </div>

          <div class="space-y-2">
            <h2 class="text-xl font-semibold text-base-content">
              Você ainda não possui associações
            </h2>
            <p class="text-base text-base-content/60 max-w-sm mx-auto">
              Associações oferecem descontos automáticos e acesso exclusivo a itens nos eventos.
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

        <div :if={@memberships != []} id="memberships-list" class="space-y-4">
          <div
            :for={membership <- @memberships}
            id={"membership-#{membership.id}"}
            class="rounded-2xl border border-base-200 bg-base-100 shadow-sm overflow-hidden"
          >
            <%!-- Cabeçalho do card --%>
            <div class="flex items-center justify-between px-5 py-4 border-b border-base-200 bg-base-200/30">
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                  <.icon name="hero-identification" class="size-5 text-primary" />
                </div>
                <div>
                  <p class="font-semibold text-base-content">
                    {membership.membership_type.name}
                  </p>
                  <p
                    :if={membership.membership_type.description}
                    class="text-xs text-base-content/50 mt-0.5"
                  >
                    {membership.membership_type.description}
                  </p>
                </div>
              </div>

              <%= cond do %>
                <% expired?(membership) -> %>
                  <span class="badge badge-error badge-sm font-semibold">Expirado</span>
                <% membership.status == "active" -> %>
                  <span class="badge badge-success badge-sm font-semibold">Ativo</span>
                <% true -> %>
                  <span class="badge badge-ghost badge-sm font-semibold">
                    {String.capitalize(membership.status)}
                  </span>
              <% end %>
            </div>

            <%!-- Corpo do card --%>
            <div class="px-5 py-4 space-y-4">
              <%!-- Validade --%>
              <div class="flex items-center gap-3 text-sm">
                <.icon name="hero-calendar-days" class="size-4 text-primary shrink-0" />
                <div>
                  <span class="text-base-content/60">Válido de </span>
                  <span class="font-medium text-base-content">
                    {format_date(membership.starts_at)}
                  </span>
                  <span class="text-base-content/60"> até </span>
                  <span class={[
                    "font-medium",
                    expired?(membership) && "text-error",
                    !expired?(membership) && "text-base-content"
                  ]}>
                    {format_date(membership.expires_at)}
                  </span>
                </div>
              </div>

              <%!-- Benefícios --%>
              <div :if={membership.membership_type.benefits != []}>
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
                  Benefícios
                </p>
                <div class="space-y-1.5">
                  <div
                    :for={benefit <- membership.membership_type.benefits}
                    class="flex items-center gap-2 text-sm"
                  >
                    <.icon name="hero-check-circle" class="size-4 text-success shrink-0" />
                    <span class="text-base-content">{benefit_description(benefit)}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.customer_layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Minhas Associações")}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    customer = socket.assigns.current_scope.customer
    memberships = Memberships.list_active_memberships(customer)
    {:noreply, assign(socket, :memberships, memberships)}
  end

  defp expired?(%{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y")
  defp format_date(_), do: "—"

  defp benefit_description(%{benefit_type: "percentage_discount", value: v}) when is_integer(v) do
    whole = div(v, 100)
    frac = rem(v, 100)
    "#{whole},#{String.pad_leading(to_string(frac), 2, "0")}% de desconto automático nos pedidos"
  end

  defp benefit_description(%{benefit_type: "fixed_discount", value: v}) when is_integer(v) do
    whole = div(v, 100)
    frac = rem(v, 100)
    "R$ #{whole},#{String.pad_leading(to_string(frac), 2, "0")} de desconto fixo nos pedidos"
  end

  defp benefit_description(%{benefit_type: "item_access"}),
    do: "Acesso a itens exclusivos para membros"

  defp benefit_description(_), do: "Benefício especial"
end
