defmodule Pretex.Payments.Adapters.Manual do
  @behaviour Pretex.Payments.Adapter

  @impl true
  def display_name, do: "Manual / Transferência Bancária"

  @impl true
  def description,
    do:
      "Pagamento manual confirmado pelo organizador. Aceita transferência, depósito ou qualquer forma offline."

  @impl true
  def required_fields,
    do: [
      %{key: "bank_info", label: "Informações bancárias (exibidas ao comprador)", type: :text}
    ]

  @impl true
  def payment_methods, do: ["bank_transfer", "cash"]

  @impl true
  def validate_credentials(_config), do: {:ok, :valid}

  @impl true
  def create_payment(_config, _amount, _currency, _metadata) do
    ref = "manual_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def refund(_config, _payment_ref, _amount) do
    ref = "manual_refund_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    {:ok, ref}
  end

  @impl true
  def parse_webhook(_config, _raw_body, _headers), do: {:error, :invalid_signature}
end
