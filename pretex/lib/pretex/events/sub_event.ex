defmodule Pretex.Events.SubEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft published hidden)

  schema "sub_events" do
    field(:name, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:starts_at, :utc_datetime)
    field(:ends_at, :utc_datetime)
    field(:venue, :string)
    field(:status, :string, default: "draft")
    field(:capacity, :integer)

    belongs_to(:parent_event, Pretex.Events.Event)

    timestamps(type: :utc_datetime)
  end

  def changeset(sub_event, attrs) do
    sub_event
    |> cast(attrs, [
      :name,
      :description,
      :starts_at,
      :ends_at,
      :venue,
      :status,
      :capacity
    ])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 255)
    |> validate_inclusion(:status, @statuses)
    |> validate_ends_after_starts()
    |> maybe_generate_slug()
    |> unique_constraint(:slug, name: :sub_events_parent_event_id_slug_index)
  end

  defp validate_ends_after_starts(changeset) do
    starts = get_field(changeset, :starts_at)
    ends = get_field(changeset, :ends_at)

    if starts && ends && DateTime.compare(ends, starts) != :gt do
      add_error(changeset, :ends_at, "must be after the start date")
    else
      changeset
    end
  end

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        slug =
          name
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9\s-]/, "")
          |> String.replace(~r/\s+/, "-")
          |> String.replace(~r/-+/, "-")
          |> String.trim("-")
          |> String.slice(0, 50)

        put_change(changeset, :slug, slug)
    end
  end
end
