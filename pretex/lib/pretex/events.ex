defmodule Pretex.Events do
  @moduledoc "Manages events and their lifecycle."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Events.Event
  alias Pretex.Events.SubEvent
  alias Pretex.Organizations.Organization

  def list_published_events do
    Event
    |> where([e], e.status == "published")
    |> order_by([e], asc: e.starts_at)
    |> preload(:organization)
    |> Repo.all()
  end

  def get_event_by_slug!(slug) do
    Event
    |> where([e], e.slug == ^slug and e.status == "published")
    |> preload(:organization)
    |> Repo.one!()
  end

  def list_events(%Organization{id: org_id}) do
    Event
    |> where([e], e.organization_id == ^org_id)
    |> order_by([e], desc: e.inserted_at)
    |> Repo.all()
    |> Enum.map(&maybe_auto_complete/1)
  end

  def get_event!(id) do
    Event
    |> Repo.get!(id)
    |> maybe_auto_complete()
  end

  def create_event(%Organization{} = org, attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Ecto.Changeset.put_change(:organization_id, org.id)
    |> Ecto.Changeset.put_change(:status, "draft")
    |> Repo.insert()
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  def publish_event(%Event{status: "draft"} = event) do
    if Pretex.Catalog.count_items(event) > 0 do
      event
      |> Ecto.Changeset.change(status: "published")
      |> Repo.update()
    else
      {:error, :no_catalog_items}
    end
  end

  def publish_event(_), do: {:error, :invalid_status}

  def complete_event(%Event{status: "published"} = event) do
    event
    |> Ecto.Changeset.change(status: "completed")
    |> Repo.update()
  end

  def complete_event(_), do: {:error, :invalid_status}

  def clone_event(%Event{} = event, attrs \\ %{}) do
    name = Map.get(attrs, "name", Map.get(attrs, :name, event.name <> " (copy)"))

    clone_attrs = %{
      name: name,
      description: event.description,
      starts_at: event.starts_at,
      ends_at: event.ends_at,
      venue: event.venue,
      logo_url: event.logo_url,
      banner_url: event.banner_url,
      primary_color: event.primary_color,
      accent_color: event.accent_color
    }

    org = Repo.get!(Organization, event.organization_id)

    Repo.transaction(fn ->
      case create_event(org, clone_attrs) do
        {:ok, new_event} ->
          Pretex.Catalog.list_items(event)
          |> Enum.each(fn item ->
            Pretex.Catalog.create_item(new_event, %{
              name: item.name,
              price_cents: item.price_cents,
              item_type: item.item_type,
              status: item.status
            })
          end)

          new_event

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp maybe_auto_complete(%Event{status: "published", ends_at: ends_at} = event)
       when not is_nil(ends_at) do
    if DateTime.compare(ends_at, DateTime.utc_now()) == :lt do
      case Repo.update(Ecto.Changeset.change(event, status: "completed")) do
        {:ok, updated} -> updated
        _ -> event
      end
    else
      event
    end
  end

  defp maybe_auto_complete(event), do: event

  # ---------------------------------------------------------------------------
  # Series enable/disable
  # ---------------------------------------------------------------------------

  def enable_series(%Event{} = event) do
    event
    |> Ecto.Changeset.change(is_series: true)
    |> Repo.update()
  end

  def disable_series(%Event{} = event) do
    event
    |> Ecto.Changeset.change(is_series: false)
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # SubEvent context
  # ---------------------------------------------------------------------------

  def list_sub_events(%Event{id: parent_id}) do
    SubEvent
    |> where([s], s.parent_event_id == ^parent_id)
    |> order_by([s], asc: s.inserted_at)
    |> Repo.all()
  end

  def get_sub_event!(id) do
    Repo.get!(SubEvent, id)
  end

  def create_sub_event(%Event{} = parent_event, attrs) do
    %SubEvent{}
    |> SubEvent.changeset(attrs)
    |> Ecto.Changeset.put_change(:parent_event_id, parent_event.id)
    |> Ecto.Changeset.put_change(:status, "draft")
    |> Repo.insert()
  end

  def update_sub_event(%SubEvent{} = sub_event, attrs) do
    sub_event
    |> SubEvent.changeset(attrs)
    |> Repo.update()
  end

  def delete_sub_event(%SubEvent{} = sub_event) do
    Repo.delete(sub_event)
  end

  def change_sub_event(%SubEvent{} = sub_event, attrs \\ %{}) do
    SubEvent.changeset(sub_event, attrs)
  end

  def publish_sub_event(%SubEvent{status: "draft"} = sub_event) do
    sub_event
    |> Ecto.Changeset.change(status: "published")
    |> Repo.update()
  end

  def publish_sub_event(_), do: {:error, :invalid_status}

  def hide_sub_event(%SubEvent{status: status} = sub_event) when status in ~w(draft published) do
    sub_event
    |> Ecto.Changeset.change(status: "hidden")
    |> Repo.update()
  end

  def hide_sub_event(_), do: {:error, :invalid_status}
end
