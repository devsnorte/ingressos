defmodule Pretex.Devices.DeviceAssignment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_assignments" do
    belongs_to(:device, Pretex.Devices.Device)
    belongs_to(:event, Pretex.Events.Event)

    timestamps(type: :utc_datetime)
  end

  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:device_id, :event_id])
    |> validate_required([:device_id, :event_id])
    |> unique_constraint([:device_id, :event_id])
    |> foreign_key_constraint(:device_id)
    |> foreign_key_constraint(:event_id)
  end
end
