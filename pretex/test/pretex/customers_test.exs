defmodule Pretex.CustomersTest do
  use Pretex.DataCase

  alias Pretex.Customers

  import Pretex.CustomersFixtures
  alias Pretex.Customers.{Customer, CustomerToken}

  describe "get_customer_by_email/1" do
    test "does not return the customer if the email does not exist" do
      refute Customers.get_customer_by_email("unknown@example.com")
    end

    test "returns the customer if the email exists" do
      %{id: id} = customer = customer_fixture()
      assert %Customer{id: ^id} = Customers.get_customer_by_email(customer.email)
    end
  end

  describe "get_customer_by_email_and_password/2" do
    test "does not return the customer if the email does not exist" do
      refute Customers.get_customer_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the customer if the password is not valid" do
      customer = customer_fixture() |> set_password()
      refute Customers.get_customer_by_email_and_password(customer.email, "invalid")
    end

    test "returns the customer if the email and password are valid" do
      %{id: id} = customer = customer_fixture() |> set_password()

      assert %Customer{id: ^id} =
               Customers.get_customer_by_email_and_password(
                 customer.email,
                 valid_customer_password()
               )
    end
  end

  describe "get_customer!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Customers.get_customer!(-1)
      end
    end

    test "returns the customer with the given id" do
      %{id: id} = customer = customer_fixture()
      assert %Customer{id: ^id} = Customers.get_customer!(customer.id)
    end
  end

  describe "register_customer/1" do
    test "requires email to be set" do
      {:error, changeset} = Customers.register_customer(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Customers.register_customer(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Customers.register_customer(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = customer_fixture()
      {:error, changeset} = Customers.register_customer(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} = Customers.register_customer(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers customers without password" do
      email = unique_customer_email()
      {:ok, customer} = Customers.register_customer(valid_customer_attributes(email: email))
      assert customer.email == email
      assert is_nil(customer.hashed_password)
      assert is_nil(customer.confirmed_at)
      assert is_nil(customer.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Customers.sudo_mode?(%Customer{authenticated_at: DateTime.utc_now()})
      assert Customers.sudo_mode?(%Customer{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Customers.sudo_mode?(%Customer{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Customers.sudo_mode?(
               %Customer{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Customers.sudo_mode?(%Customer{})
    end
  end

  describe "change_customer_email/3" do
    test "returns a customer changeset" do
      assert %Ecto.Changeset{} = changeset = Customers.change_customer_email(%Customer{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_customer_update_email_instructions/3" do
    setup do
      %{customer: customer_fixture()}
    end

    test "sends token through notification", %{customer: customer} do
      token =
        extract_customer_token(fn url ->
          Customers.deliver_customer_update_email_instructions(
            customer,
            "current@example.com",
            url
          )
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert customer_token = Repo.get_by(CustomerToken, token: :crypto.hash(:sha256, token))
      assert customer_token.customer_id == customer.id
      assert customer_token.sent_to == customer.email
      assert customer_token.context == "change:current@example.com"
    end
  end

  describe "update_customer_email/2" do
    setup do
      customer = unconfirmed_customer_fixture()
      email = unique_customer_email()

      token =
        extract_customer_token(fn url ->
          Customers.deliver_customer_update_email_instructions(
            %{customer | email: email},
            customer.email,
            url
          )
        end)

      %{customer: customer, token: token, email: email}
    end

    test "updates the email with a valid token", %{customer: customer, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Customers.update_customer_email(customer, token)
      changed_customer = Repo.get!(Customer, customer.id)
      assert changed_customer.email != customer.email
      assert changed_customer.email == email
      refute Repo.get_by(CustomerToken, customer_id: customer.id)
    end

    test "does not update email with invalid token", %{customer: customer} do
      assert Customers.update_customer_email(customer, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(Customer, customer.id).email == customer.email
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end

    test "does not update email if customer email changed", %{customer: customer, token: token} do
      assert Customers.update_customer_email(%{customer | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(Customer, customer.id).email == customer.email
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end

    test "does not update email if token expired", %{customer: customer, token: token} do
      {1, nil} = Repo.update_all(CustomerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Customers.update_customer_email(customer, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(Customer, customer.id).email == customer.email
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end
  end

  describe "change_customer_password/3" do
    test "returns a customer changeset" do
      assert %Ecto.Changeset{} = changeset = Customers.change_customer_password(%Customer{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Customers.change_customer_password(
          %Customer{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_customer_password/2" do
    setup do
      %{customer: customer_fixture()}
    end

    test "validates password", %{customer: customer} do
      {:error, changeset} =
        Customers.update_customer_password(customer, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{customer: customer} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Customers.update_customer_password(customer, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{customer: customer} do
      {:ok, {customer, expired_tokens}} =
        Customers.update_customer_password(customer, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(customer.password)
      assert Customers.get_customer_by_email_and_password(customer.email, "new valid password")
    end

    test "deletes all tokens for the given customer", %{customer: customer} do
      _ = Customers.generate_customer_session_token(customer)

      {:ok, {_, _}} =
        Customers.update_customer_password(customer, %{
          password: "new valid password"
        })

      refute Repo.get_by(CustomerToken, customer_id: customer.id)
    end
  end

  describe "generate_customer_session_token/1" do
    setup do
      %{customer: customer_fixture()}
    end

    test "generates a token", %{customer: customer} do
      token = Customers.generate_customer_session_token(customer)
      assert customer_token = Repo.get_by(CustomerToken, token: token)
      assert customer_token.context == "session"
      assert customer_token.authenticated_at != nil

      # Creating the same token for another customer should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%CustomerToken{
          token: customer_token.token,
          customer_id: customer_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given customer in new token", %{customer: customer} do
      customer = %{customer | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Customers.generate_customer_session_token(customer)
      assert customer_token = Repo.get_by(CustomerToken, token: token)
      assert customer_token.authenticated_at == customer.authenticated_at
      assert DateTime.compare(customer_token.inserted_at, customer.authenticated_at) == :gt
    end
  end

  describe "get_customer_by_session_token/1" do
    setup do
      customer = customer_fixture()
      token = Customers.generate_customer_session_token(customer)
      %{customer: customer, token: token}
    end

    test "returns customer by token", %{customer: customer, token: token} do
      assert {session_customer, token_inserted_at} =
               Customers.get_customer_by_session_token(token)

      assert session_customer.id == customer.id
      assert session_customer.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return customer for invalid token" do
      refute Customers.get_customer_by_session_token("oops")
    end

    test "does not return customer for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(CustomerToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Customers.get_customer_by_session_token(token)
    end
  end

  describe "get_customer_by_magic_link_token/1" do
    setup do
      customer = customer_fixture()
      {encoded_token, _hashed_token} = generate_customer_magic_link_token(customer)
      %{customer: customer, token: encoded_token}
    end

    test "returns customer by token", %{customer: customer, token: token} do
      assert session_customer = Customers.get_customer_by_magic_link_token(token)
      assert session_customer.id == customer.id
    end

    test "does not return customer for invalid token" do
      refute Customers.get_customer_by_magic_link_token("oops")
    end

    test "does not return customer for expired token", %{token: token} do
      {1, nil} = Repo.update_all(CustomerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Customers.get_customer_by_magic_link_token(token)
    end
  end

  describe "login_customer_by_magic_link/1" do
    test "confirms customer and expires tokens" do
      customer = unconfirmed_customer_fixture()
      refute customer.confirmed_at
      {encoded_token, hashed_token} = generate_customer_magic_link_token(customer)

      assert {:ok, {customer, [%{token: ^hashed_token}]}} =
               Customers.login_customer_by_magic_link(encoded_token)

      assert customer.confirmed_at
    end

    test "returns customer and (deleted) token for confirmed customer" do
      customer = customer_fixture()
      assert customer.confirmed_at
      {encoded_token, _hashed_token} = generate_customer_magic_link_token(customer)
      assert {:ok, {^customer, []}} = Customers.login_customer_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Customers.login_customer_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed customer has password set" do
      customer = unconfirmed_customer_fixture()
      {1, nil} = Repo.update_all(Customer, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_customer_magic_link_token(customer)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Customers.login_customer_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_customer_session_token/1" do
    test "deletes the token" do
      customer = customer_fixture()
      token = Customers.generate_customer_session_token(customer)
      assert Customers.delete_customer_session_token(token) == :ok
      refute Customers.get_customer_by_session_token(token)
    end
  end

  describe "delete_customer/1" do
    test "deletes the customer record" do
      customer = customer_fixture()
      assert {:ok, %Customer{}} = Customers.delete_customer(customer)
      assert_raise Ecto.NoResultsError, fn -> Customers.get_customer!(customer.id) end
    end

    test "also removes associated tokens" do
      customer = customer_fixture()
      _token = Customers.generate_customer_session_token(customer)
      assert {:ok, _} = Customers.delete_customer(customer)
      refute Repo.get_by(CustomerToken, customer_id: customer.id)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{customer: unconfirmed_customer_fixture()}
    end

    test "sends token through notification", %{customer: customer} do
      token =
        extract_customer_token(fn url ->
          Customers.deliver_login_instructions(customer, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert customer_token = Repo.get_by(CustomerToken, token: :crypto.hash(:sha256, token))
      assert customer_token.customer_id == customer.id
      assert customer_token.sent_to == customer.email
      assert customer_token.context == "login"
    end
  end

  describe "inspect/2 for the Customer module" do
    test "does not include password" do
      refute inspect(%Customer{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
