defmodule Pretex.Accounts do
  @moduledoc """
  The Accounts context manages staff users and their authentication tokens.
  """

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Accounts.User
  alias Pretex.Accounts.UserToken
  alias Pretex.Accounts.UserNotifier

  # ---------------------------------------------------------------------------
  # User queries
  # ---------------------------------------------------------------------------

  def list_users do
    User
    |> order_by(asc: :name)
    |> Repo.all()
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # Session tokens
  # ---------------------------------------------------------------------------

  @doc "Generates and persists a session token for a user. Returns the raw binary token."
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc "Returns the user for the given raw session token, or nil if invalid/expired."
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc "Deletes the session token so the user is logged out."
  def delete_user_session_token(token) do
    Repo.delete_all(from(t in UserToken, where: t.token == ^token and t.context == "session"))
    :ok
  end

  # ---------------------------------------------------------------------------
  # Magic link
  # ---------------------------------------------------------------------------

  @doc """
  Generates a magic-link token, stores the hashed version, and emails the
  URL-encoded raw token to the user.

  `login_url_fun` receives the encoded token and must return the full URL,
  e.g. `&url(~p"/staff/log-in/\#{&1}")`.
  """
  def deliver_user_login_instructions(%User{} = user, login_url_fun)
      when is_function(login_url_fun, 1) do
    {encoded, user_token} = UserToken.build_magic_link_token(user)
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, login_url_fun.(encoded))
  end

  @doc """
  Peeks at a magic-link token: returns `{:ok, user}` if the token is valid
  **without** consuming (deleting) it. Used by the LiveView to show the
  user's name on the confirmation page before the final POST.
  Returns `{:error, :invalid}` if the token is missing or expired.
  """
  def peek_user_magic_link_token(encoded) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(encoded),
         {user, _token} <- Repo.one(query) do
      {:ok, user}
    else
      _ -> {:error, :invalid}
    end
  end

  @doc """
  Consumes a magic-link token: verifies it, deletes it, and returns
  `{:ok, user}`. Returns `{:error, :invalid}` if missing or expired.
  Call this exactly once — in the session controller — to complete login.
  """
  def consume_user_magic_link_token(encoded) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(encoded),
         {user, token} <- Repo.one(query) do
      Repo.delete!(token)
      {:ok, user}
    else
      _ -> {:error, :invalid}
    end
  end
end
