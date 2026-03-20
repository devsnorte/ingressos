defmodule PretexWeb.Admin.FeeLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Fees
  alias Pretex.Fees.FeeRule
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    fee_rules = Fees.list_fee_rules(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:page_title, "Taxas e Cobranças — #{event.name}")
      |> stream(:fee_rules, fee_rules)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Taxas e Cobranças — #{socket.assigns.event.name}")
    |> assign(:fee_rule, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nova Taxa")
    |> assign(:fee_rule, %FeeRule{})
    |> assign(:form, to_form(Fees.change_fee_rule(%FeeRule{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    fee_rule = Fees.get_fee_rule!(id)

    socket
    |> assign(:page_title, "Editar Taxa")
    |> assign(:fee_rule, fee_rule)
    |> assign(:form, to_form(Fees.change_fee_rule(fee_rule)))
  end

  @impl true
  def handle_event("validate", %{"fee_rule" => params}, socket) do
    changeset =
      socket.assigns.fee_rule
      |> Fees.change_fee_rule(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"fee_rule" => params}, socket) do
    case socket.assigns.live_action do
      :new -> do_create(socket, params)
      :edit -> do_update(socket, params)
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    fee_rule = Fees.get_fee_rule!(id)

    case Fees.delete_fee_rule(fee_rule) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxa removida com sucesso.")
         |> stream_delete(:fee_rules, fee_rule)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover a taxa.")}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    fee_rule = Fees.get_fee_rule!(id)
    new_active = !fee_rule.active

    case Fees.update_fee_rule(fee_rule, %{active: new_active}) do
      {:ok, updated} ->
        {:noreply, stream_insert(socket, :fee_rules, updated)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível alterar o status da taxa.")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    org = socket.assigns.org
    event = socket.assigns.event

    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/events/#{event}/fees")}
  end

  defp do_create(socket, params) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Fees.create_fee_rule(event, params) do
      {:ok, fee_rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxa criada com sucesso.")
         |> stream_insert(:fee_rules, fee_rule)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/fees")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    fee_rule = socket.assigns.fee_rule
    org = socket.assigns.org
    event = socket.assigns.event

    case Fees.update_fee_rule(fee_rule, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxa atualizada com sucesso.")
         |> stream_insert(:fee_rules, updated)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/fees")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
