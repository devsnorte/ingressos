defmodule PretexWeb.Admin.OrganizationLive.FormComponent do
  use PretexWeb, :live_component

  alias Pretex.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
      </.header>

      <.form
        for={@form}
        id="organization-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="mt-4 space-y-4"
      >
        <.input field={@form[:name]} type="text" label="Nome" />
        <.input field={@form[:slug]} type="text" label="Slug" />
        <.input field={@form[:display_name]} type="text" label="Nome de Exibição" />
        <.input field={@form[:description]} type="textarea" label="Descrição" />
        <.input field={@form[:logo_url]} type="text" label="URL do Logo" />
        <div class="mt-6">
          <.button phx-disable-with="Salvando...">Salvar Organização</.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{organization: organization} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Organizations.change_organization(organization))
     end)}
  end

  @impl true
  def handle_event("validate", %{"organization" => organization_params}, socket) do
    changeset =
      Organizations.change_organization(socket.assigns.organization, organization_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"organization" => organization_params}, socket) do
    save_organization(socket, socket.assigns.action, organization_params)
  end

  defp save_organization(socket, :edit, organization_params) do
    case Organizations.update_organization(socket.assigns.organization, organization_params) do
      {:ok, organization} ->
        notify_parent({:saved, organization})

        {:noreply,
         socket
         |> put_flash(:info, "Organization updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_organization(socket, :new, organization_params) do
    case Organizations.create_organization(organization_params) do
      {:ok, organization} ->
        notify_parent({:saved, organization})

        {:noreply,
         socket
         |> put_flash(:info, "Organization created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
