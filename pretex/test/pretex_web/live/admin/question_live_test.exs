defmodule PretexWeb.Admin.QuestionLiveTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Pretex.Catalog
  alias Pretex.Events
  alias Pretex.Organizations

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp org_fixture(attrs \\ %{}) do
    {:ok, org} =
      attrs
      |> Enum.into(%{name: "Test Org", slug: "test-org-#{System.unique_integer([:positive])}"})
      |> Organizations.create_organization()

    org
  end

  defp event_fixture(org, attrs \\ %{}) do
    base = %{
      name: "Test Event #{System.unique_integer([:positive])}",
      starts_at: ~U[2030-06-01 10:00:00Z],
      ends_at: ~U[2030-06-01 18:00:00Z],
      venue: "Main Stage"
    }

    {:ok, event} = Events.create_event(org, Enum.into(attrs, base))
    event
  end

  defp item_fixture(event, attrs \\ %{}) do
    base = %{
      name: "Test Item #{System.unique_integer([:positive])}",
      price_cents: 1000,
      item_type: "ticket",
      status: "active"
    }

    {:ok, item} = Catalog.create_item(event, Enum.into(attrs, base))
    item
  end

  defp question_fixture(event, attrs \\ %{}) do
    base = %{
      label: "Test Question #{System.unique_integer([:positive])}",
      question_type: "text"
    }

    {:ok, question} = Catalog.create_question(event, Enum.into(attrs, base))
    question
  end

  # ---------------------------------------------------------------------------
  # Index — listing questions
  # ---------------------------------------------------------------------------

  describe "Index - listing questions" do
    setup :register_and_log_in_user

    test "renders the questions page for an event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Summer Festival"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert html =~ "Attendee Questions"
      assert html =~ "Summer Festival"
    end

    test "shows empty state when no questions exist", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert html =~ "No questions yet"
    end

    test "lists questions for the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "What is your diet?"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert html =~ question.label
    end

    test "does not show questions from other events", %{conn: conn} do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      question = question_fixture(event1, %{label: "Other Event Question"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event2}/questions")

      refute html =~ question.label
    end

    test "shows question type badge", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _question = question_fixture(event, %{question_type: "number"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert html =~ "number"
    end

    test "shows required badge for required questions", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      _question = question_fixture(event, %{label: "Required Q", is_required: true})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert html =~ "Required"
    end

    test "shows New Question button", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert has_element?(view, "a", "New Question")
    end

    test "shows back link to the event", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}\"]"
             )
    end

    test "shows attendee fields link", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}/questions/attendee-fields\"]"
             )
    end

    test "shows edit link for each question", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "Editable Question"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}/questions/#{question.id}/edit\"]"
             )
    end

    test "shows delete button for each question", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "Deletable Question"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert has_element?(view, "#delete-#{question.id}")
    end

    test "shows options count for choice questions", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{question_type: "single_choice"})
      {:ok, _} = Catalog.create_question_option(question, %{label: "Option A"})
      {:ok, _} = Catalog.create_question_option(question, %{label: "Option B"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert html =~ "Options"
    end
  end

  # ---------------------------------------------------------------------------
  # New question via modal
  # ---------------------------------------------------------------------------

  describe "New question modal" do
    setup :register_and_log_in_user

    test "navigating to /questions/new opens the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      assert has_element?(view, "#question-modal")
      assert render(view) =~ "New Question"
    end

    test "shows the question form inside the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      assert has_element?(view, "#question-form")
    end

    test "shows validation error when label is blank", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      view
      |> form("#question-form", question: %{label: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "shows validation error when label is too short", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      view
      |> form("#question-form", question: %{label: "X"})
      |> render_change()

      assert render(view) =~ "should be at least 2 character"
    end

    test "creates question (text type) and closes modal on valid submit", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      view
      |> form("#question-form", question: %{label: "What is your name?", question_type: "text"})
      |> render_submit()

      html = render(view)
      assert html =~ "Question created successfully"
      assert html =~ "What is your name?"
      refute has_element?(view, "#question-modal")
    end

    test "creates a number type question", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      view
      |> form("#question-form", question: %{label: "How old are you?", question_type: "number"})
      |> render_submit()

      html = render(view)
      assert html =~ "Question created successfully"
      assert html =~ "How old are you?"
    end

    test "creates a single_choice question with options section visible", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      view
      |> form("#question-form", question: %{label: "Shirt size?", question_type: "single_choice"})
      |> render_change()

      assert has_element?(view, "#options-section")
    end

    test "add_option event adds an option row to the form", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      view
      |> form("#question-form", question: %{label: "Shirt size?", question_type: "single_choice"})
      |> render_change()

      view |> element("button[phx-click=\"add_option\"]") |> render_click()

      assert render(view) =~ "option-row-0"
    end

    test "remove_option event removes the option row", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      view
      |> form("#question-form", question: %{label: "Shirt size?", question_type: "single_choice"})
      |> render_change()

      view |> element("button[phx-click=\"add_option\"]") |> render_click()
      assert render(view) =~ "option-row-0"

      view |> element("button[phx-click=\"remove_option\"]") |> render_click()
      refute render(view) =~ "option-row-0"
    end

    test "clicking Cancel closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      assert has_element?(view, "#question-modal")

      view
      |> element("button[phx-click=\"close_modal\"].btn-ghost.btn-sm:not(.btn-circle)")
      |> render_click()

      refute has_element?(view, "#question-modal")
    end

    test "clicking X button closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      assert has_element?(view, "#question-modal")

      view
      |> element("button[phx-click=\"close_modal\"].btn-circle")
      |> render_click()

      refute has_element?(view, "#question-modal")
    end

    test "newly created question appears in the stream after save", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/new")

      view
      |> form("#question-form", question: %{label: "Brand New Question", question_type: "text"})
      |> render_submit()

      assert render(view) =~ "Brand New Question"
    end
  end

  # ---------------------------------------------------------------------------
  # Edit question via modal
  # ---------------------------------------------------------------------------

  describe "Edit question modal" do
    setup :register_and_log_in_user

    test "navigating to /questions/:id/edit opens modal pre-filled", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "Editable Question", question_type: "text"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/#{question.id}/edit")

      assert has_element?(view, "#question-modal")
      assert html =~ "Edit Question"
      assert html =~ "Editable Question"
    end

    test "shows the question form pre-filled with current values", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "Pre-filled Question"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/#{question.id}/edit")

      assert html =~ "Pre-filled Question"
    end

    test "saves changes and updates the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "Old Question Label"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/#{question.id}/edit")

      view
      |> form("#question-form",
        question: %{label: "Updated Question Label", question_type: "number"}
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Question updated successfully"
      assert html =~ "Updated Question Label"
      refute has_element?(view, "#question-modal")
    end

    test "shows validation errors on invalid update", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/#{question.id}/edit")

      view
      |> form("#question-form", question: %{label: ""})
      |> render_change()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "existing options are listed in the edit form for choice questions", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      question =
        question_fixture(event, %{label: "Choice Q", question_type: "single_choice"})

      {:ok, _} = Catalog.create_question_option(question, %{label: "Alpha"})
      {:ok, _} = Catalog.create_question_option(question, %{label: "Beta"})

      {:ok, _view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/#{question.id}/edit")

      assert html =~ "Alpha"
      assert html =~ "Beta"
    end

    test "cancelling edit closes the modal", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions/#{question.id}/edit")

      assert has_element?(view, "#question-modal")

      view
      |> element("button[phx-click=\"close_modal\"].btn-ghost.btn-sm:not(.btn-circle)")
      |> render_click()

      refute has_element?(view, "#question-modal")
    end
  end

  # ---------------------------------------------------------------------------
  # Delete question
  # ---------------------------------------------------------------------------

  describe "Delete question" do
    setup :register_and_log_in_user

    test "removes the question from the stream", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "To Be Deleted"})

      {:ok, view, html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      assert html =~ question.label

      view
      |> element("#delete-#{question.id}")
      |> render_click()

      html = render(view)
      assert html =~ "Question deleted"
      refute html =~ question.label
    end

    test "shows empty state after deleting the only question", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "Only Question"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      view
      |> element("#delete-#{question.id}")
      |> render_click()

      assert render(view) =~ "No questions yet"
    end

    test "can delete a question that has options", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "Choice Q", question_type: "single_choice"})
      {:ok, _} = Catalog.create_question_option(question, %{label: "Opt A"})

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      view
      |> element("#delete-#{question.id}")
      |> render_click()

      assert render(view) =~ "Question deleted"
    end

    test "can delete a question scoped to an item", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "Scoped Q"})
      item = item_fixture(event)
      Catalog.scope_question_to_item(question, item)

      {:ok, view, _html} =
        live(conn, ~p"/admin/organizations/#{org}/events/#{event}/questions")

      view
      |> element("#delete-#{question.id}")
      |> render_click()

      assert render(view) =~ "Question deleted"
    end
  end

  # ---------------------------------------------------------------------------
  # AttendeeFields page
  # ---------------------------------------------------------------------------

  describe "AttendeeFields page" do
    setup :register_and_log_in_user

    test "renders the attendee fields page", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org, %{name: "Fields Event"})

      {:ok, _view, html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/questions/attendee-fields"
        )

      assert html =~ "Attendee Fields"
      assert html =~ "Fields Event"
    end

    test "shows all built-in field names", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/questions/attendee-fields"
        )

      assert html =~ "name"
      assert html =~ "email"
      assert html =~ "company"
      assert html =~ "phone"
      assert html =~ "address"
      assert html =~ "birth_date"
    end

    test "shows name and email as always-shown", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/questions/attendee-fields"
        )

      assert html =~ "Always shown"
    end

    test "shows back link to questions page", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/questions/attendee-fields"
        )

      assert has_element?(
               view,
               "a[href=\"/admin/organizations/#{org.id}/events/#{event.id}/questions\"]"
             )
    end

    test "shows enabled and required toggles for each field", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/questions/attendee-fields"
        )

      assert html =~ "Enabled"
      assert html =~ "Required"
    end

    test "toggling a non-protected field's enabled state updates the page", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/questions/attendee-fields"
        )

      view
      |> element("#field-company input[phx-click=\"toggle_enabled\"]")
      |> render_click()

      html = render(view)
      assert html =~ "company"
    end

    test "toggling required state for a field updates the page", %{conn: conn} do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/admin/organizations/#{org}/events/#{event}/questions/attendee-fields"
        )

      view
      |> element("#field-company input[phx-click=\"toggle_required\"]")
      |> render_click()

      html = render(view)
      assert html =~ "company"
    end
  end
end
