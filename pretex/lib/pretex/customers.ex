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

  # ---------------------------------------------------------------------------
  # TOTP
  # ---------------------------------------------------------------------------

  @doc "Generates a fresh TOTP secret (raw binary)."
  def generate_totp_secret, do: NimbleTOTP.secret()

  @doc "Returns the otpauth URI for the QR code."
  def totp_uri(%Customer{email: email}, secret) do
    NimbleTOTP.otpauth_uri("Pretex:#{email}", secret, issuer: "Pretex")
  end

  @doc """
  Returns an SVG string (safe for embedding) of the QR code for the TOTP setup URI.
  The secret passed here is the raw binary from generate_totp_secret/0.
  """
  def totp_qr_svg(%Customer{} = customer, secret) do
    customer
    |> totp_uri(secret)
    |> EQRCode.encode()
    |> EQRCode.svg(width: 200)
  end

  @doc "Returns the Base32-encoded secret string for manual entry."
  def totp_secret_base32(secret), do: Base.encode32(secret, padding: false)

  @doc "Verifies a TOTP code against the raw binary secret. Returns true/false."
  def valid_totp_code?(secret, code) when is_binary(secret) and is_binary(code) do
    NimbleTOTP.valid?(secret, code)
  end

  @doc """
  Enables TOTP for the customer: stores the secret and sets totp_enabled_at.
  Should only be called after valid_totp_code? returns true.
  """
  def enable_totp(%Customer{} = customer, secret) do
    customer
    |> Ecto.Changeset.change(totp_secret: secret, totp_enabled_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  @doc "Disables TOTP for the customer."
  def disable_totp(%Customer{} = customer) do
    customer
    |> Ecto.Changeset.change(totp_secret: nil, totp_enabled_at: nil)
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Recovery codes
  # ---------------------------------------------------------------------------

  @doc """
  Generates 8 recovery codes, stores their SHA-256 hashes, and returns the
  plaintext codes as a list of strings. Deletes any previously existing codes.
  Format: "XXXX-XXXX" (8 random uppercase alphanumeric chars, hyphen in middle).
  """
  def generate_recovery_codes(%Customer{} = customer) do
    Repo.delete_all(
      from(r in Pretex.Customers.CustomerRecoveryCode, where: r.customer_id == ^customer.id)
    )

    codes =
      for _ <- 1..8 do
        raw =
          :crypto.strong_rand_bytes(5)
          |> Base.encode32(padding: false)
          |> String.slice(0, 8)

        formatted = "#{String.slice(raw, 0, 4)}-#{String.slice(raw, 4, 4)}"
        hash = :crypto.hash(:sha256, String.upcase(formatted)) |> Base.encode16(case: :lower)
        {formatted, hash}
      end

    Enum.each(codes, fn {_plain, hash} ->
      %Pretex.Customers.CustomerRecoveryCode{}
      |> Ecto.Changeset.change(code_hash: hash, customer_id: customer.id)
      |> Repo.insert!()
    end)

    Enum.map(codes, fn {plain, _} -> plain end)
  end

  @doc """
  Attempts to use a recovery code for the customer.
  Returns :ok if found and unused, :error otherwise.
  Marks the code as used.
  """
  def use_recovery_code(%Customer{} = customer, code) do
    hash =
      :crypto.hash(:sha256, String.upcase(String.trim(code)))
      |> Base.encode16(case: :lower)

    query =
      from(r in Pretex.Customers.CustomerRecoveryCode,
        where: r.customer_id == ^customer.id and r.code_hash == ^hash and is_nil(r.used_at)
      )

    case Repo.one(query) do
      nil ->
        :error

      record ->
        record
        |> Ecto.Changeset.change(used_at: DateTime.utc_now(:second))
        |> Repo.update!()

        :ok
    end
  end

  @doc "Returns the count of remaining unused recovery codes for the customer."
  def remaining_recovery_codes(%Customer{} = customer) do
    Repo.aggregate(
      from(r in Pretex.Customers.CustomerRecoveryCode,
        where: r.customer_id == ^customer.id and is_nil(r.used_at)
      ),
      :count
    )
  end

  # ---------------------------------------------------------------------------
  # WebAuthn
  # ---------------------------------------------------------------------------

  @doc "Lists all WebAuthn credentials for a customer."
  def list_webauthn_credentials(%Customer{id: id}) do
    Repo.all(from(c in Pretex.Customers.CustomerWebAuthnCredential, where: c.customer_id == ^id))
  end

  @doc """
  Starts a WebAuthn registration for the customer.
  Returns {challenge, creation_options_map} where challenge is a %Wax.Challenge{} and
  creation_options_map is ready to be JSON-encoded and sent to the browser.
  """
  def webauthn_registration_options(%Customer{} = customer) do
    challenge =
      Wax.new_registration_challenge(
        origin: "http://localhost:4000",
        rp_id: "localhost",
        attestation: "none"
      )

    opts = %{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      rp: %{id: "localhost", name: "Pretex"},
      user: %{
        id: Base.url_encode64(:binary.encode_unsigned(customer.id), padding: false),
        name: customer.email,
        displayName: customer.email
      },
      pubKeyCredParams: [
        %{type: "public-key", alg: -7},
        %{type: "public-key", alg: -257}
      ],
      timeout: 60_000,
      attestation: "none",
      authenticatorSelection: %{
        residentKey: "discouraged",
        userVerification: "preferred"
      }
    }

    {challenge, opts}
  end

  @doc """
  Verifies a WebAuthn registration attestation from the browser.
  `credential_json` is the JSON string sent by the browser.
  `challenge` is the %Wax.Challenge{} from webauthn_registration_options/1.
  `label` is the user-given name for the key.
  Returns {:ok, credential} or {:error, reason}.
  """
  def register_webauthn_credential(%Customer{} = customer, challenge, credential_json, label) do
    with {:ok, credential_map} <- Jason.decode(credential_json),
         %{
           "response" => %{
             "attestationObject" => att_b64,
             "clientDataJSON" => client_data_b64
           }
         } <- credential_map,
         {:ok, attestation_object} <- Base.url_decode64(att_b64, padding: false),
         {:ok, client_data_json} <- Base.url_decode64(client_data_b64, padding: false),
         {:ok, {auth_data, _att_result}} <-
           Wax.register(attestation_object, client_data_json, challenge) do
      credential_id = auth_data.attested_credential_data.credential_id
      cose_key = auth_data.attested_credential_data.credential_public_key
      public_key_cbor = :erlang.term_to_binary(cose_key)

      %Pretex.Customers.CustomerWebAuthnCredential{}
      |> Ecto.Changeset.change(%{
        credential_id: credential_id,
        public_key_cbor: public_key_cbor,
        sign_count: 0,
        label: label,
        customer_id: customer.id
      })
      |> Repo.insert()
    else
      err -> {:error, err}
    end
  end

  @doc """
  Builds the authentication options (allowCredentials list + challenge) for a customer.
  Returns {challenge, auth_options_map}.
  """
  def webauthn_authentication_options(%Customer{} = customer) do
    credentials = list_webauthn_credentials(customer)

    allow_credentials =
      Enum.map(credentials, fn c ->
        {c.credential_id, :erlang.binary_to_term(c.public_key_cbor, [:safe])}
      end)

    challenge =
      Wax.new_authentication_challenge(
        origin: "http://localhost:4000",
        rp_id: "localhost",
        allow_credentials: allow_credentials
      )

    opts = %{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      rpId: "localhost",
      timeout: 60_000,
      userVerification: "preferred",
      allowCredentials:
        Enum.map(credentials, fn c ->
          %{type: "public-key", id: Base.url_encode64(c.credential_id, padding: false)}
        end)
    }

    {challenge, opts}
  end

  @doc """
  Verifies a WebAuthn assertion from the browser during login.
  Returns {:ok, customer} or {:error, reason}.
  """
  def verify_webauthn_assertion(%Customer{} = customer, challenge, assertion_json) do
    with {:ok, assertion_map} <- Jason.decode(assertion_json),
         %{
           "id" => id_b64,
           "response" => %{
             "authenticatorData" => auth_data_b64,
             "clientDataJSON" => client_data_b64,
             "signature" => sig_b64
           }
         } <- assertion_map,
         {:ok, credential_id} <- Base.url_decode64(id_b64, padding: false),
         credential =
           Repo.get_by(Pretex.Customers.CustomerWebAuthnCredential,
             credential_id: credential_id
           ),
         true <- not is_nil(credential) and credential.customer_id == customer.id,
         {:ok, auth_data_bin} <- Base.url_decode64(auth_data_b64, padding: false),
         {:ok, client_data_json} <- Base.url_decode64(client_data_b64, padding: false),
         {:ok, signature} <- Base.url_decode64(sig_b64, padding: false),
         cose_key = :erlang.binary_to_term(credential.public_key_cbor, [:safe]),
         {:ok, auth_data} <-
           Wax.authenticate(
             credential_id,
             auth_data_bin,
             signature,
             client_data_json,
             challenge,
             [{credential_id, cose_key}]
           ) do
      credential
      |> Ecto.Changeset.change(
        sign_count: auth_data.sign_count,
        last_used_at: DateTime.utc_now(:second)
      )
      |> Repo.update!()

      {:ok, customer}
    else
      _ -> {:error, :invalid_assertion}
    end
  end
end
