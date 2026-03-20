defmodule PretexWeb.Admin.QuestionLive.AttendeeFields do
  use PretexWeb, :live_view

  alias Pretex.Catalog
  alias Pretex.Catalog.AttendeeFieldConfig
  alias Pretex.Events
  alias Pretex.Organizations

  @always_shown ~w(name email)

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    configs = load_configs(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:page_title, "Attendee Fields — #{event.name}")
      |> assign(:configs, configs)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_enabled", %{"field" => field_name}, socket) do
    event = socket.assigns.event

    with {:ok, config} <- Catalog.get_or_create_attendee_field_config(event, field_name) do
      new_enabled = !config.is_enabled

      new_required =
        if !new_enabled do
          false
        else
          config.is_required
        end

      case Catalog.update_attendee_field_config(config, %{
             is_enabled: new_enabled,
             is_required: new_required
           }) do
        {:ok, _} ->
          configs = load_configs(event)
          {:noreply, assign(socket, :configs, configs)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update field config.")}
      end
    end
  end

  def handle_event("toggle_required", %{"field" => field_name}, socket) do
    event = socket.assigns.event

    with {:ok, config} <- Catalog.get_or_create_attendee_field_config(event, field_name) do
      case Catalog.update_attendee_field_config(config, %{is_required: !config.is_required}) do
        {:ok, _} ->
          configs = load_configs(event)
          {:noreply, assign(socket, :configs, configs)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update field config.")}
      end
    end
  end

  defp load_configs(event) do
    existing =
      Catalog.list_attendee_field_configs(event)
      |> Map.new(fn c -> {c.field_name, c} end)

    AttendeeFieldConfig.field_names()
    |> Enum.map(fn field_name ->
      config =
        Map.get(existing, field_name, %AttendeeFieldConfig{
          field_name: field_name,
          is_enabled: true,
          is_required: false
        })

      %{
        field_name: field_name,
        is_enabled: config.is_enabled,
        is_required: config.is_required,
        always_shown: field_name in @always_shown
      }
    end)
  end

  defp field_label("name"), do: "Nome Completo"
  defp field_label("email"), do: "Endereço de E-mail"
  defp field_label("company"), do: "Empresa / Organização"
  defp field_label("phone"), do: "Telefone"
  defp field_label("address"), do: "Endereço Postal"
  defp field_label("birth_date"), do: "Data de Nascimento"
  defp field_label(name), do: name |> String.replace("_", " ") |> String.capitalize()
end
