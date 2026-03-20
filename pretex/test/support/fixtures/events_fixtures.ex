defmodule Pretex.EventsFixtures do
  alias Pretex.Events
  alias Pretex.OrganizationsFixtures

  def event_fixture(org \\ nil, attrs \\ %{}) do
    org = org || OrganizationsFixtures.org_fixture()

    base = %{
      name: "Test Event #{System.unique_integer([:positive])}",
      slug: "test-event-#{System.unique_integer([:positive])}",
      starts_at: ~U[2030-06-01 10:00:00Z],
      ends_at: ~U[2030-06-01 18:00:00Z],
      venue: "Main Stage"
    }

    {:ok, event} = Events.create_event(org, Enum.into(attrs, base))
    event
  end

  def published_event_fixture(org \\ nil, attrs \\ %{}) do
    org = org || OrganizationsFixtures.org_fixture()
    event = event_fixture(org, attrs)
    Pretex.CatalogFixtures.item_fixture(event)
    {:ok, published} = Events.publish_event(event)
    published
  end
end
