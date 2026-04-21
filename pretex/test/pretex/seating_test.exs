defmodule Pretex.SeatingTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures
  import Pretex.SeatingFixtures

  alias Pretex.Seating
  alias Pretex.Seating.SeatReservation

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp cart_session_fixture(event) do
    {:ok, cart} = Pretex.Orders.create_cart(event)
    cart
  end

  defp order_item_fixture(event) do
    item = item_fixture(event)

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    confirmation_code = "TEST#{System.unique_integer([:positive])}"

    {:ok, order} =
      %Pretex.Orders.Order{}
      |> Ecto.Changeset.change(%{
        event_id: event.id,
        status: "confirmed",
        total_cents: item.price_cents,
        email: "test@example.com",
        name: "Test User",
        confirmation_code: confirmation_code,
        expires_at: DateTime.add(now, 3600, :second)
      })
      |> Pretex.Repo.insert()

    ticket_code = "TKT#{System.unique_integer([:positive])}"

    {:ok, order_item} =
      %Pretex.Orders.OrderItem{}
      |> Ecto.Changeset.change(%{
        order_id: order.id,
        item_id: item.id,
        quantity: 1,
        unit_price_cents: item.price_cents,
        ticket_code: ticket_code
      })
      |> Pretex.Repo.insert()

    order_item
  end

  # ---------------------------------------------------------------------------
  # parse_layout/1
  # ---------------------------------------------------------------------------

  describe "parse_layout/1" do
    test "parses a valid layout into section/seat maps" do
      layout = %{
        "sections" => [
          %{
            "name" => "Pista",
            "rows" => [
              %{"label" => "A", "seats" => 3},
              %{"label" => "B", "seats" => 2}
            ]
          }
        ]
      }

      assert {:ok, [section]} = Seating.parse_layout(layout)
      assert section.name == "Pista"
      assert section.row_count == 2
      assert section.capacity == 5
      assert length(section.seats) == 5

      labels = Enum.map(section.seats, & &1.label)
      assert "A-1" in labels
      assert "A-3" in labels
      assert "B-1" in labels
      assert "B-2" in labels
    end

    test "parses multiple sections" do
      assert {:ok, sections} = Seating.parse_layout(valid_layout())
      assert length(sections) == 2
      names = Enum.map(sections, & &1.name)
      assert "Orchestra" in names
      assert "Balcony" in names
    end

    test "returns error for nil" do
      assert {:error, :invalid_layout} = Seating.parse_layout(nil)
    end

    test "returns error for empty map" do
      assert {:error, :invalid_layout} = Seating.parse_layout(%{})
    end

    test "returns error when sections key is missing" do
      assert {:error, :invalid_layout} = Seating.parse_layout(%{"name" => "Test"})
    end

    test "returns error when sections is an empty list" do
      assert {:error, :invalid_layout} = Seating.parse_layout(%{"sections" => []})
    end

    test "returns error when a section is missing name" do
      layout = %{
        "sections" => [
          %{"rows" => [%{"label" => "A", "seats" => 5}]}
        ]
      }

      assert {:error, :invalid_layout} = Seating.parse_layout(layout)
    end

    test "returns error when a section has empty name" do
      layout = %{
        "sections" => [
          %{"name" => "", "rows" => [%{"label" => "A", "seats" => 5}]}
        ]
      }

      assert {:error, :invalid_layout} = Seating.parse_layout(layout)
    end

    test "returns error when a row has invalid seat count" do
      layout = %{
        "sections" => [
          %{"name" => "A", "rows" => [%{"label" => "A", "seats" => 0}]}
        ]
      }

      assert {:error, :invalid_layout} = Seating.parse_layout(layout)
    end

    test "returns error when a row is missing label" do
      layout = %{
        "sections" => [
          %{"name" => "A", "rows" => [%{"seats" => 5}]}
        ]
      }

      assert {:error, :invalid_layout} = Seating.parse_layout(layout)
    end
  end

  # ---------------------------------------------------------------------------
  # create_seating_plan/2
  # ---------------------------------------------------------------------------

  describe "create_seating_plan/2" do
    test "creates plan with sections and seats from valid layout" do
      org = org_fixture()

      assert {:ok, plan} =
               Seating.create_seating_plan(org.id, %{
                 name: "Teatro Central",
                 layout: valid_layout()
               })

      assert plan.name == "Teatro Central"
      assert plan.organization_id == org.id
      assert length(plan.sections) == 2

      total_seats = plan.sections |> Enum.flat_map(& &1.seats) |> length()
      # Orchestra: 5+5=10, Balcony: 3
      assert total_seats == 13
    end

    test "returns :invalid_layout for malformed JSON map" do
      org = org_fixture()

      assert {:error, :invalid_layout} =
               Seating.create_seating_plan(org.id, %{
                 name: "Bad Plan",
                 layout: %{"wrong" => "structure"}
               })
    end

    test "returns changeset error when name is missing" do
      org = org_fixture()

      assert {:error, changeset} =
               Seating.create_seating_plan(org.id, %{layout: valid_layout()})

      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "returns changeset error when name is too short" do
      org = org_fixture()

      assert {:error, changeset} =
               Seating.create_seating_plan(org.id, %{name: "X", layout: valid_layout()})

      assert %{name: [_ | _]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # list_seating_plans/1
  # ---------------------------------------------------------------------------

  describe "list_seating_plans/1" do
    test "returns plans for the given org ordered by name" do
      org = org_fixture()
      seating_plan_fixture(org.id, %{name: "Zebra Hall"})
      seating_plan_fixture(org.id, %{name: "Alpha Arena"})

      plans = Seating.list_seating_plans(org.id)
      names = Enum.map(plans, & &1.name)
      assert Enum.at(names, 0) == "Alpha Arena"
      assert Enum.at(names, 1) == "Zebra Hall"
    end

    test "does not return plans from another org" do
      org1 = org_fixture()
      org2 = org_fixture()
      seating_plan_fixture(org1.id)

      assert Seating.list_seating_plans(org2.id) == []
    end
  end

  # ---------------------------------------------------------------------------
  # get_seating_plan!/1
  # ---------------------------------------------------------------------------

  describe "get_seating_plan!/1" do
    test "returns plan with sections and seats" do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)

      fetched = Seating.get_seating_plan!(plan.id)
      assert fetched.id == plan.id
      assert length(fetched.sections) == 2
      assert fetched.sections |> hd() |> Map.get(:seats) |> is_list()
    end

    test "raises Ecto.NoResultsError for missing id" do
      assert_raise Ecto.NoResultsError, fn -> Seating.get_seating_plan!(0) end
    end
  end

  # ---------------------------------------------------------------------------
  # assign_plan_to_event/2
  # ---------------------------------------------------------------------------

  describe "assign_plan_to_event/2" do
    test "links a seating plan to an event" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)

      assert {:ok, updated_event} = Seating.assign_plan_to_event(event.id, plan.id)
      assert updated_event.seating_plan_id == plan.id
    end

    test "returns :not_found for missing event" do
      org = org_fixture()
      plan = seating_plan_fixture(org.id)

      assert {:error, :not_found} = Seating.assign_plan_to_event(0, plan.id)
    end
  end

  # ---------------------------------------------------------------------------
  # map_section_to_item/3
  # ---------------------------------------------------------------------------

  describe "map_section_to_item/3" do
    test "sets item_id on a section" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      item = item_fixture(event)

      section = hd(plan.sections)

      assert {:ok, updated} = Seating.map_section_to_item(section.id, item.id, nil)
      assert updated.item_id == item.id
      assert is_nil(updated.item_variation_id)
    end

    test "sets item_id and item_variation_id on a section" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      item = item_fixture(event)
      variation = variation_fixture(item)

      section = hd(plan.sections)

      assert {:ok, updated} = Seating.map_section_to_item(section.id, item.id, variation.id)
      assert updated.item_id == item.id
      assert updated.item_variation_id == variation.id
    end

    test "clears item mapping when nil is passed" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      item = item_fixture(event)

      section = hd(plan.sections)
      {:ok, _} = Seating.map_section_to_item(section.id, item.id, nil)

      assert {:ok, cleared} = Seating.map_section_to_item(section.id, nil, nil)
      assert is_nil(cleared.item_id)
    end

    test "returns :not_found for unknown section" do
      assert {:error, :not_found} = Seating.map_section_to_item(0, 1, nil)
    end
  end

  # ---------------------------------------------------------------------------
  # available_seats/2
  # ---------------------------------------------------------------------------

  describe "available_seats/2" do
    test "returns all seats in a section when none are reserved" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)

      section = hd(plan.sections)
      seats = Seating.available_seats(event.id, section.id)

      assert length(seats) == section.capacity
    end

    test "excludes held seats" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart = cart_session_fixture(event)

      section = hd(plan.sections)
      seat = section.seats |> hd()

      {:ok, _} = Seating.hold_seat(seat.id, event.id, cart.id)

      available = Seating.available_seats(event.id, section.id)
      available_ids = Enum.map(available, & &1.id)
      refute seat.id in available_ids
    end

    test "excludes confirmed seats" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      order_item = order_item_fixture(event)

      section = hd(plan.sections)
      seat = section.seats |> hd()

      {:ok, _} = Seating.assign_seat(seat.id, event.id, order_item.id)

      available = Seating.available_seats(event.id, section.id)
      available_ids = Enum.map(available, & &1.id)
      refute seat.id in available_ids
    end

    test "includes seats whose reservations are released" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart = cart_session_fixture(event)

      section = hd(plan.sections)
      seat = section.seats |> hd()

      {:ok, _} = Seating.hold_seat(seat.id, event.id, cart.id)
      {:ok, _} = Seating.release_seat(seat.id, event.id)

      available = Seating.available_seats(event.id, section.id)
      available_ids = Enum.map(available, & &1.id)
      assert seat.id in available_ids
    end
  end

  # ---------------------------------------------------------------------------
  # hold_seat/3
  # ---------------------------------------------------------------------------

  describe "hold_seat/3" do
    test "creates a held reservation with a future expiry" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart = cart_session_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()

      assert {:ok, reservation} = Seating.hold_seat(seat.id, event.id, cart.id)
      assert reservation.status == "held"
      assert reservation.seat_id == seat.id
      assert reservation.event_id == event.id
      assert reservation.cart_session_id == cart.id
      assert DateTime.compare(reservation.held_until, DateTime.utc_now()) == :gt
    end

    test "returns :already_reserved for a seat that is already held" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart1 = cart_session_fixture(event)
      cart2 = cart_session_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()

      {:ok, _} = Seating.hold_seat(seat.id, event.id, cart1.id)

      assert {:error, :already_reserved} = Seating.hold_seat(seat.id, event.id, cart2.id)
    end

    test "allows holding a seat for a different event" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart1 = cart_session_fixture(event1)
      cart2 = cart_session_fixture(event2)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()

      assert {:ok, _} = Seating.hold_seat(seat.id, event1.id, cart1.id)
      assert {:ok, _} = Seating.hold_seat(seat.id, event2.id, cart2.id)
    end
  end

  # ---------------------------------------------------------------------------
  # confirm_seat/3
  # ---------------------------------------------------------------------------

  describe "confirm_seat/3" do
    test "upgrades a held reservation to confirmed" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart = cart_session_fixture(event)
      order_item = order_item_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()

      {:ok, _} = Seating.hold_seat(seat.id, event.id, cart.id)

      assert {:ok, confirmed} = Seating.confirm_seat(seat.id, event.id, order_item.id)
      assert confirmed.status == "confirmed"
      assert confirmed.order_item_id == order_item.id
      assert is_nil(confirmed.held_until)
    end

    test "returns :not_found when no active reservation exists" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()

      assert {:error, :not_found} = Seating.confirm_seat(seat.id, event.id, 999)
    end
  end

  # ---------------------------------------------------------------------------
  # release_seat/2
  # ---------------------------------------------------------------------------

  describe "release_seat/2" do
    test "releases a held reservation" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart = cart_session_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()
      {:ok, _} = Seating.hold_seat(seat.id, event.id, cart.id)

      assert {:ok, released} = Seating.release_seat(seat.id, event.id)
      assert released.status == "released"
    end

    test "releases a confirmed reservation" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      order_item = order_item_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()
      {:ok, _} = Seating.assign_seat(seat.id, event.id, order_item.id)

      assert {:ok, released} = Seating.release_seat(seat.id, event.id)
      assert released.status == "released"
    end

    test "returns :not_found when no active reservation exists" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()

      assert {:error, :not_found} = Seating.release_seat(seat.id, event.id)
    end

    test "allows re-holding a seat after it is released" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart1 = cart_session_fixture(event)
      cart2 = cart_session_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()
      {:ok, _} = Seating.hold_seat(seat.id, event.id, cart1.id)
      {:ok, _} = Seating.release_seat(seat.id, event.id)

      assert {:ok, new_hold} = Seating.hold_seat(seat.id, event.id, cart2.id)
      assert new_hold.status == "held"
    end
  end

  # ---------------------------------------------------------------------------
  # assign_seat/3
  # ---------------------------------------------------------------------------

  describe "assign_seat/3" do
    test "creates a confirmed reservation directly" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      order_item = order_item_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()

      assert {:ok, reservation} = Seating.assign_seat(seat.id, event.id, order_item.id)
      assert reservation.status == "confirmed"
      assert reservation.order_item_id == order_item.id
    end

    test "returns :already_reserved when seat is held by another cart" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart = cart_session_fixture(event)
      order_item = order_item_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()
      {:ok, _} = Seating.hold_seat(seat.id, event.id, cart.id)

      assert {:error, :already_reserved} = Seating.assign_seat(seat.id, event.id, order_item.id)
    end
  end

  # ---------------------------------------------------------------------------
  # reassign_seat/4
  # ---------------------------------------------------------------------------

  describe "reassign_seat/4" do
    test "moves a confirmed reservation to a new seat" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      order_item = order_item_fixture(event)

      [seat1, seat2 | _] = plan.sections |> hd() |> Map.get(:seats)
      {:ok, _} = Seating.assign_seat(seat1.id, event.id, order_item.id)

      assert {:ok, new_reservation} =
               Seating.reassign_seat(seat1.id, seat2.id, event.id, order_item.id)

      assert new_reservation.seat_id == seat2.id
      assert new_reservation.status == "confirmed"

      # Old seat should be released (available again)
      available = Seating.available_seats(event.id, hd(plan.sections).id)
      available_ids = Enum.map(available, & &1.id)
      assert seat1.id in available_ids
    end

    test "returns :not_found when old seat has no active reservation" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)

      [seat1, seat2 | _] = plan.sections |> hd() |> Map.get(:seats)

      assert {:error, :not_found} =
               Seating.reassign_seat(seat1.id, seat2.id, event.id, 999)
    end

    test "returns :already_reserved when target seat is taken" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      order_item1 = order_item_fixture(event)
      order_item2 = order_item_fixture(event)

      [seat1, seat2 | _] = plan.sections |> hd() |> Map.get(:seats)
      {:ok, _} = Seating.assign_seat(seat1.id, event.id, order_item1.id)
      {:ok, _} = Seating.assign_seat(seat2.id, event.id, order_item2.id)

      assert {:error, :already_reserved} =
               Seating.reassign_seat(seat1.id, seat2.id, event.id, order_item1.id)
    end
  end

  # ---------------------------------------------------------------------------
  # release_expired_holds/0
  # ---------------------------------------------------------------------------

  describe "release_expired_holds/0" do
    test "releases holds that have passed their held_until timestamp" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart = cart_session_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()
      {:ok, reservation} = Seating.hold_seat(seat.id, event.id, cart.id)

      # Manually backdate the held_until to simulate expiry
      expired_at = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      reservation
      |> Ecto.Changeset.change(held_until: expired_at)
      |> Pretex.Repo.update!()

      {count, _} = Seating.release_expired_holds()
      assert count >= 1

      updated = Pretex.Repo.get!(SeatReservation, reservation.id)
      assert updated.status == "released"
    end

    test "does not release holds that are still within the time window" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      cart = cart_session_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()
      {:ok, reservation} = Seating.hold_seat(seat.id, event.id, cart.id)

      Seating.release_expired_holds()

      updated = Pretex.Repo.get!(SeatReservation, reservation.id)
      assert updated.status == "held"
    end

    test "does not release confirmed reservations" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)
      order_item = order_item_fixture(event)

      seat = plan.sections |> hd() |> Map.get(:seats) |> hd()
      {:ok, reservation} = Seating.assign_seat(seat.id, event.id, order_item.id)

      Seating.release_expired_holds()

      updated = Pretex.Repo.get!(SeatReservation, reservation.id)
      assert updated.status == "confirmed"
    end
  end

  # ---------------------------------------------------------------------------
  # Concurrency: simultaneous seat holds
  # ---------------------------------------------------------------------------

  describe "concurrent seat holds" do
    test "only one hold succeeds when two processes race for the same seat" do
      org = org_fixture()
      event = event_fixture(org)
      plan = seating_plan_fixture(org.id)

      [seat | _] = plan.sections |> hd() |> Map.get(:seats)

      cart1 = cart_session_fixture(event)
      cart2 = cart_session_fixture(event)

      # Race both holds from separate tasks
      results =
        [
          Task.async(fn -> Seating.hold_seat(seat.id, event.id, cart1.id) end),
          Task.async(fn -> Seating.hold_seat(seat.id, event.id, cart2.id) end)
        ]
        |> Task.await_many(5000)

      successes = Enum.count(results, &match?({:ok, _}, &1))
      failures = Enum.count(results, &match?({:error, :already_reserved}, &1))

      assert successes == 1
      assert failures == 1
    end
  end
end
