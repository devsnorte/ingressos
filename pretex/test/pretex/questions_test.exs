defmodule Pretex.QuestionsTest do
  use Pretex.DataCase, async: true

  alias Pretex.Catalog
  alias Pretex.Catalog.Question
  alias Pretex.Catalog.AttendeeFieldConfig
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
      name: "My Event #{System.unique_integer([:positive])}",
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
      label: "Question #{System.unique_integer([:positive])}",
      question_type: "text"
    }

    {:ok, question} = Catalog.create_question(event, Enum.into(attrs, base))
    question
  end

  # ---------------------------------------------------------------------------
  # list_questions/1
  # ---------------------------------------------------------------------------

  describe "list_questions/1" do
    test "returns questions ordered by position" do
      org = org_fixture()
      event = event_fixture(org)
      _q1 = question_fixture(event, %{label: "Q A", position: 2})
      _q2 = question_fixture(event, %{label: "Q B", position: 0})
      _q3 = question_fixture(event, %{label: "Q C", position: 1})

      questions = Catalog.list_questions(event)
      positions = Enum.map(questions, & &1.position)

      assert positions == Enum.sort(positions)
      assert length(questions) == 3
    end

    test "returns empty list when no questions exist" do
      org = org_fixture()
      event = event_fixture(org)

      assert Catalog.list_questions(event) == []
    end

    test "does not return questions from other events" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      question = question_fixture(event1)

      result = Catalog.list_questions(event2)
      ids = Enum.map(result, & &1.id)

      refute question.id in ids
    end

    test "preloads options" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{question_type: "single_choice"})
      {:ok, _} = Catalog.create_question_option(question, %{label: "Option A"})

      [loaded] = Catalog.list_questions(event)

      assert length(loaded.options) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # get_question!/1
  # ---------------------------------------------------------------------------

  describe "get_question!/1" do
    test "returns the question with given id" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "My Question", question_type: "number"})

      found = Catalog.get_question!(question.id)

      assert found.id == question.id
      assert found.label == "My Question"
      assert found.question_type == "number"
    end

    test "preloads options" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{question_type: "multiple_choice"})
      {:ok, _} = Catalog.create_question_option(question, %{label: "Choice 1"})
      {:ok, _} = Catalog.create_question_option(question, %{label: "Choice 2"})

      found = Catalog.get_question!(question.id)

      assert length(found.options) == 2
    end

    test "preloads scoped_items" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)
      item = item_fixture(event)
      Catalog.scope_question_to_item(question, item)

      found = Catalog.get_question!(question.id)

      assert length(found.scoped_items) == 1
      assert hd(found.scoped_items).id == item.id
    end

    test "raises Ecto.NoResultsError for missing id" do
      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_question!(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_question/2
  # ---------------------------------------------------------------------------

  describe "create_question/2" do
    test "with valid attrs creates a question" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, question} =
               Catalog.create_question(event, %{label: "T-shirt size?", question_type: "text"})

      assert question.label == "T-shirt size?"
      assert question.question_type == "text"
      assert question.event_id == event.id
      assert question.is_required == false
    end

    test "sets is_required to true when provided" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, question} =
               Catalog.create_question(event, %{
                 label: "Diet restrictions",
                 question_type: "text",
                 is_required: true
               })

      assert question.is_required == true
    end

    test "missing label returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_question(event, %{question_type: "text"})

      assert %{label: ["can't be blank"]} = errors_on(changeset)
    end

    test "missing question_type returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_question(event, %{label: "Some question"})

      assert %{question_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid question_type returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_question(event, %{
                 label: "Some question",
                 question_type: "invalid_type"
               })

      assert %{question_type: [msg]} = errors_on(changeset)
      assert msg =~ "is invalid"
    end

    test "label too short returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.create_question(event, %{label: "X", question_type: "text"})

      assert %{label: [msg]} = errors_on(changeset)
      assert msg =~ "should be at least 2 character"
    end

    test "label too long returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      long_label = String.duplicate("a", 256)

      assert {:error, changeset} =
               Catalog.create_question(event, %{label: long_label, question_type: "text"})

      assert %{label: [msg]} = errors_on(changeset)
      assert msg =~ "should be at most 255 character"
    end

    test "accepts all valid question types" do
      org = org_fixture()
      event = event_fixture(org)

      for type <- Question.question_types() do
        assert {:ok, _question} =
                 Catalog.create_question(event, %{
                   label: "Question for #{type}",
                   question_type: type
                 })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # update_question/2
  # ---------------------------------------------------------------------------

  describe "update_question/2" do
    test "with valid attrs updates the question" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{label: "Old Label", question_type: "text"})

      assert {:ok, updated} =
               Catalog.update_question(question, %{
                 label: "New Label",
                 question_type: "number"
               })

      assert updated.label == "New Label"
      assert updated.question_type == "number"
    end

    test "can update is_required" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{is_required: false})

      assert {:ok, updated} = Catalog.update_question(question, %{is_required: true})
      assert updated.is_required == true
    end

    test "with invalid attrs returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)

      assert {:error, changeset} = Catalog.update_question(question, %{label: ""})
      assert %{label: ["can't be blank"]} = errors_on(changeset)
    end

    test "with invalid question_type returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)

      assert {:error, changeset} =
               Catalog.update_question(question, %{question_type: "bogus"})

      assert %{question_type: [msg]} = errors_on(changeset)
      assert msg =~ "is invalid"
    end
  end

  # ---------------------------------------------------------------------------
  # delete_question/1
  # ---------------------------------------------------------------------------

  describe "delete_question/1" do
    test "deletes the question" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)

      assert {:ok, _} = Catalog.delete_question(question)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_question!(question.id) end
    end

    test "deleting question cascades to options" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{question_type: "single_choice"})
      {:ok, _} = Catalog.create_question_option(question, %{label: "Option A"})

      assert {:ok, _} = Catalog.delete_question(question)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_question!(question.id) end
    end
  end

  # ---------------------------------------------------------------------------
  # change_question/2
  # ---------------------------------------------------------------------------

  describe "change_question/2" do
    test "returns a changeset" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)

      assert %Ecto.Changeset{} = Catalog.change_question(question)
    end

    test "returns a changeset for empty struct" do
      assert %Ecto.Changeset{} = Catalog.change_question(%Question{})
    end

    test "accepts attrs as second argument" do
      assert %Ecto.Changeset{} =
               Catalog.change_question(%Question{}, %{label: "Hello", question_type: "text"})
    end
  end

  # ---------------------------------------------------------------------------
  # create_question_option/2
  # ---------------------------------------------------------------------------

  describe "create_question_option/2" do
    test "creates an option linked to the question" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{question_type: "single_choice"})

      assert {:ok, option} =
               Catalog.create_question_option(question, %{label: "Option A", position: 0})

      assert option.label == "Option A"
      assert option.question_id == question.id
    end

    test "missing label returns error changeset" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{question_type: "single_choice"})

      assert {:error, changeset} = Catalog.create_question_option(question, %{})
      assert %{label: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows multiple options for the same question" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{question_type: "multiple_choice"})

      {:ok, _} = Catalog.create_question_option(question, %{label: "Red", position: 0})
      {:ok, _} = Catalog.create_question_option(question, %{label: "Blue", position: 1})

      loaded = Catalog.get_question!(question.id)
      assert length(loaded.options) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # delete_question_option/1
  # ---------------------------------------------------------------------------

  describe "delete_question_option/1" do
    test "removes the option" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{question_type: "single_choice"})
      {:ok, option} = Catalog.create_question_option(question, %{label: "Choice"})

      assert {:ok, _} = Catalog.delete_question_option(option)

      loaded = Catalog.get_question!(question.id)
      assert loaded.options == []
    end

    test "deleting one option does not affect others" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event, %{question_type: "multiple_choice"})
      {:ok, option1} = Catalog.create_question_option(question, %{label: "A", position: 0})
      {:ok, _option2} = Catalog.create_question_option(question, %{label: "B", position: 1})

      assert {:ok, _} = Catalog.delete_question_option(option1)

      loaded = Catalog.get_question!(question.id)
      assert length(loaded.options) == 1
      assert hd(loaded.options).label == "B"
    end
  end

  # ---------------------------------------------------------------------------
  # scope_question_to_item/2
  # ---------------------------------------------------------------------------

  describe "scope_question_to_item/2" do
    test "links a question to an item" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)
      item = item_fixture(event)

      assert {:ok, _} = Catalog.scope_question_to_item(question, item)

      loaded = Catalog.get_question!(question.id)
      assert length(loaded.scoped_items) == 1
      assert hd(loaded.scoped_items).id == item.id
    end

    test "is idempotent — scoping again does not raise" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)
      item = item_fixture(event)

      assert {:ok, _} = Catalog.scope_question_to_item(question, item)
      assert {:ok, _} = Catalog.scope_question_to_item(question, item)

      loaded = Catalog.get_question!(question.id)
      assert length(loaded.scoped_items) == 1
    end

    test "can scope the same question to multiple items" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)
      item1 = item_fixture(event)
      item2 = item_fixture(event)

      {:ok, _} = Catalog.scope_question_to_item(question, item1)
      {:ok, _} = Catalog.scope_question_to_item(question, item2)

      loaded = Catalog.get_question!(question.id)
      assert length(loaded.scoped_items) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # unscope_question_from_item/2
  # ---------------------------------------------------------------------------

  describe "unscope_question_from_item/2" do
    test "removes the scope link" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)
      item = item_fixture(event)
      Catalog.scope_question_to_item(question, item)

      assert {:ok, _} = Catalog.unscope_question_from_item(question, item)

      loaded = Catalog.get_question!(question.id)
      assert loaded.scoped_items == []
    end

    test "is safe when no scope exists" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)
      item = item_fixture(event)

      assert {:ok, _} = Catalog.unscope_question_from_item(question, item)
    end

    test "does not remove other scope links" do
      org = org_fixture()
      event = event_fixture(org)
      question = question_fixture(event)
      item1 = item_fixture(event)
      item2 = item_fixture(event)
      Catalog.scope_question_to_item(question, item1)
      Catalog.scope_question_to_item(question, item2)

      {:ok, _} = Catalog.unscope_question_from_item(question, item1)

      loaded = Catalog.get_question!(question.id)
      assert length(loaded.scoped_items) == 1
      assert hd(loaded.scoped_items).id == item2.id
    end
  end

  # ---------------------------------------------------------------------------
  # get_or_create_attendee_field_config/2
  # ---------------------------------------------------------------------------

  describe "get_or_create_attendee_field_config/2" do
    test "creates a config if none exists" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, config} =
               Catalog.get_or_create_attendee_field_config(event, "company")

      assert config.field_name == "company"
      assert config.event_id == event.id
      assert config.is_enabled == true
      assert config.is_required == false
    end

    test "returns existing config if already present" do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, first} = Catalog.get_or_create_attendee_field_config(event, "phone")
      {:ok, second} = Catalog.get_or_create_attendee_field_config(event, "phone")

      assert first.id == second.id
    end

    test "rejects invalid field names" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Catalog.get_or_create_attendee_field_config(event, "invalid_field")

      assert %{field_name: [msg]} = errors_on(changeset)
      assert msg =~ "is invalid"
    end

    test "accepts all valid field names" do
      org = org_fixture()
      event = event_fixture(org)

      for field_name <- AttendeeFieldConfig.field_names() do
        assert {:ok, _} = Catalog.get_or_create_attendee_field_config(event, field_name)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # update_attendee_field_config/2
  # ---------------------------------------------------------------------------

  describe "update_attendee_field_config/2" do
    test "can toggle is_enabled" do
      org = org_fixture()
      event = event_fixture(org)
      {:ok, config} = Catalog.get_or_create_attendee_field_config(event, "company")

      assert {:ok, updated} =
               Catalog.update_attendee_field_config(config, %{is_enabled: false})

      assert updated.is_enabled == false
    end

    test "can toggle is_required" do
      org = org_fixture()
      event = event_fixture(org)
      {:ok, config} = Catalog.get_or_create_attendee_field_config(event, "company")

      assert {:ok, updated} =
               Catalog.update_attendee_field_config(config, %{is_required: true})

      assert updated.is_required == true
    end

    test "persists changes across fetches" do
      org = org_fixture()
      event = event_fixture(org)
      {:ok, config} = Catalog.get_or_create_attendee_field_config(event, "address")

      {:ok, _} = Catalog.update_attendee_field_config(config, %{is_enabled: false})

      {:ok, refetched} = Catalog.get_or_create_attendee_field_config(event, "address")
      assert refetched.is_enabled == false
    end
  end

  # ---------------------------------------------------------------------------
  # list_attendee_field_configs/1
  # ---------------------------------------------------------------------------

  describe "list_attendee_field_configs/1" do
    test "returns configs ordered by field_name" do
      org = org_fixture()
      event = event_fixture(org)

      {:ok, _} = Catalog.get_or_create_attendee_field_config(event, "phone")
      {:ok, _} = Catalog.get_or_create_attendee_field_config(event, "company")
      {:ok, _} = Catalog.get_or_create_attendee_field_config(event, "address")

      configs = Catalog.list_attendee_field_configs(event)
      field_names = Enum.map(configs, & &1.field_name)

      assert field_names == Enum.sort(field_names)
      assert length(configs) == 3
    end

    test "returns empty list when no configs exist" do
      org = org_fixture()
      event = event_fixture(org)

      assert Catalog.list_attendee_field_configs(event) == []
    end

    test "does not return configs from other events" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)

      {:ok, _} = Catalog.get_or_create_attendee_field_config(event1, "company")

      result = Catalog.list_attendee_field_configs(event2)
      assert result == []
    end
  end
end
