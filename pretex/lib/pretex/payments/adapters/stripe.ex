defmodule Pretex.Payments.Adapters.Stripe do
  @behaviour Pretex.Payments.Adapter

  @impl true
  def display_name, do: "Stripe"

  @impl true
  def description,
    do:
      "Cartão de crédito, débito e métodos internacionais via Stripe. Suporta Pix via Stripe também."

  @impl true
  def required_fields,
    do: [
      %{key: "secret_key", label: "Secret Key (sk_...)", type: :password},
      %{key: "publishable_key", label: "Publishable Key (pk_...)", type: :text},
      %{key: "webhook_secret", label: "Webhook Signing Secret (whsec_...)", type: :password}
    ]

  @impl true
  def payment_methods, do: ["credit_card", "debit_card", "pix"]

  @impl true
  def validate_credentials(%{"secret_key" => key}) when is_binary(key) do
    cond do
      String.starts_with?(key, "sk_test_") -> {:ok, :valid}
      String.starts_with?(key, "sk_live_") -> {:ok, :valid}
      true -> {:error, "Secret Key deve começar com sk_test_ ou sk_live_"}
    end
  end

  def validate_credentials(_), do: {:error, "Secret Key é obrigatória"}

  @impl true
  def create_payment(_config, _amount, _currency, _metadata) do
    ref = "stripe_pi_#{:crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def refund(_config, _payment_ref, _amount) do
    ref = "stripe_re_#{:crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def parse_webhook(%{"webhook_secret" => _secret}, _raw_body, _headers) do
    {:ok, %{type: "payment_intent.succeeded"}}
  end

  def parse_webhook(_, _, _), do: {:error, :invalid_signature}
end
