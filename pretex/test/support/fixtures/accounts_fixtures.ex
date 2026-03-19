defmodule Pretex.AccountsFixtures do
  @moduledoc """
  Test helpers for creating staff users via `Pretex.Accounts`.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_user_email(),
        name: "Test User"
      })
      |> Pretex.Accounts.create_user()

    user
  end
end
