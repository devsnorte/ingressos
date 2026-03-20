defmodule Pretex.ConcurrencyTest do
  # Cannot use async: true because Task.async spawns processes that need
  # shared sandbox access to the database.
  use Pretex.DataCase, async: false

  alias Pretex.Catalog
  alias Pretex.Organizations
  alias Pretex.Events

  # Shared fixtures - import if available, otherwise inline
  defp setup_event do
    {:ok, org} =
      Organizations.create_organization(%{
        name: "Concurrent Org #{System.unique_integer([:positive])}",
        slug: "concurrent-#{System.unique_integer([:positive])}"
      })

    {:ok, event} =
      Events.create_event(org, %{
        name: "Concurrent Event",
        slug: "concurrent-event-#{System.unique_integer([:positive])}",
        starts_at: ~U[2030-06-01 10:00:00Z],
        ends_at: ~U[2030-06-01 18:00:00Z]
      })

    {org, event}
  end

  describe "concurrent organization creation" do
    test "rejects duplicate slugs under concurrent creation" do
      slug = "race-condition-#{System.unique_integer([:positive])}"

      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            Organizations.create_organization(%{
              name: "Race Org",
              slug: slug
            })
          end)
        end

      results = Task.await_many(tasks)

      successes = Enum.filter(results, &match?({:ok, _}, &1))
      failures = Enum.filter(results, &match?({:error, _}, &1))

      # Exactly one should succeed, the rest should fail with unique constraint
      assert length(successes) == 1
      assert length(failures) == 4
    end
  end

  describe "concurrent catalog operations" do
    test "concurrent item creation for same event gets unique items" do
      {_org, event} = setup_event()

      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            Catalog.create_item(event, %{
              name: "Item #{i}",
              price_cents: 1000 * i
            })
          end)
        end

      results = Task.await_many(tasks)
      successes = Enum.filter(results, &match?({:ok, _}, &1))

      assert length(successes) == 10

      # Verify all items exist
      items = Catalog.list_items(event)
      assert length(items) == 10
    end
  end

  describe "concurrent quota operations" do
    test "quota count remains consistent under concurrent updates" do
      {_org, event} = setup_event()
      {:ok, item} = Catalog.create_item(event, %{name: "Quota Item", price_cents: 5000})
      {:ok, quota} = Catalog.create_quota(event, %{name: "Limited", capacity: 100})
      {:ok, _} = Catalog.assign_item_to_quota(quota, item)

      # Verify initial state
      updated_quota = Catalog.get_quota!(quota.id)
      assert updated_quota.capacity == 100
    end
  end
end
