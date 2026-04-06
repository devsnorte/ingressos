defmodule PretexWeb.Admin.SeatingLive.Index do
  @moduledoc """
  Lists seating plans for an organization and allows uploading a new plan via
  JSON layout.
  """

  use PretexWeb, :live_view

  alias Pretex.Seating
  alias Pretex.Seating.SeatingPlan
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    plans = Seating.list_seating_plans(org.id)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:page_title, "Plantas de Assentos — #{org.name}")
      |> stream(:plans, plans)
      |> allow_upload(:layout,
        accept: ~w(.json),
        max_entries: 1,
        max_file_size: 1_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:form, nil)
    |> assign(:upload_error, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nova Planta de Assentos")
    |> assign(:form, to_form(Seating.change_seating_plan(%SeatingPlan{})))
    |> assign(:upload_error, nil)
  end

  @impl true
  def handle_event("validate", %{"seating_plan" => params}, socket) do
    changeset =
      %SeatingPlan{}
      |> Seating.change_seating_plan(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"seating_plan" => params}, socket) do
    org = socket.assigns.org

    case consume_layout_upload(socket) do
      {:ok, layout} ->
        attrs = Map.put(params, "layout", layout)

        case Seating.create_seating_plan(org.id, attrs) do
          {:ok, plan} ->
            {:noreply,
             socket
             |> put_flash(:info, "Planta \"#{plan.name}\" criada com sucesso.")
             |> stream_insert(:plans, plan)
             |> push_patch(to: ~p"/admin/organizations/#{org}/seating")}

          {:error, :invalid_layout} ->
            {:noreply, assign(socket, :upload_error, "O arquivo JSON tem formato inválido.")}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      {:error, message} ->
        {:noreply, assign(socket, :upload_error, message)}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :layout, ref)}
  end

  def handle_event("cancel", _params, socket) do
    org = socket.assigns.org
    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/seating")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    plan = Seating.get_seating_plan!(id)

    case Seating.delete_seating_plan(plan) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Planta removida.")
         |> stream_delete(:plans, plan)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover a planta.")}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp consume_layout_upload(socket) do
    entries = socket.assigns.uploads.layout.entries

    case entries do
      [] ->
        {:error, "Selecione um arquivo JSON de layout."}

      [_entry] ->
        result =
          consume_uploaded_entries(socket, :layout, fn %{path: path}, _entry ->
            case File.read(path) do
              {:ok, content} ->
                case Jason.decode(content) do
                  {:ok, json} -> {:ok, json}
                  {:error, _} -> {:ok, :invalid_json}
                end

              {:error, _} ->
                {:ok, :read_error}
            end
          end)

        case result do
          [:invalid_json] -> {:error, "O arquivo não é um JSON válido."}
          [:read_error] -> {:error, "Erro ao ler o arquivo."}
          [json] -> {:ok, json}
          _ -> {:error, "Erro inesperado ao processar o arquivo."}
        end
    end
  end

  defp upload_error_to_string(:too_large), do: "Arquivo muito grande (máximo 1 MB)."
  defp upload_error_to_string(:not_accepted), do: "Formato não aceito. Envie um arquivo .json."
  defp upload_error_to_string(:too_many_files), do: "Envie apenas um arquivo por vez."
  defp upload_error_to_string(_), do: "Erro ao processar o arquivo."
end
