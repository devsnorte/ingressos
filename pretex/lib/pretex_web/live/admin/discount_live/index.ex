defmodule PretexWeb.Admin.DiscountLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Organizations
  alias Pretex.Discounts
  alias Pretex.Discounts.DiscountRule

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    discount_rules = Discounts.list_discount_rules(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:page_title, "Descontos Automáticos — #{event.name}")
      |> assign(:discount_rule, nil)
      |> assign(:form, nil)
      |> stream(:discount_rules, discount_rules)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Descontos Automáticos — #{socket.assigns.event.name}")
    |> assign(:discount_rule, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    rule = %DiscountRule{}

    socket
    |> assign(:page_title, "Nova Regra de Desconto")
    |> assign(:discount_rule, rule)
    |> assign(:form, to_form(Discounts.change_discount_rule(rule)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    rule = Discounts.get_discount_rule!(id)

    socket
    |> assign(:page_title, "Editar Regra de Desconto")
    |> assign(:discount_rule, rule)
    |> assign(:form, to_form(Discounts.change_discount_rule(rule)))
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate", %{"discount_rule" => params}, socket) do
    changeset =
      socket.assigns.discount_rule
      |> Discounts.change_discount_rule(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"discount_rule" => params}, socket) do
    case socket.assigns.live_action do
      :new -> do_create(socket, params)
      :edit -> do_update(socket, params)
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    rule = Discounts.get_discount_rule!(id)

    case Discounts.delete_discount_rule(rule) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Regra de desconto removida com sucesso.")
         |> stream_delete(:discount_rules, rule)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover a regra de desconto.")}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    rule = Discounts.get_discount_rule!(id)
    new_active = !rule.active

    case Discounts.update_discount_rule(rule, %{active: new_active}) do
      {:ok, updated} ->
        {:noreply, stream_insert(socket, :discount_rules, updated)}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Não foi possível alterar o status da regra de desconto.")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    org = socket.assigns.org
    event = socket.assigns.event

    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/events/#{event}/discounts")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp do_create(socket, params) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Discounts.create_discount_rule(event, params) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Regra de desconto criada com sucesso.")
         |> stream_insert(:discount_rules, rule)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/discounts")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    rule = socket.assigns.discount_rule
    event = socket.assigns.event
    org = socket.assigns.org

    case Discounts.update_discount_rule(rule, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Regra de desconto atualizada com sucesso.")
         |> stream_insert(:discount_rules, updated)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/discounts")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
