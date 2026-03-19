defmodule PretexWeb.Admin.QuestionLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Catalog
  alias Pretex.Catalog.Question
  alias Pretex.Events
  alias Pretex.Organizations

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    questions = Catalog.list_questions(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:page_title, "Questions — #{event.name}")
      |> stream(:questions, questions)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Questions — #{socket.assigns.event.name}")
    |> assign(:question, nil)
    |> assign(:form, nil)
    |> assign(:pending_options, [])
  end

  defp apply_action(socket, :new, _params) do
    question = %Question{}

    socket
    |> assign(:page_title, "New Question")
    |> assign(:question, question)
    |> assign(:form, to_form(Catalog.change_question(question)))
    |> assign(:pending_options, [])
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    question = Catalog.get_question!(id)

    socket
    |> assign(:page_title, "Edit Question")
    |> assign(:question, question)
    |> assign(:form, to_form(Catalog.change_question(question)))
    |> assign(:pending_options, question.options)
  end

  @impl true
  def handle_event("validate", %{"question" => params}, socket) do
    changeset =
      socket.assigns.question
      |> Catalog.change_question(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"question" => params}, socket) do
    case socket.assigns.live_action do
      :new -> do_create(socket, params)
      :edit -> do_update(socket, params)
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    question = Catalog.get_question!(id)

    case Catalog.delete_question(question) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Question deleted.")
         |> stream_delete(:questions, question)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete question.")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    org = socket.assigns.org
    event = socket.assigns.event

    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/events/#{event}/questions")}
  end

  def handle_event("add_option", _params, socket) do
    new_option = %{id: nil, label: "", position: length(socket.assigns.pending_options)}
    {:noreply, assign(socket, :pending_options, socket.assigns.pending_options ++ [new_option])}
  end

  def handle_event("remove_option", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    options = List.delete_at(socket.assigns.pending_options, index)
    {:noreply, assign(socket, :pending_options, options)}
  end

  def handle_event("remove_existing_option", %{"id" => id}, socket) do
    option =
      Enum.find(socket.assigns.pending_options, fn o ->
        to_string(Map.get(o, :id)) == id
      end)

    if option && Map.get(option, :id) do
      option_struct = %Pretex.Catalog.QuestionOption{id: Map.get(option, :id)}

      case Catalog.delete_question_option(option_struct) do
        {:ok, _} ->
          remaining =
            Enum.reject(socket.assigns.pending_options, fn o ->
              to_string(Map.get(o, :id)) == id
            end)

          {:noreply, assign(socket, :pending_options, remaining)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not remove option.")}
      end
    else
      {:noreply, socket}
    end
  end

  defp do_create(socket, params) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Catalog.create_question(event, params) do
      {:ok, question} ->
        sync_options(question, socket.assigns.pending_options, params)

        question = Catalog.get_question!(question.id)

        {:noreply,
         socket
         |> put_flash(:info, "Question created successfully.")
         |> stream_insert(:questions, question)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/questions")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    question = socket.assigns.question
    org = socket.assigns.org
    event = socket.assigns.event

    case Catalog.update_question(question, params) do
      {:ok, updated} ->
        sync_options(updated, socket.assigns.pending_options, params)

        updated = Catalog.get_question!(updated.id)

        {:noreply,
         socket
         |> put_flash(:info, "Question updated successfully.")
         |> stream_insert(:questions, updated)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/questions")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp sync_options(question, pending_options, params) do
    option_labels = Map.get(params, "option_labels", %{})

    Enum.each(pending_options, fn option ->
      label =
        cond do
          is_map(option) && Map.get(option, :id) ->
            Map.get(option_labels, to_string(option.id), Map.get(option, :label, ""))

          is_map(option) ->
            idx = :erlang.phash2(option)
            Map.get(option_labels, to_string(idx), Map.get(option, :label, ""))

          true ->
            ""
        end

      if label != "" && is_nil(Map.get(option, :id)) do
        Catalog.create_question_option(question, %{
          label: label,
          position: Map.get(option, :position, 0)
        })
      end
    end)
  end

  defp type_badge_class("text"), do: "badge-info"
  defp type_badge_class("multiline"), do: "badge-info"
  defp type_badge_class("number"), do: "badge-warning"
  defp type_badge_class("yes_no"), do: "badge-success"
  defp type_badge_class("single_choice"), do: "badge-primary"
  defp type_badge_class("multiple_choice"), do: "badge-secondary"
  defp type_badge_class("file_upload"), do: "badge-accent"
  defp type_badge_class("date"), do: "badge-neutral"
  defp type_badge_class("time"), do: "badge-neutral"
  defp type_badge_class("phone"), do: "badge-ghost"
  defp type_badge_class("country"), do: "badge-ghost"
  defp type_badge_class(_), do: "badge-ghost"

  defp needs_options?(type), do: type in ["single_choice", "multiple_choice"]
end
