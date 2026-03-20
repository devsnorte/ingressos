defmodule Pretex.Catalog do
  @moduledoc "Manages the item and product catalog for events."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Catalog.Item
  alias Pretex.Catalog.ItemCategory
  alias Pretex.Catalog.ItemVariation
  alias Pretex.Catalog.Bundle
  alias Pretex.Catalog.AddonAssignment
  alias Pretex.Catalog.Quota
  alias Pretex.Catalog.QuotaItem
  alias Pretex.Catalog.Question
  alias Pretex.Catalog.QuestionOption
  alias Pretex.Catalog.AttendeeFieldConfig
  alias Pretex.Events.Event

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  def list_categories(%Event{id: event_id}) do
    ItemCategory
    |> where([c], c.event_id == ^event_id)
    |> order_by([c], asc: c.position)
    |> Repo.all()
  end

  def get_category!(id), do: Repo.get!(ItemCategory, id)

  def create_category(%Event{} = event, attrs) do
    %ItemCategory{}
    |> ItemCategory.changeset(attrs)
    |> Ecto.Changeset.put_change(:event_id, event.id)
    |> Repo.insert()
  end

  def update_category(%ItemCategory{} = category, attrs) do
    category
    |> ItemCategory.changeset(attrs)
    |> Repo.update()
  end

  def delete_category(%ItemCategory{} = category) do
    Repo.delete(category)
  end

  def change_category(%ItemCategory{} = category, attrs \\ %{}) do
    ItemCategory.changeset(category, attrs)
  end

  # ---------------------------------------------------------------------------
  # Items
  # ---------------------------------------------------------------------------

  def count_items(%Event{id: event_id}) do
    Item
    |> where([i], i.event_id == ^event_id)
    |> Repo.aggregate(:count)
  end

  def list_items(%Event{id: event_id}) do
    Item
    |> where([i], i.event_id == ^event_id)
    |> order_by([i], asc: i.name)
    |> preload([:category, :variations])
    |> Repo.all()
  end

  def get_item!(id) do
    Item
    |> preload([:category, :variations])
    |> Repo.get!(id)
  end

  def create_item(%Event{} = event, attrs) do
    %Item{}
    |> Item.changeset(attrs)
    |> Ecto.Changeset.put_change(:event_id, event.id)
    |> Repo.insert()
  end

  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end

  def change_item(%Item{} = item, attrs \\ %{}) do
    Item.changeset(item, attrs)
  end

  # ---------------------------------------------------------------------------
  # Variations
  # ---------------------------------------------------------------------------

  def list_variations(%Item{id: item_id}) do
    ItemVariation
    |> where([v], v.item_id == ^item_id)
    |> order_by([v], asc: v.name)
    |> Repo.all()
  end

  def get_variation!(id), do: Repo.get!(ItemVariation, id)

  def create_variation(%Item{} = item, attrs) do
    %ItemVariation{}
    |> ItemVariation.changeset(attrs)
    |> Ecto.Changeset.put_change(:item_id, item.id)
    |> Repo.insert()
  end

  def update_variation(%ItemVariation{} = variation, attrs) do
    variation
    |> ItemVariation.changeset(attrs)
    |> Repo.update()
  end

  def delete_variation(%ItemVariation{} = variation) do
    Repo.delete(variation)
  end

  def change_variation(%ItemVariation{} = variation, attrs \\ %{}) do
    ItemVariation.changeset(variation, attrs)
  end

  # ---------------------------------------------------------------------------
  # Bundles
  # ---------------------------------------------------------------------------

  def list_bundles(%Event{id: event_id}) do
    Bundle
    |> where([b], b.event_id == ^event_id)
    |> order_by([b], asc: b.name)
    |> preload(:items)
    |> Repo.all()
  end

  def get_bundle!(id) do
    Bundle
    |> preload(:items)
    |> Repo.get!(id)
  end

  def create_bundle(%Event{} = event, attrs) do
    {item_ids, attrs} = Map.pop(attrs, :item_ids, Map.get(attrs, "item_ids", []))

    items =
      if item_ids != [] do
        Item
        |> where([i], i.id in ^item_ids)
        |> Repo.all()
      else
        []
      end

    %Bundle{}
    |> Bundle.changeset(attrs)
    |> Ecto.Changeset.put_change(:event_id, event.id)
    |> Ecto.Changeset.put_assoc(:items, items)
    |> Repo.insert()
  end

  def update_bundle(%Bundle{} = bundle, attrs) do
    {item_ids, attrs} =
      Map.pop(attrs, :item_ids, Map.pop(attrs, "item_ids", :not_provided) |> elem(0))

    changeset = Bundle.changeset(bundle, attrs)

    changeset =
      if item_ids != :not_provided do
        items =
          if item_ids != [] do
            Item
            |> where([i], i.id in ^item_ids)
            |> Repo.all()
          else
            []
          end

        Ecto.Changeset.put_assoc(changeset, :items, items)
      else
        changeset
      end

    Repo.update(changeset)
  end

  def delete_bundle(%Bundle{} = bundle) do
    Repo.delete(bundle)
  end

  def change_bundle(%Bundle{} = bundle, attrs \\ %{}) do
    Bundle.changeset(bundle, attrs)
  end

  # ---------------------------------------------------------------------------
  # Addon assignments
  # ---------------------------------------------------------------------------

  def list_addons_for_item(%Item{id: item_id}) do
    Item
    |> join(:inner, [i], a in AddonAssignment, on: a.item_id == i.id)
    |> where([_i, a], a.parent_item_id == ^item_id)
    |> Repo.all()
  end

  def assign_addon(%Item{} = addon_item, %Item{} = parent_item) do
    %AddonAssignment{}
    |> AddonAssignment.changeset(%{item_id: addon_item.id, parent_item_id: parent_item.id})
    |> Repo.insert()
  end

  def remove_addon(%Item{} = addon_item, %Item{} = parent_item) do
    case Repo.get_by(AddonAssignment,
           item_id: addon_item.id,
           parent_item_id: parent_item.id
         ) do
      nil -> {:error, :not_found}
      assignment -> Repo.delete(assignment)
    end
  end

  # ---------------------------------------------------------------------------
  # Quotas
  # ---------------------------------------------------------------------------

  def list_quotas(%Event{id: event_id}) do
    Quota
    |> where([q], q.event_id == ^event_id)
    |> order_by([q], asc: q.name)
    |> preload(:quota_items)
    |> Repo.all()
  end

  def get_quota!(id) do
    Quota
    |> preload([:quota_items, quota_items: [:item, :item_variation]])
    |> Repo.get!(id)
  end

  def create_quota(%Event{} = event, attrs) do
    %Quota{}
    |> Quota.changeset(attrs)
    |> Ecto.Changeset.put_change(:event_id, event.id)
    |> Repo.insert()
  end

  def update_quota(%Quota{} = quota, attrs) do
    quota
    |> Quota.changeset(attrs)
    |> Repo.update()
  end

  def delete_quota(%Quota{} = quota) do
    Repo.delete(quota)
  end

  def change_quota(%Quota{} = quota, attrs \\ %{}) do
    Quota.changeset(quota, attrs)
  end

  # ---------------------------------------------------------------------------
  # Quota item assignment
  # ---------------------------------------------------------------------------

  def assign_item_to_quota(%Quota{} = quota, %Item{} = item) do
    %QuotaItem{}
    |> QuotaItem.changeset(%{quota_id: quota.id, item_id: item.id})
    |> Repo.insert()
  end

  def assign_variation_to_quota(%Quota{} = quota, %ItemVariation{} = variation) do
    %QuotaItem{}
    |> QuotaItem.changeset(%{quota_id: quota.id, item_variation_id: variation.id})
    |> Repo.insert()
  end

  def remove_item_from_quota(%Quota{} = quota, %Item{} = item) do
    case Repo.get_by(QuotaItem, quota_id: quota.id, item_id: item.id) do
      nil -> {:error, :not_found}
      quota_item -> Repo.delete(quota_item)
    end
  end

  def remove_variation_from_quota(%Quota{} = quota, %ItemVariation{} = variation) do
    case Repo.get_by(QuotaItem, quota_id: quota.id, item_variation_id: variation.id) do
      nil -> {:error, :not_found}
      quota_item -> Repo.delete(quota_item)
    end
  end

  # ---------------------------------------------------------------------------
  # Availability
  # ---------------------------------------------------------------------------

  def available_quantity(%Quota{capacity: capacity, sold_count: sold_count}) do
    max(0, capacity - sold_count)
  end

  def sold_out?(%Quota{} = quota) do
    available_quantity(quota) == 0
  end

  # ---------------------------------------------------------------------------
  # Questions
  # ---------------------------------------------------------------------------

  def list_questions(%Event{id: event_id}) do
    Question
    |> where([q], q.event_id == ^event_id)
    |> order_by([q], asc: q.position)
    |> preload(:options)
    |> Repo.all()
  end

  def get_question!(id) do
    Question
    |> preload([:options, :scoped_items])
    |> Repo.get!(id)
  end

  def create_question(%Event{} = event, attrs) do
    %Question{}
    |> Question.changeset(attrs)
    |> Ecto.Changeset.put_change(:event_id, event.id)
    |> Repo.insert()
  end

  def update_question(%Question{} = question, attrs) do
    question
    |> Question.changeset(attrs)
    |> Repo.update()
  end

  def delete_question(%Question{} = question) do
    Repo.delete(question)
  end

  def change_question(%Question{} = question, attrs \\ %{}) do
    Question.changeset(question, attrs)
  end

  # ---------------------------------------------------------------------------
  # Question options
  # ---------------------------------------------------------------------------

  def create_question_option(%Question{} = question, attrs) do
    %QuestionOption{}
    |> QuestionOption.changeset(attrs)
    |> Ecto.Changeset.put_change(:question_id, question.id)
    |> Repo.insert()
  end

  def delete_question_option(%QuestionOption{} = option) do
    Repo.delete(option)
  end

  # ---------------------------------------------------------------------------
  # Question item scoping
  # ---------------------------------------------------------------------------

  def scope_question_to_item(%Question{} = question, %Item{} = item) do
    Repo.insert_all(
      "question_item_scopes",
      [
        %{
          question_id: question.id,
          item_id: item.id,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      ],
      on_conflict: :nothing
    )

    {:ok, question}
  end

  def unscope_question_from_item(%Question{} = question, %Item{} = item) do
    from(s in "question_item_scopes",
      where: s.question_id == ^question.id and s.item_id == ^item.id
    )
    |> Repo.delete_all()

    {:ok, question}
  end

  # ---------------------------------------------------------------------------
  # Attendee field config
  # ---------------------------------------------------------------------------

  def list_attendee_field_configs(%Event{id: event_id}) do
    AttendeeFieldConfig
    |> where([c], c.event_id == ^event_id)
    |> order_by([c], asc: c.field_name)
    |> Repo.all()
  end

  def get_or_create_attendee_field_config(%Event{} = event, field_name) do
    case Repo.get_by(AttendeeFieldConfig, event_id: event.id, field_name: field_name) do
      nil ->
        %AttendeeFieldConfig{}
        |> AttendeeFieldConfig.changeset(%{field_name: field_name})
        |> Ecto.Changeset.put_change(:event_id, event.id)
        |> Repo.insert()

      config ->
        {:ok, config}
    end
  end

  def update_attendee_field_config(%AttendeeFieldConfig{} = config, attrs) do
    config
    |> AttendeeFieldConfig.changeset(attrs)
    |> Repo.update()
  end
end
