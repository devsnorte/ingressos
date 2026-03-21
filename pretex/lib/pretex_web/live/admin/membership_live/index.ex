defmodule PretexWeb.Admin.MembershipLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Customers
  alias Pretex.Memberships
  alias Pretex.Memberships.MembershipBenefit
  alias Pretex.Memberships.MembershipType
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    membership_types = Memberships.list_membership_types(org)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:page_title, "Associações — #{org.name}")
      |> assign(:membership_type, nil)
      |> assign(:form, nil)
      |> assign(:grant_form, nil)
      |> assign(:benefit_form, nil)
      |> stream(:membership_types, membership_types)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Associações — #{socket.assigns.org.name}")
    |> assign(:membership_type, nil)
    |> assign(:form, nil)
    |> assign(:grant_form, nil)
    |> assign(:benefit_form, nil)
  end

  defp apply_action(socket, :new, _params) do
    mt = %MembershipType{}

    socket
    |> assign(:page_title, "Nova Associação")
    |> assign(:membership_type, mt)
    |> assign(:form, to_form(Memberships.change_membership_type(mt)))
    |> assign(:grant_form, nil)
    |> assign(:benefit_form, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    mt = Memberships.get_membership_type!(id)

    socket
    |> assign(:page_title, "Editar Associação")
    |> assign(:membership_type, mt)
    |> assign(:form, to_form(Memberships.change_membership_type(mt)))
    |> assign(:grant_form, nil)
    |> assign(:benefit_form, to_form(Memberships.change_benefit(%MembershipBenefit{})))
  end

  defp apply_action(socket, :grant, %{"id" => id}) do
    mt = Memberships.get_membership_type!(id)

    socket
    |> assign(:page_title, "Conceder Associação")
    |> assign(:membership_type, mt)
    |> assign(:form, nil)
    |> assign(:grant_form, to_form(%{"email" => ""}, as: :grant))
    |> assign(:benefit_form, nil)
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate", %{"membership_type" => params}, socket) do
    changeset =
      socket.assigns.membership_type
      |> Memberships.change_membership_type(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"membership_type" => params}, socket) do
    case socket.assigns.live_action do
      :new -> do_create(socket, params)
      :edit -> do_update(socket, params)
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    mt = Memberships.get_membership_type!(id)

    case Memberships.delete_membership_type(mt) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Associação removida com sucesso.")
         |> stream_delete(:membership_types, mt)}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Não foi possível remover a associação. Pode haver membros ativos vinculados a ela."
         )}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    mt = Memberships.get_membership_type!(id)

    case Memberships.update_membership_type(mt, %{active: !mt.active}) do
      {:ok, updated} ->
        {:noreply, stream_insert(socket, :membership_types, updated)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível alterar o status da associação.")}
    end
  end

  def handle_event("validate_benefit", %{"membership_benefit" => params}, socket) do
    changeset =
      %MembershipBenefit{}
      |> Memberships.change_benefit(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :benefit_form, to_form(changeset))}
  end

  def handle_event("add_benefit", %{"membership_benefit" => params}, socket) do
    mt = socket.assigns.membership_type

    case Memberships.create_benefit(mt, params) do
      {:ok, _benefit} ->
        updated_mt = Memberships.get_membership_type!(mt.id)

        {:noreply,
         socket
         |> assign(:membership_type, updated_mt)
         |> assign(:benefit_form, to_form(Memberships.change_benefit(%MembershipBenefit{})))
         |> stream_insert(:membership_types, updated_mt)}

      {:error, changeset} ->
        {:noreply, assign(socket, :benefit_form, to_form(changeset))}
    end
  end

  def handle_event("delete_benefit", %{"id" => benefit_id}, socket) do
    mt = socket.assigns.membership_type
    benefit = Enum.find(mt.benefits, &(to_string(&1.id) == benefit_id))

    if benefit do
      case Memberships.delete_benefit(benefit) do
        {:ok, _} ->
          updated_mt = Memberships.get_membership_type!(mt.id)

          {:noreply,
           socket
           |> assign(:membership_type, updated_mt)
           |> stream_insert(:membership_types, updated_mt)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Não foi possível remover o benefício.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("grant", %{"grant" => %{"email" => email}}, socket) do
    mt = socket.assigns.membership_type
    org = socket.assigns.org

    case Customers.get_customer_by_email(email) do
      nil ->
        {:noreply,
         socket
         |> assign(:grant_form, to_form(%{"email" => email}, as: :grant))
         |> put_flash(:error, "Nenhum cliente encontrado com o e-mail #{email}.")}

      customer ->
        case Memberships.grant_membership(mt, customer, org) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Associação \"#{mt.name}\" concedida para #{email}.")
             |> push_patch(to: ~p"/admin/organizations/#{org}/memberships")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Não foi possível conceder a associação.")}
        end
    end
  end

  def handle_event("close_modal", _params, socket) do
    org = socket.assigns.org
    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/memberships")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp do_create(socket, params) do
    org = socket.assigns.org

    case Memberships.create_membership_type(org, params) do
      {:ok, mt} ->
        {:noreply,
         socket
         |> put_flash(:info, "Associação criada com sucesso.")
         |> stream_insert(:membership_types, mt)
         |> push_patch(to: ~p"/admin/organizations/#{org}/memberships")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    org = socket.assigns.org
    mt = socket.assigns.membership_type

    case Memberships.update_membership_type(mt, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Associação atualizada com sucesso.")
         |> stream_insert(:membership_types, updated)
         |> push_patch(to: ~p"/admin/organizations/#{org}/memberships")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp benefit_label("percentage_discount"), do: "Desconto %"
  defp benefit_label("fixed_discount"), do: "Desconto Fixo"
  defp benefit_label("item_access"), do: "Acesso a Item"
  defp benefit_label(type), do: type

  defp benefit_value_display(%{benefit_type: "percentage_discount", value: v}) when is_integer(v) do
    whole = div(v, 100)
    frac = rem(v, 100)
    "#{whole},#{String.pad_leading(to_string(frac), 2, "0")}%"
  end

  defp benefit_value_display(%{benefit_type: "fixed_discount", value: v}) when is_integer(v) do
    whole = div(v, 100)
    frac = rem(v, 100)
    "R$ #{whole},#{String.pad_leading(to_string(frac), 2, "0")}"
  end

  defp benefit_value_display(%{benefit_type: "item_access"}), do: "Acesso exclusivo"
  defp benefit_value_display(_), do: "—"
end
