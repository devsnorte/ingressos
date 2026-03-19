defmodule Pretex.Customers do
  @moduledoc """
  The Customers context.
  """

  import Ecto.Query, warn: false
  alias Pretex.Repo

  alias Pretex.Customers.{Customer, CustomerToken, CustomerNotifier}

  ## Database getters

  @doc """
  Gets a customer by email.

  ## Examples

      iex> get_customer_by_email("foo@example.com")
      %Customer{}

      iex> get_customer_by_email("unknown@example.com")
      nil

  """
  def get_customer_by_email(email) when is_binary(email) do
    Repo.get_by(Customer, email: email)
  end

  @doc """
  Gets a customer by email and password.

  ## Examples

      iex> get_customer_by_email_and_password("foo@example.com", "correct_password")
      %Customer{}

      iex> get_customer_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_customer_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    customer = Repo.get_by(Customer, email: email)
    if Customer.valid_password?(customer, password), do: customer
  end

  @doc """
  Gets a single customer.

  Raises `Ecto.NoResultsError` if the Customer does not exist.

  ## Examples

      iex> get_customer!(123)
      %Customer{}

      iex> get_customer!(456)
      ** (Ecto.NoResultsError)

  """
  def get_customer!(id), do: Repo.get!(Customer, id)

  @doc """
  Deletes a customer and all associated tokens.

  ## Examples

      iex> delete_customer(customer)
      {:ok, %Customer{}}

  """
  def delete_customer(%Customer{} = customer) do
    Repo.delete(customer)
  end

  ## Customer registration

  @doc """
  Registers a customer.

  ## Examples

      iex> register_customer(%{field: value})
      {:ok, %Customer{}}

      iex> register_customer(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_customer(attrs) do
    %Customer{}
    |> Customer.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the customer is in sudo mode.

  The customer is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(customer, minutes \\ -20)

  def sudo_mode?(%Customer{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_customer, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the customer email.

  See `Pretex.Customers.Customer.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_customer_email(customer)
      %Ecto.Changeset{data: %Customer{}}

  """
  def change_customer_email(customer, attrs \\ %{}, opts \\ []) do
    Customer.email_changeset(customer, attrs, opts)
  end

  @doc """
  Updates the customer email using the given token.

  If the token matches, the customer email is updated and the token is deleted.
  """
  def update_customer_email(customer, token) do
    context = "change:#{customer.email}"

    Repo.transact(fn ->
      with {:ok, query} <- CustomerToken.verify_change_email_token_query(token, context),
           %CustomerToken{sent_to: email} <- Repo.one(query),
           {:ok, customer} <- Repo.update(Customer.email_changeset(customer, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(
               from(CustomerToken, where: [customer_id: ^customer.id, context: ^context])
             ) do
        {:ok, customer}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the customer password.

  See `Pretex.Customers.Customer.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_customer_password(customer)
      %Ecto.Changeset{data: %Customer{}}

  """
  def change_customer_password(customer, attrs \\ %{}, opts \\ []) do
    Customer.password_changeset(customer, attrs, opts)
  end

  @doc """
  Updates the customer password.

  Returns a tuple with the updated customer, as well as a list of expired tokens.

  ## Examples

      iex> update_customer_password(customer, %{password: ...})
      {:ok, {%Customer{}, [...]}}

      iex> update_customer_password(customer, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_customer_password(customer, attrs) do
    customer
    |> Customer.password_changeset(attrs)
    |> update_customer_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_customer_session_token(customer) do
    {token, customer_token} = CustomerToken.build_session_token(customer)
    Repo.insert!(customer_token)
    token
  end

  @doc """
  Gets the customer with the given signed token.

  If the token is valid `{customer, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_customer_by_session_token(token) do
    {:ok, query} = CustomerToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the customer with the given magic link token.
  """
  def get_customer_by_magic_link_token(token) do
    with {:ok, query} <- CustomerToken.verify_magic_link_token_query(token),
         {customer, _token} <- Repo.one(query) do
      customer
    else
      _ -> nil
    end
  end

  @doc """
  Logs the customer in by magic link.

  There are three cases to consider:

  1. The customer has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The customer has not confirmed their email and no password is set.
     In this case, the customer gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The customer has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_customer_by_magic_link(token) do
    {:ok, query} = CustomerToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%Customer{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%Customer{confirmed_at: nil} = customer, _token} ->
        customer
        |> Customer.confirm_changeset()
        |> update_customer_and_delete_all_tokens()

      {customer, token} ->
        Repo.delete!(token)
        {:ok, {customer, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given customer.

  ## Examples

      iex> deliver_customer_update_email_instructions(customer, current_email, &url(~p"/customers/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_customer_update_email_instructions(
        %Customer{} = customer,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    {encoded_token, customer_token} =
      CustomerToken.build_email_token(customer, "change:#{current_email}")

    Repo.insert!(customer_token)

    CustomerNotifier.deliver_update_email_instructions(
      customer,
      update_email_url_fun.(encoded_token)
    )
  end

  @doc """
  Delivers the magic link login instructions to the given customer.
  """
  def deliver_login_instructions(%Customer{} = customer, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, customer_token} = CustomerToken.build_email_token(customer, "login")
    Repo.insert!(customer_token)
    CustomerNotifier.deliver_login_instructions(customer, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_customer_session_token(token) do
    Repo.delete_all(from(CustomerToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_customer_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, customer} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(CustomerToken, customer_id: customer.id)

        Repo.delete_all(
          from(t in CustomerToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id))
        )

        {:ok, {customer, tokens_to_expire}}
      end
    end)
  end
end
