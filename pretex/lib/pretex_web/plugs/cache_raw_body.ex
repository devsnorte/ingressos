defmodule PretexWeb.Plugs.CacheRawBody do
  @moduledoc """
  Plug that reads and caches the raw request body **before** `Plug.Parsers`
  consumes it.

  This is required for webhook signature verification (e.g. Stripe, Woovi)
  because HMAC signatures are computed over the exact raw bytes of the request
  body. Once `Plug.Parsers` has parsed the body, the original bytes are no
  longer available.

  ## Usage

  Mount this plug in the endpoint *before* `Plug.Parsers`, scoped only to the
  webhook pipeline to avoid the memory overhead for all other requests:

      # In PretexWeb.Endpoint, before Plug.Parsers:
      plug PretexWeb.Plugs.CacheRawBody, only: ["/webhooks"]

  The raw body is stored under `conn.private[:raw_body]` and can be retrieved
  in any downstream plug or controller:

      raw = conn.private[:raw_body]   # binary or ""
  """

  @behaviour Plug

  @default_max_length 4_000_000

  @impl Plug
  def init(opts) do
    %{
      only: Keyword.get(opts, :only, []),
      max_length: Keyword.get(opts, :max_length, @default_max_length)
    }
  end

  @impl Plug
  def call(conn, %{only: [], max_length: max_length}) do
    cache_body(conn, max_length)
  end

  def call(conn, %{only: paths, max_length: max_length}) do
    if Enum.any?(paths, &String.starts_with?(conn.request_path, &1)) do
      cache_body(conn, max_length)
    else
      conn
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp cache_body(conn, max_length) do
    case Plug.Conn.read_body(conn, length: max_length) do
      {:ok, body, conn} ->
        Plug.Conn.put_private(conn, :raw_body, body)

      {:more, partial, conn} ->
        # Body is larger than max_length — store what we have.
        # Signature verification will fail downstream, which is the correct
        # behaviour for oversized/malformed webhook payloads.
        Plug.Conn.put_private(conn, :raw_body, partial)

      {:error, _reason} ->
        Plug.Conn.put_private(conn, :raw_body, "")
    end
  end
end
