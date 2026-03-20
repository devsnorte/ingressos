defmodule Pretex.Payments.Adapters.Woovi do
  @behaviour Pretex.Payments.Adapter

  @impl true
  def display_name, do: "Woovi (Pix)"

  @impl true
  def description,
    do:
      "Pagamentos via Pix usando a plataforma Woovi (OpenPix). Confirmação instantânea via webhook."

  @impl true
  def required_fields,
    do: [
      %{key: "app_id", label: "App ID", type: :text},
      %{key: "api_key", label: "API Key", type: :password},
      %{key: "webhook_secret", label: "Webhook Secret", type: :password}
    ]

  @impl true
  def payment_methods, do: ["pix"]

  @impl true
  def validate_credentials(%{"api_key" => api_key})
      when is_binary(api_key) and byte_size(api_key) > 0 do
    # In production: make a GET request to Woovi API to verify the key
    # For now, validate format
    {:ok, :valid}
  end

  def validate_credentials(_), do: {:error, "API Key é obrigatória"}

  @impl true
  def create_payment(_config, _amount, _currency, _metadata) do
    # In production: POST to Woovi API to create a Pix charge
    ref = "woovi_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def refund(_config, _payment_ref, _amount) do
    ref = "woovi_refund_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def parse_webhook(%{"webhook_secret" => _secret}, _raw_body, _headers) do
    # In production: verify HMAC signature
    {:ok, %{type: "charge.completed"}}
  end

  def parse_webhook(_, _, _), do: {:error, :invalid_signature}
end
