defmodule Pretex.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft published completed)
  @color_regex ~r/^#[0-9a-fA-F]{6}$/

  schema "events" do
    field(:name, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:starts_at, :utc_datetime)
    field(:ends_at, :utc_datetime)
    field(:venue, :string)
    field(:status, :string, default: "draft")
    field(:logo_url, :string)
    field(:banner_url, :string)
    field(:primary_color, :string, default: "#6366f1")
    field(:accent_color, :string, default: "#f43f5e")

    field(:is_series, :boolean, default: false)
    field(:multi_entry, :boolean, default: false)

    belongs_to(:organization, Pretex.Organizations.Organization)
    belongs_to(:seating_plan, Pretex.Seating.SeatingPlan)
    has_many(:sub_events, Pretex.Events.SubEvent, foreign_key: :parent_event_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :name,
      :description,
      :starts_at,
      :ends_at,
      :venue,
      :logo_url,
      :banner_url,
      :primary_color,
      :accent_color,
      :is_series,
      :multi_entry
    ])
    |> validate_required([:name, :starts_at, :ends_at])
    |> validate_length(:name, min: 2, max: 255)
    |> validate_inclusion(:status, @statuses)
    |> validate_format(:primary_color, @color_regex,
      message: "must be a valid hex color (e.g. #6366f1)"
    )
    |> validate_format(:accent_color, @color_regex,
      message: "must be a valid hex color (e.g. #f43f5e)"
    )
    |> validate_ends_after_starts()
    |> maybe_generate_slug()
    |> unique_constraint(:slug, name: :events_organization_id_slug_index)
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
