defmodule Pretex.Payments.Adapter do
  @moduledoc """
  Behaviour for payment provider adapters.
  Each gateway implements this contract.
  """

  @doc "Human-readable display name for this provider type"
  @callback display_name() :: String.t()

  @doc "Description of the provider"
  @callback description() :: String.t()

  @doc "List of credential fields required by this provider"
  @callback required_fields() :: [%{key: String.t(), label: String.t(), type: :text | :password}]

  @doc "Supported payment methods"
  @callback payment_methods() :: [String.t()]

  @doc "Validate provider credentials without charging"
  @callback validate_credentials(config :: map()) ::
              {:ok, :valid} | {:error, String.t()}

  @doc "Create a payment"
  @callback create_payment(
              config :: map(),
              amount :: integer(),
              currency :: String.t(),
              metadata :: map()
            ) ::
              {:ok, payment_ref :: String.t()}
              | {:redirect, url :: String.t()}
              | {:error, String.t()}

  @doc "Process a refund"
  @callback refund(config :: map(), payment_ref :: String.t(), amount :: integer()) ::
              {:ok, refund_ref :: String.t()} | {:error, String.t()}

  @doc "Parse and validate an incoming webhook payload"
  @callback parse_webhook(config :: map(), raw_body :: binary(), headers :: map()) ::
              {:ok, event :: map()} | {:error, :invalid_signature}
end
