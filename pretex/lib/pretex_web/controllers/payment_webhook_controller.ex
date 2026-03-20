defmodule PretexWeb.PaymentWebhookController do
  @moduledoc """
  Handles incoming payment webhooks from configured gateways.

  Each provider is identified by a unique `webhook_token` embedded in the URL:

      POST /webhooks/payments/:token

  The raw request body is read **before** any JSON parsing so that gateway
  signature verification (HMAC, Stripe-Signature header, etc.) works correctly.
  The raw body is stored in `conn.private[:raw_body]` by the
  `PretexWeb.Plugs.CacheRawBody` plug, which must be placed before
  `Plug.Parsers` in the endpoint pipeline for webhook routes.

  Responses:
  - 200 OK          — webhook accepted and processed (or safely ignored)
  - 400 Bad Request — signature invalid or malformed payload
  - 404 Not Found   — unknown webhook token
  """

  use PretexWeb, :controller

  require Logger

  alias Pretex.Payments

  @doc """
  Receives a payment webhook, verifies the signature, and dispatches the event.
  """
  def receive(conn, %{"token" => token}) do
    raw_body = get_raw_body(conn)
    headers = conn.req_headers |> Map.new()

    Logger.info("PaymentWebhook: received for token=#{String.slice(token, 0, 8)}...")

    case Payments.handle_webhook(token, raw_body, headers) do
      {:ok, :processed} ->
        Logger.info(
          "PaymentWebhook: processed successfully for token=#{String.slice(token, 0, 8)}"
        )

        send_resp(conn, 200, "ok")

      {:error, :unknown_token} ->
        Logger.warning("PaymentWebhook: unknown token=#{String.slice(token, 0, 8)}")
        send_resp(conn, 404, "not found")

      {:error, :invalid_signature} ->
        Logger.warning("PaymentWebhook: invalid signature for token=#{String.slice(token, 0, 8)}")

        send_resp(conn, 400, "invalid signature")

      {:error, reason} ->
        Logger.error(
          "PaymentWebhook: unexpected error for token=#{String.slice(token, 0, 8)}: #{inspect(reason)}"
        )

        # Return 200 to prevent the provider from retrying for internal errors.
        # We log and investigate separately.
        send_resp(conn, 200, "ok")
    end
  end

  # ---------------------------------------------------------------------------
  # Raw body extraction
  # ---------------------------------------------------------------------------

  # Primary: raw body cached by PretexWeb.Plugs.CacheRawBody before Plug.Parsers
  defp get_raw_body(%Plug.Conn{private: %{raw_body: body}}) when is_binary(body), do: body

  # Fallback: if the body hasn't been parsed yet (e.g. in tests), read it directly.
  # This will return an empty binary if Plug.Parsers has already consumed the body.
  defp get_raw_body(conn) do
    case Plug.Conn.read_body(conn, length: 1_000_000) do
      {:ok, body, _conn} -> body
      _ -> ""
    end
  end
end
