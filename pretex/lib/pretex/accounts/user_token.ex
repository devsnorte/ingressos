defmodule Pretex.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query

  @hash_algorithm :sha256
  @rand_size 32

  # Session tokens are valid for 60 days
  @session_validity_in_days 60

  # Magic link tokens are valid for 10 minutes
  @magic_link_validity_in_minutes 10

  schema "user_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string

    belongs_to :user, Pretex.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "Builds a raw-binary session token. Returns {token, struct}."
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %__MODULE__{token: token, context: "session", user_id: user.id}}
  end

  @doc "Returns an Ecto query that resolves a session token to a user."
  def verify_session_token_query(token) do
    query =
      from t in __MODULE__,
        join: u in assoc(t, :user),
        where:
          t.token == ^token and
            t.context == "session" and
            t.inserted_at > ago(@session_validity_in_days, "day"),
        select: u

    {:ok, query}
  end

  @doc """
  Builds a hashed magic-link token.
  Returns {url_encoded_raw_token, struct} — only the struct is stored.
  """
  def build_magic_link_token(user) do
    raw = :crypto.strong_rand_bytes(@rand_size)
    hashed = :crypto.hash(@hash_algorithm, raw)
    encoded = Base.url_encode64(raw, padding: false)

    {encoded,
     %__MODULE__{
       token: hashed,
       context: "magic_link",
       sent_to: user.email,
       user_id: user.id
     }}
  end

  @doc "Returns {:ok, query} or :error for a magic-link token from a URL."
  def verify_magic_link_token_query(encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, raw} ->
        hashed = :crypto.hash(@hash_algorithm, raw)
        min = @magic_link_validity_in_minutes

        query =
          from t in __MODULE__,
            join: u in assoc(t, :user),
            where:
              t.token == ^hashed and
                t.context == "magic_link" and
                t.inserted_at > ago(^min, "minute"),
            select: {u, t}

        {:ok, query}

      :error ->
        :error
    end
  end
end
