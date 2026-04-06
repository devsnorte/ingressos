defmodule Pretex.SyncTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.AccountsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.{Devices, Orders, Sync}

  defp provisioned_device_fixture(org) do
    user = user_fixture()
    {:ok, token_code} = Devices.generate_init_token(org.id, user.id)
    {:ok, %{device: device}} = Devices.provision_device(token_code, "Test Device")
    device
  end

  defp confirmed_order_fixture(event, attrs \\ %{}) do
    {:ok, cart} = Orders.create_cart(event)
    cart = Orders.get_cart_by_token(cart.session_token)
    item = item_fixture(event)

    {:ok, _} = Orders.add_to_cart(cart, item)
    cart = Orders.get_cart_by_token(cart.session_token)

    {:ok, order} =
      Orders.create_order_from_cart(
        cart,
        Enum.into(attrs, %{
          name: "Jane Doe",
          email: "jane@example.com",
          payment_method: "pix"
        })
      )

    {:ok, order} = Orders.confirm_order(order)
    Orders.get_order!(order.id)
  end

  describe "build_manifest/2 (full sync)" do
    test "returns event and attendee data for assigned events" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      [order_item | _] = order.order_items

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      {:ok, manifest} = Sync.build_manifest(device.id, nil)

      assert length(manifest.events) == 1
      [ev] = manifest.events
      assert ev.id == event.id
      assert ev.name == event.name
      assert length(ev.attendees) >= 1

      attendee = Enum.find(ev.attendees, &(&1.ticket_code == order_item.ticket_code))
      assert attendee
      assert attendee.attendee_name == "Jane Doe"
      assert attendee.checked_in_at == nil
      assert manifest.server_timestamp
    end

    test "returns empty events when device has no assignments" do
      org = org_fixture()
      device = provisioned_device_fixture(org)

      {:ok, manifest} = Sync.build_manifest(device.id, nil)
      assert manifest.events == []
    end

    test "excludes unconfirmed orders" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)

      {:ok, cart} = Orders.create_cart(event)
      cart = Orders.get_cart_by_token(cart.session_token)
      item = item_fixture(event)
      {:ok, _} = Orders.add_to_cart(cart, item)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, _order} =
        Orders.create_order_from_cart(cart, %{
          name: "Pending Person",
          email: "pending@example.com",
          payment_method: "pix"
        })

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      {:ok, manifest} = Sync.build_manifest(device.id, nil)
      [ev] = manifest.events
      assert Enum.all?(ev.attendees, &(&1.attendee_name != "Pending Person"))
    end
  end

  describe "build_manifest/2 (incremental sync)" do
    test "returns only attendees updated since given timestamp" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)

      order1 = confirmed_order_fixture(event, %{name: "Early Bird", email: "early@test.com"})

      # Backdate order1's items so they fall before the since cutoff
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      Enum.each(order1.order_items, fn oi ->
        oi |> Ecto.Changeset.change(updated_at: past) |> Pretex.Repo.update!()
      end)

      since = DateTime.utc_now() |> DateTime.add(-1, :second)
      _order2 = confirmed_order_fixture(event, %{name: "Late Comer", email: "late@test.com"})

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      {:ok, manifest} = Sync.build_manifest(device.id, since)
      [ev] = manifest.events

      names = Enum.map(ev.attendees, & &1.attendee_name)
      assert "Late Comer" in names
      refute "Early Bird" in names
    end

    test "returns cancelled ticket codes for removal" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)

      order = confirmed_order_fixture(event)
      [order_item | _] = order.order_items
      since = DateTime.utc_now() |> DateTime.add(-1, :second)

      {:ok, _} = Orders.cancel_order(order)
      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      {:ok, manifest} = Sync.build_manifest(device.id, since)
      [ev] = manifest.events
      assert order_item.ticket_code in ev.removed_ticket_codes
    end
  end

  describe "process_upload/2" do
    test "inserts check-ins from offline device" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      [order_item | _] = order.order_items

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      results = [
        %{
          ticket_code: order_item.ticket_code,
          event_id: event.id,
          checked_in_at: ~U[2026-04-02 09:15:00Z]
        }
      ]

      assert {:ok, summary} = Sync.process_upload(device.id, results)
      assert summary.inserted == 1
      assert summary.conflicts_resolved == 0
      assert summary.skipped == 0
    end

    test "resolves conflict by keeping earliest timestamp" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      {:ok, _} =
        Pretex.CheckIns.check_in_by_ticket_code(
          event.id,
          order_item.ticket_code,
          operator.id
        )

      results = [
        %{
          ticket_code: order_item.ticket_code,
          event_id: event.id,
          checked_in_at: ~U[2026-04-02 09:15:00Z]
        }
      ]

      assert {:ok, summary} = Sync.process_upload(device.id, results)
      assert summary.conflicts_resolved == 1

      check_in = Pretex.CheckIns.get_active_check_in(order_item.id, event.id)
      assert DateTime.compare(check_in.checked_in_at, ~U[2026-04-02 09:15:00Z]) == :eq
    end

    test "skips when existing check-in is earlier" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      operator = user_fixture()
      [order_item | _] = order.order_items

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      {:ok, existing} =
        Pretex.CheckIns.check_in_by_ticket_code(
          event.id,
          order_item.ticket_code,
          operator.id
        )

      results = [
        %{
          ticket_code: order_item.ticket_code,
          event_id: event.id,
          checked_in_at: ~U[2030-01-01 12:00:00Z]
        }
      ]

      assert {:ok, summary} = Sync.process_upload(device.id, results)
      assert summary.skipped == 1

      check_in = Pretex.CheckIns.get_active_check_in(order_item.id, event.id)
      assert check_in.checked_in_at == existing.checked_in_at
    end

    test "handles multiple check-ins in one upload" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)
      order1 = confirmed_order_fixture(event, %{name: "Alice", email: "alice@test.com"})
      order2 = confirmed_order_fixture(event, %{name: "Bob", email: "bob@test.com"})
      [oi1 | _] = order1.order_items
      [oi2 | _] = order2.order_items

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      results = [
        %{
          ticket_code: oi1.ticket_code,
          event_id: event.id,
          checked_in_at: ~U[2026-04-02 09:00:00Z]
        },
        %{
          ticket_code: oi2.ticket_code,
          event_id: event.id,
          checked_in_at: ~U[2026-04-02 09:01:00Z]
        }
      ]

      assert {:ok, summary} = Sync.process_upload(device.id, results)
      assert summary.inserted == 2
      assert summary.processed == 2
    end

    test "skips invalid ticket codes gracefully" do
      org = org_fixture()
      device = provisioned_device_fixture(org)
      event = published_event_fixture(org)

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      results = [
        %{ticket_code: "NONEXISTENT", event_id: event.id, checked_in_at: ~U[2026-04-02 09:00:00Z]}
      ]

      assert {:ok, summary} = Sync.process_upload(device.id, results)
      assert summary.errors == 1
      assert summary.inserted == 0
    end
  end
end
