defmodule Pretex.Devices.DeviceAssignmentsTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.AccountsFixtures
  import Pretex.EventsFixtures

  alias Pretex.Devices

  defp provisioned_device_fixture(org) do
    user = user_fixture()
    {:ok, token_code} = Devices.generate_init_token(org.id, user.id)
    {:ok, %{device: device}} = Devices.provision_device(token_code, "Test Device")
    device
  end

  describe "assign_device_to_event/2" do
    test "assigns a device to an event" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)

      assert {:ok, assignment} = Devices.assign_device_to_event(device.id, event.id)
      assert assignment.device_id == device.id
      assert assignment.event_id == event.id
    end

    test "prevents duplicate assignment" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)

      assert {:ok, _} = Devices.assign_device_to_event(device.id, event.id)
      assert {:error, changeset} = Devices.assign_device_to_event(device.id, event.id)
      assert errors_on(changeset)[:device_id]
    end
  end

  describe "unassign_device_from_event/2" do
    test "removes a device assignment" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)
      assert :ok = Devices.unassign_device_from_event(device.id, event.id)
      assert [] = Devices.list_device_assignments(device.id)
    end
  end

  describe "list_device_assignments/1" do
    test "returns all events assigned to a device" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event1 = published_event_fixture(org)
      event2 = published_event_fixture(org)

      {:ok, _} = Devices.assign_device_to_event(device.id, event1.id)
      {:ok, _} = Devices.assign_device_to_event(device.id, event2.id)

      assignments = Devices.list_device_assignments(device.id)
      assert length(assignments) == 2
    end
  end
end
