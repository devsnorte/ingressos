defmodule Pretex.CustomersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pretex.Customers` context.
  """

  import Ecto.Query

  alias Pretex.Customers
  alias Pretex.Customers.Scope

  def unique_customer_email, do: "customer#{System.unique_integer()}@example.com"
  def valid_customer_password, do: "hello world!"

  def valid_customer_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_customer_email()
    })
  end

  def unconfirmed_customer_fixture(attrs \\ %{}) do
    {:ok, customer} =
      attrs
      |> valid_customer_attributes()
      |> Customers.register_customer()

    customer
  end

  def customer_fixture(attrs \\ %{}) do
    customer = unconfirmed_customer_fixture(attrs)

    token =
      extract_customer_token(fn url ->
        Customers.deliver_login_instructions(customer, url)
      end)

    {:ok, {customer, _expired_tokens}} =
      Customers.login_customer_by_magic_link(token)

    customer
  end

  def customer_scope_fixture do
    customer = customer_fixture()
    customer_scope_fixture(customer)
  end

  def customer_scope_fixture(customer) do
    Scope.for_customer(customer)
  end

  def set_password(customer) do
    {:ok, {customer, _expired_tokens}} =
      Customers.update_customer_password(customer, %{password: valid_customer_password()})

    customer
  end

  def extract_customer_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Pretex.Repo.update_all(
      from(t in Customers.CustomerToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_customer_magic_link_token(customer) do
    {encoded_token, customer_token} = Customers.CustomerToken.build_email_token(customer, "login")
    Pretex.Repo.insert!(customer_token)
    {encoded_token, customer_token.token}
  end

  def offset_customer_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Pretex.Repo.update_all(
      from(ut in Customers.CustomerToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
