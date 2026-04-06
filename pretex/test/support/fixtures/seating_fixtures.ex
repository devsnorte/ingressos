defmodule Pretex.SeatingFixtures do
  @moduledoc "Fixtures for the Seating context tests."

  alias Pretex.Seating

  @valid_layout %{
    "sections" => [
      %{
        "name" => "Orchestra",
        "rows" => [
          %{"label" => "A", "seats" => 5},
          %{"label" => "B", "seats" => 5}
        ]
      },
      %{
        "name" => "Balcony",
        "rows" => [
          %{"label" => "A", "seats" => 3}
        ]
      }
    ]
  }

  def valid_layout, do: @valid_layout

  def seating_plan_fixture(org_id, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Test Plan #{System.unique_integer([:positive])}",
        layout: @valid_layout
      })

    {:ok, plan} = Seating.create_seating_plan(org_id, attrs)
    plan
  end
end
