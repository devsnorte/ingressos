defmodule Pretex.Payments.Adapters.AbacatePay do
  @behaviour Pretex.Payments.Adapter

  @impl true
  def display_name, do: "AbacatePay"

  @impl true
  def description,
    do: "Pagamentos via Pix e boleto com a AbacatePay. Gateway brasileiro com taxas competitivas."

  @impl true
  def required_fields,
    do: [
      %{key: "api_key", label: "API Key", type: :password},
      %{key: "webhook_secret", label: "Webhook Secret", type: :password}
    ]

  @impl true
  def payment_methods, do: ["pix", "boleto"]

  @impl true
  def validate_credentials(%{"api_key" => key}) when is_binary(key) and byte_size(key) > 0 do
    {:ok, :valid}
  end

  def validate_credentials(_), do: {:error, "API Key é obrigatória"}

  @impl true
  def create_payment(_config, _amount, _currency, _metadata) do
    ref = "abacate_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def refund(_config, _payment_ref, _amount) do
    ref = "abacate_refund_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def parse_webhook(%{"webhook_secret" => _secret}, _raw_body, _headers) do
    {:ok, %{type: "payment.confirmed"}}
  end

  def parse_webhook(_, _, _), do: {:error, :invalid_signature}
end
