defmodule Pretex.Catalog.AttendeeFieldConfig do
  use Ecto.Schema
  import Ecto.Changeset

  @field_names ~w(name email company phone address birth_date)

  schema "attendee_field_configs" do
    field(:field_name, :string)
    field(:is_enabled, :boolean, default: true)
    field(:is_required, :boolean, default: false)

    belongs_to(:event, Pretex.Events.Event)

    timestamps(type: :utc_datetime)
  end

  def field_names, do: @field_names

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:field_name, :is_enabled, :is_required])
    |> validate_required([:field_name])
    |> validate_inclusion(:field_name, @field_names)
    |> unique_constraint(:field_name, name: :attendee_field_configs_event_id_field_name_index)
  end
end
