defmodule Pretex.Accounts do
  @moduledoc """
  The Accounts context manages users in the system.
  """

  import Ecto.Query
  alias Pretex.Repo
  alias Pretex.Accounts.User

  def list_users do
    User
    |> order_by(asc: :name)
    |> Repo.all()
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
