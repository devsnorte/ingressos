defmodule PretexWeb.Admin.PaymentLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Organizations
  alias Pretex.Payments

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"org_id" => org_id} = params, _uri, socket) do
    org = Organizations.get_organization!(org_id)
    providers = Payments.list_providers(org.id)
    available = Payments.available_providers()

    socket =
      socket
      |> assign(:org, org)
      |> assign(:providers, providers)
      |> assign(:available_providers, available)
      |> assign(:page_title, "Provedores de Pagamento")
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params), do: assign(socket, :selected_type, nil)

  defp apply_action(socket, :select, _params) do
    assign(socket, :selected_type, nil)
  end

  defp apply_action(socket, :new, %{"type" => type}) do
    provider_info = Enum.find(socket.assigns.available_providers, &(&1.type == type))

    socket
    |> assign(:selected_type, type)
    |> assign(:provider_info, provider_info)
    |> assign(
      :form,
      to_form(%{"name" => provider_info.display_name, "credentials" => %{}}, as: "provider")
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    provider = Payments.get_provider!(id)
    provider_info = Enum.find(socket.assigns.available_providers, &(&1.type == provider.type))
    masked = Payments.mask_credentials(provider)

    socket
    |> assign(:provider, provider)
    |> assign(:provider_info, provider_info)
    |> assign(:selected_type, provider.type)
    |> assign(:form, to_form(%{"name" => provider.name, "credentials" => masked}, as: "provider"))
  end

  defp apply_action(socket, _, _params), do: socket

  @impl true
  def handle_event("validate", %{"provider" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: "provider"))}
  end

  @impl true
  def handle_event("save", %{"provider" => params}, socket) do
    case socket.assigns.live_action do
      :new -> save_provider(socket, params)
      :edit -> update_provider(socket, params)
    end
  end

  @impl true
  def handle_event("validate_provider", %{"id" => id}, socket) do
    provider = Payments.get_provider!(id)

    case Payments.validate_provider(provider) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:providers, Payments.list_providers(socket.assigns.org.id))
         |> put_flash(:info, "Provedor \"#{updated.name}\" validado com sucesso!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:providers, Payments.list_providers(socket.assigns.org.id))
         |> put_flash(:error, "Falha na validação: #{reason}")}
    end
  end

  @impl true
  def handle_event("set_default", %{"id" => id}, socket) do
    provider = Payments.get_provider!(id)

    case Payments.set_default_provider(provider) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:providers, Payments.list_providers(socket.assigns.org.id))
         |> put_flash(:info, "\"#{provider.name}\" definido como padrão.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível definir como padrão.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    provider = Payments.get_provider!(id)
    {:ok, _} = Payments.delete_provider(provider)

    {:noreply,
     socket
     |> assign(:providers, Payments.list_providers(socket.assigns.org.id))
     |> put_flash(:info, "Provedor \"#{provider.name}\" removido.")}
  end

  defp save_provider(socket, params) do
    org = socket.assigns.org
    type = socket.assigns.selected_type

    attrs = %{
      organization_id: org.id,
      type: type,
      name: params["name"],
      credentials: params["credentials"] || %{}
    }

    case Payments.create_provider(attrs) do
      {:ok, _provider} ->
        {:noreply,
         socket
         |> put_flash(:info, "Provedor adicionado com sucesso!")
         |> push_patch(to: ~p"/admin/organizations/#{org}/payments")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset_to_params(changeset), as: "provider"))}
    end
  end

  defp update_provider(socket, params) do
    provider = socket.assigns.provider
    org = socket.assigns.org

    # Only update credentials if they changed (not masked values)
    credentials = params["credentials"] || %{}
    clean_creds = Map.reject(credentials, fn {_k, v} -> String.starts_with?(v || "", "••••") end)

    update_attrs =
      %{name: params["name"]}
      |> then(fn attrs ->
        if map_size(clean_creds) > 0 do
          # Merge new creds with existing ones
          existing = provider.credentials || %{}
          Map.put(attrs, :credentials, Map.merge(existing, clean_creds))
        else
          attrs
        end
      end)

    case Payments.update_provider(provider, update_attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Provedor atualizado com sucesso!")
         |> push_patch(to: ~p"/admin/organizations/#{org}/payments")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset_to_params(changeset), as: "provider"))}
    end
  end

  defp changeset_to_params(%Ecto.Changeset{changes: changes}) do
    Map.new(changes, fn {k, v} -> {to_string(k), v} end)
  end
end
