defmodule Pretex.Events do
  @moduledoc "Manages events and their lifecycle."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Events.Event
  alias Pretex.Events.TicketType
  alias Pretex.Organizations.Organization

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
    if has_ticket_types?(event) do
      event
      |> Ecto.Changeset.change(status: "published")
      |> Repo.update()
    else
      {:error, :no_ticket_types}
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
          event
          |> ticket_types_query()
          |> Repo.all()
          |> Enum.each(fn tt ->
            %TicketType{}
            |> TicketType.changeset(%{
              name: tt.name,
              price_cents: tt.price_cents,
              quantity: tt.quantity,
              status: tt.status
            })
            |> Ecto.Changeset.put_change(:event_id, new_event.id)
            |> Repo.insert!()
          end)

          new_event

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def has_ticket_types?(%Event{id: id}) do
    Repo.exists?(from(t in TicketType, where: t.event_id == ^id and t.status == "active"))
  end

  def count_ticket_types(%Event{id: id}) do
    Repo.aggregate(from(t in TicketType, where: t.event_id == ^id), :count)
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

  defp ticket_types_query(%Event{id: id}) do
    from(t in TicketType, where: t.event_id == ^id)
  end
end
