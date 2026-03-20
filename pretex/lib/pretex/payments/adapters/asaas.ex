defmodule Pretex.Payments.Adapters.Asaas do
  @behaviour Pretex.Payments.Adapter

  @impl true
  def display_name, do: "Asaas"

  @impl true
  def description,
    do:
      "Cobranças via Pix, boleto e cartão com Asaas. Plataforma completa de pagamentos para o Brasil."

  @impl true
  def required_fields,
    do: [
      %{key: "api_key", label: "API Key ($aact_...)", type: :password},
      %{key: "webhook_token", label: "Webhook Token", type: :password}
    ]

  @impl true
  def payment_methods, do: ["pix", "boleto", "credit_card"]

  @impl true
  def validate_credentials(%{"api_key" => key}) when is_binary(key) do
    if String.starts_with?(key, "$aact_") do
      {:ok, :valid}
    else
      {:error, "API Key deve começar com $aact_"}
    end
  end

  def validate_credentials(_), do: {:error, "API Key é obrigatória"}

  @impl true
  def create_payment(_config, _amount, _currency, _metadata) do
    ref = "asaas_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def refund(_config, _payment_ref, _amount) do
    ref = "asaas_refund_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def parse_webhook(%{"webhook_token" => _token}, _raw_body, _headers) do
    {:ok, %{type: "PAYMENT_CONFIRMED"}}
  end

  def parse_webhook(_, _, _), do: {:error, :invalid_signature}
end
