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

  # ---------------------------------------------------------------------------
  # TOTP
  # ---------------------------------------------------------------------------

  @doc "Generates a fresh TOTP secret (raw binary)."
  def generate_totp_secret, do: NimbleTOTP.secret()

  @doc "Returns the otpauth URI for the QR code."
  def totp_uri(%User{email: email}, secret) do
    NimbleTOTP.otpauth_uri("Pretex:#{email}", secret, issuer: "Pretex")
  end

  @doc """
  Returns an SVG string (safe for embedding) of the QR code for the TOTP setup URI.
  The secret passed here is the raw binary from generate_totp_secret/0.
  """
  def totp_qr_svg(%User{} = user, secret) do
    user
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
  Enables TOTP for the user: stores the secret and sets totp_enabled_at.
  Should only be called after valid_totp_code? returns true.
  """
  def enable_totp(%User{} = user, secret) do
    user
    |> Ecto.Changeset.change(totp_secret: secret, totp_enabled_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  @doc "Disables TOTP for the user."
  def disable_totp(%User{} = user) do
    user
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
  def generate_recovery_codes(%User{} = user) do
    Repo.delete_all(from(r in Pretex.Accounts.UserRecoveryCode, where: r.user_id == ^user.id))

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
      %Pretex.Accounts.UserRecoveryCode{}
      |> Ecto.Changeset.change(code_hash: hash, user_id: user.id)
      |> Repo.insert!()
    end)

    Enum.map(codes, fn {plain, _} -> plain end)
  end

  @doc """
  Attempts to use a recovery code for the user.
  Returns :ok if found and unused, :error otherwise.
  Marks the code as used.
  """
  def use_recovery_code(%User{} = user, code) do
    hash =
      :crypto.hash(:sha256, String.upcase(String.trim(code)))
      |> Base.encode16(case: :lower)

    query =
      from(r in Pretex.Accounts.UserRecoveryCode,
        where: r.user_id == ^user.id and r.code_hash == ^hash and is_nil(r.used_at)
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

  @doc "Returns the count of remaining unused recovery codes for the user."
  def remaining_recovery_codes(%User{} = user) do
    Repo.aggregate(
      from(r in Pretex.Accounts.UserRecoveryCode,
        where: r.user_id == ^user.id and is_nil(r.used_at)
      ),
      :count
    )
  end

  # ---------------------------------------------------------------------------
  # WebAuthn
  # ---------------------------------------------------------------------------

  @doc "Lists all WebAuthn credentials for a user."
  def list_webauthn_credentials(%User{id: id}) do
    Repo.all(from(c in Pretex.Accounts.UserWebAuthnCredential, where: c.user_id == ^id))
  end

  @doc """
  Starts a WebAuthn registration for the user.
  Returns {challenge, creation_options_map} where challenge is a %Wax.Challenge{} and
  creation_options_map is ready to be JSON-encoded and sent to the browser.
  """
  def webauthn_registration_options(%User{} = user) do
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
        id: Base.url_encode64(:binary.encode_unsigned(user.id), padding: false),
        name: user.email,
        displayName: user.email
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
  def register_webauthn_credential(%User{} = user, challenge, credential_json, label) do
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

      %Pretex.Accounts.UserWebAuthnCredential{}
      |> Ecto.Changeset.change(%{
        credential_id: credential_id,
        public_key_cbor: public_key_cbor,
        sign_count: 0,
        label: label,
        user_id: user.id
      })
      |> Repo.insert()
    else
      err -> {:error, err}
    end
  end

  @doc """
  Builds the authentication options (allowCredentials list + challenge) for a user.
  Returns {challenge, auth_options_map}.
  """
  def webauthn_authentication_options(%User{} = user) do
    credentials = list_webauthn_credentials(user)

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
  Returns {:ok, user} or {:error, reason}.
  """
  def verify_webauthn_assertion(%User{} = user, challenge, assertion_json) do
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
           Repo.get_by(Pretex.Accounts.UserWebAuthnCredential, credential_id: credential_id),
         true <- not is_nil(credential) and credential.user_id == user.id,
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

      {:ok, user}
    else
      _ -> {:error, :invalid_assertion}
    end
  end
end
