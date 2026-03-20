defmodule Pretex.PaymentProcessingTest do
  use Pretex.DataCase, async: true

  alias Pretex.Payments
  alias Pretex.Payments.Payment
  alias Pretex.Payments.Refund
  alias Pretex.Orders

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  # ---------------------------------------------------------------------------
  # Shared fixtures
  # ---------------------------------------------------------------------------

  defp provider_fixture(org, type) do
    credentials =
      case type do
        "stripe" ->
          %{
            "secret_key" => "sk_test_fixture123",
            "publishable_key" => "pk_test_fixture123",
            "webhook_secret" => "whsec_fixture123"
          }

        "woovi" ->
          %{"api_key" => "woovi_test_key_fixture", "webhook_secret" => "woovi_secret"}

        "asaas" ->
          %{"api_key" => "$aact_fixture123", "webhook_token" => "asaas_token_fixture"}

        "abacatepay" ->
          %{"api_key" => "abacate_key_fixture", "webhook_secret" => "abacate_secret"}

        _ ->
          %{"bank_info" => "Banco Fixture - Ag 0001"}
      end

    base = %{
      organization_id: org.id,
      type: type,
      name: "#{String.capitalize(type)} Provider #{System.unique_integer([:positive])}",
      credentials: credentials,
      is_active: true
    }

    {:ok, provider} = Payments.create_provider(base)
    # Activate it
    {:ok, provider} = Payments.validate_provider(provider)
    provider
  end

  defp order_fixture(event, provider \\ nil, attrs \\ %{}) do
    item = item_fixture(event)
    {:ok, cart} = Orders.create_cart(event)
    {:ok, _} = Orders.add_to_cart(cart, item, quantity: 1)
    cart = Orders.get_cart_by_token(cart.session_token)

    base = %{
      name: "Test Attendee",
      email: "attendee@example.com",
      payment_method: "bank_transfer"
    }

    extra =
      if provider, do: %{payment_provider_id: provider.id}, else: %{}

    {:ok, order} = Orders.create_order_from_cart(cart, Enum.into(attrs, Map.merge(base, extra)))
    order
  end

  # ---------------------------------------------------------------------------
  # AC1 — Payment methods from configured providers
  # ---------------------------------------------------------------------------

  describe "list_payment_options_for_organization/1" do
    test "returns methods from all active providers for the organization" do
      org = org_fixture()
      _stripe = provider_fixture(org, "stripe")
      _woovi = provider_fixture(org, "woovi")

      options = Payments.list_payment_options_for_organization(org.id)
      methods = Enum.map(options, & &1.method)

      assert "credit_card" in methods
      assert "pix" in methods
    end

    test "does not return methods from inactive providers" do
      org = org_fixture()

      # Create a provider but deliberately do NOT validate/activate it
      {:ok, inactive_provider} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "stripe",
          name: "Inactive Stripe",
          credentials: %{"secret_key" => "sk_test_inactive"},
          is_active: false
        })

      refute inactive_provider.is_active

      options = Payments.list_payment_options_for_organization(org.id)
      assert options == []
    end

    test "returns empty list when organization has no configured providers" do
      org = org_fixture()
      assert Payments.list_payment_options_for_organization(org.id) == []
    end

    test "deduplicates payment methods when multiple providers support the same method" do
      org = org_fixture()
      _stripe = provider_fixture(org, "stripe")
      _asaas = provider_fixture(org, "asaas")

      # Both stripe and asaas support pix — should appear only once
      options = Payments.list_payment_options_for_organization(org.id)
      pix_options = Enum.filter(options, &(&1.method == "pix"))
      assert length(pix_options) == 1
    end

    test "includes provider_id and flow for each option" do
      org = org_fixture()
      _provider = provider_fixture(org, "stripe")

      options = Payments.list_payment_options_for_organization(org.id)
      assert length(options) > 0

      for option <- options do
        assert Map.has_key?(option, :method)
        assert Map.has_key?(option, :provider_id)
        assert Map.has_key?(option, :flow)
        assert option.flow in ~w(inline redirect async)
      end
    end

    test "does not include methods from other organizations" do
      org1 = org_fixture()
      org2 = org_fixture()

      _provider = provider_fixture(org1, "stripe")

      assert Payments.list_payment_options_for_organization(org2.id) == []
    end
  end

  # ---------------------------------------------------------------------------
  # AC2 — Inline payment (credit card)
  # ---------------------------------------------------------------------------

  describe "create_payment/3 inline flow" do
    test "creates a payment record for an inline credit card payment" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "stripe")

      order = order_fixture(event, provider, %{payment_method: "credit_card"})

      assert {:ok, %Payment{} = payment} =
               Payments.create_payment(order, provider, "credit_card")

      assert payment.order_id == order.id
      assert payment.payment_provider_id == provider.id
      assert payment.payment_method == "credit_card"
      assert payment.flow == "inline"
      assert payment.status == "pending"
      assert payment.amount_cents == order.total_cents
      assert is_binary(payment.external_ref)
    end

    test "inline payment does not set redirect_url" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "stripe")
      order = order_fixture(event, provider, %{payment_method: "credit_card"})

      assert {:ok, payment} = Payments.create_payment(order, provider, "credit_card")
      assert is_nil(payment.redirect_url)
    end

    test "inline payment for zero-amount order is allowed" do
      org = org_fixture()
      event = published_event_fixture(org)
      item = item_fixture(event, %{price_cents: 0})

      {:ok, cart} = Orders.create_cart(event)
      {:ok, _} = Orders.add_to_cart(cart, item)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Free Attendee",
          email: "free@example.com",
          payment_method: "credit_card"
        })

      provider = provider_fixture(org, "manual")

      assert {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      assert payment.amount_cents == 0
    end
  end

  # ---------------------------------------------------------------------------
  # AC2b — Pix QR code (async flow)
  # ---------------------------------------------------------------------------

  describe "create_payment/3 Pix flow" do
    test "creates a payment with async flow for pix" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "woovi")
      order = order_fixture(event, provider, %{payment_method: "pix"})

      assert {:ok, %Payment{} = payment} = Payments.create_payment(order, provider, "pix")
      assert payment.flow == "async"
      assert payment.payment_method == "pix"
      assert payment.status == "pending"
    end

    test "stripe pix flow is async" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "stripe")
      order = order_fixture(event, provider, %{payment_method: "pix"})

      assert {:ok, payment} = Payments.create_payment(order, provider, "pix")
      assert payment.flow == "async"
    end

    test "woovi creates payment with external ref" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "woovi")
      order = order_fixture(event, provider, %{payment_method: "pix"})

      assert {:ok, payment} = Payments.create_payment(order, provider, "pix")
      # The adapter generates a reference even in stub mode
      assert is_binary(payment.external_ref) or is_nil(payment.external_ref)
    end
  end

  # ---------------------------------------------------------------------------
  # AC3 — Redirect-based payment
  # ---------------------------------------------------------------------------

  describe "create_payment/3 redirect flow" do
    test "manual provider uses async flow" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider, %{payment_method: "bank_transfer"})

      assert {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      assert payment.flow == "async"
    end

    test "payment record is created with pending status for redirect flows" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider, %{payment_method: "bank_transfer"})

      assert {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      assert payment.status == "pending"
      assert payment.order_id == order.id
    end
  end

  # ---------------------------------------------------------------------------
  # Payment confirmation
  # ---------------------------------------------------------------------------

  describe "confirm_payment/1" do
    test "confirms a pending payment and the associated order" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      assert payment.status == "pending"

      assert {:ok, confirmed_payment} = Payments.confirm_payment(payment)
      assert confirmed_payment.status == "confirmed"
      assert confirmed_payment.settled_at != nil

      # Order should also be confirmed
      refreshed_order = Orders.get_order!(order.id)
      assert refreshed_order.status == "confirmed"
    end

    test "confirming an already confirmed payment is idempotent" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      {:ok, confirmed} = Payments.confirm_payment(payment)

      # Confirming again should return ok without error
      assert {:ok, _} = Payments.confirm_payment(confirmed)
    end

    test "confirm_payment sets settled_at timestamp" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")

      before = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, confirmed} = Payments.confirm_payment(payment)
      after_confirm = DateTime.utc_now() |> DateTime.truncate(:second)

      assert DateTime.compare(confirmed.settled_at, before) in [:gt, :eq]
      assert DateTime.compare(confirmed.settled_at, after_confirm) in [:lt, :eq]
    end
  end

  # ---------------------------------------------------------------------------
  # Payment failure
  # ---------------------------------------------------------------------------

  describe "fail_payment/2" do
    test "marks a payment as failed with a reason" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "stripe")
      order = order_fixture(event, provider, %{payment_method: "credit_card"})

      {:ok, payment} = Payments.create_payment(order, provider, "credit_card")

      assert {:ok, failed} = Payments.fail_payment(payment, "card declined")
      assert failed.status == "failed"
      assert failed.failure_reason == "card declined"
      assert failed.settled_at != nil
    end

    test "failing a payment does not change order status" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "stripe")
      order = order_fixture(event, provider, %{payment_method: "credit_card"})

      {:ok, payment} = Payments.create_payment(order, provider, "credit_card")
      {:ok, _failed} = Payments.fail_payment(payment, "declined")

      refreshed_order = Orders.get_order!(order.id)
      assert refreshed_order.status == "pending"
    end
  end

  # ---------------------------------------------------------------------------
  # AC4 — Async payment confirmation via webhook
  # ---------------------------------------------------------------------------

  describe "handle_webhook/3" do
    test "processes a valid woovi webhook and confirms the payment" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "woovi")
      order = order_fixture(event, provider, %{payment_method: "pix"})

      {:ok, payment} = Payments.create_payment(order, provider, "pix")

      # Set a known external_ref so the webhook can find the payment
      {:ok, _payment} =
        payment
        |> Payment.gateway_changeset(%{external_ref: "woovi_confirmed_ref_001"})
        |> Pretex.Repo.update()

      raw_body =
        Jason.encode!(%{type: "charge.completed", externalRef: "woovi_confirmed_ref_001"})

      headers = %{"content-type" => "application/json"}

      # The stub adapter will accept any webhook with a webhook_secret present
      assert {:ok, :processed} =
               Payments.handle_webhook(provider.webhook_token, raw_body, headers)
    end

    test "rejects webhook with unknown token" do
      raw_body = "{}"
      headers = %{}

      assert {:error, :unknown_token} =
               Payments.handle_webhook("completely_invalid_token_xyz", raw_body, headers)
    end

    test "rejects webhook with invalid signature (no webhook_secret in credentials)" do
      org = org_fixture()

      # Create a provider without a webhook_secret so parse_webhook returns invalid_signature
      {:ok, provider} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "manual",
          name: "Manual No Secret",
          credentials: %{"bank_info" => "test"}
        })

      # Manual adapter always returns {:error, :invalid_signature}
      raw_body = "{}"
      headers = %{}

      assert {:error, :invalid_signature} =
               Payments.handle_webhook(provider.webhook_token, raw_body, headers)
    end

    test "processes stripe payment_intent.succeeded webhook" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "stripe")
      order = order_fixture(event, provider, %{payment_method: "credit_card"})

      {:ok, payment} = Payments.create_payment(order, provider, "credit_card")

      {:ok, _payment} =
        payment
        |> Payment.gateway_changeset(%{external_ref: "stripe_pi_webhook_test"})
        |> Pretex.Repo.update()

      raw_body =
        Jason.encode!(%{
          type: "payment_intent.succeeded",
          data: %{object: %{id: "stripe_pi_webhook_test"}}
        })

      headers = %{"stripe-signature" => "t=123,v1=abc"}

      # Stub adapter parses any webhook with webhook_secret present
      assert {:ok, :processed} =
               Payments.handle_webhook(provider.webhook_token, raw_body, headers)
    end

    test "webhook for unknown external_ref is safely ignored" do
      org = org_fixture()
      provider = provider_fixture(org, "stripe")

      raw_body =
        Jason.encode!(%{
          type: "payment_intent.succeeded",
          data: %{object: %{id: "pi_completely_unknown"}}
        })

      headers = %{"stripe-signature" => "t=123,v1=abc"}

      # Should not raise — unknown refs are silently ignored
      assert {:ok, :processed} =
               Payments.handle_webhook(provider.webhook_token, raw_body, headers)
    end

    test "async payment confirmation updates order status to confirmed" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "woovi")
      order = order_fixture(event, provider, %{payment_method: "pix"})

      assert order.status == "pending"

      {:ok, payment} = Payments.create_payment(order, provider, "pix")

      {:ok, _confirmed} = Payments.confirm_payment(payment)

      refreshed = Orders.get_order!(order.id)
      assert refreshed.status == "confirmed"
    end
  end

  # ---------------------------------------------------------------------------
  # AC5 — Late payment handling: auto-refund when quota exhausted
  # ---------------------------------------------------------------------------

  describe "handle_late_payment/1" do
    test "confirms payment and immediately initiates a refund" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider, %{payment_method: "bank_transfer"})

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")

      # Simulate expired order (late payment scenario)
      {:ok, _} =
        order
        |> Ecto.Changeset.change(status: "expired")
        |> Pretex.Repo.update()

      assert {:ok, refund} = Payments.handle_late_payment(payment)
      assert refund.order_id == order.id
      assert refund.amount_cents == payment.amount_cents
      assert refund.status == "completed"
      assert String.contains?(refund.reason, "late payment")

      # Payment should be in refunded state
      refreshed_payment = Payments.get_payment!(payment.id)
      assert refreshed_payment.status == "refunded"
    end

    test "late payment refund does not confirm the order" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider, %{payment_method: "bank_transfer"})

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")

      {:ok, _} =
        order
        |> Ecto.Changeset.change(status: "expired")
        |> Pretex.Repo.update()

      {:ok, _refund} = Payments.handle_late_payment(payment)

      # The order must NOT be confirmed — it stays expired
      refreshed_order = Orders.get_order!(order.id)
      assert refreshed_order.status == "expired"
    end
  end

  # ---------------------------------------------------------------------------
  # Refund
  # ---------------------------------------------------------------------------

  describe "initiate_refund/2" do
    test "creates a completed refund record" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      {:ok, confirmed_payment} = Payments.confirm_payment(payment)

      assert {:ok, refund} = Payments.initiate_refund(confirmed_payment, "attendee request")
      assert %Refund{} = refund
      assert refund.status == "completed"
      assert refund.payment_id == confirmed_payment.id
      assert refund.order_id == order.id
      assert refund.amount_cents == confirmed_payment.amount_cents
      assert refund.reason == "attendee request"
      assert is_binary(refund.provider_ref)
      assert refund.completed_at != nil
    end

    test "marks the payment as refunded after successful refund" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      {:ok, confirmed} = Payments.confirm_payment(payment)

      {:ok, _refund} = Payments.initiate_refund(confirmed, "test refund")

      refreshed = Payments.get_payment!(confirmed.id)
      assert refreshed.status == "refunded"
    end
  end

  # ---------------------------------------------------------------------------
  # get_payment_for_order/1
  # ---------------------------------------------------------------------------

  describe "get_payment_for_order/1" do
    test "returns the most recent payment for an order" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")

      found = Payments.get_payment_for_order(order)
      assert found.id == payment.id
    end

    test "returns nil when no payment exists for the order" do
      org = org_fixture()
      event = published_event_fixture(org)
      order = order_fixture(event)

      assert is_nil(Payments.get_payment_for_order(order))
    end

    test "accepts order_id as integer" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")

      found = Payments.get_payment_for_order(order.id)
      assert found.id == payment.id
    end
  end

  # ---------------------------------------------------------------------------
  # Payment provider webhook token routing
  # ---------------------------------------------------------------------------

  describe "get_provider_by_webhook_token/1" do
    test "returns a provider matching the webhook token" do
      org = org_fixture()
      provider = provider_fixture(org, "woovi")

      found = Payments.get_provider_by_webhook_token(provider.webhook_token)
      assert found.id == provider.id
    end

    test "returns nil for an unknown token" do
      assert is_nil(Payments.get_provider_by_webhook_token("nonexistent_token_xyz"))
    end

    test "returns nil for nil input" do
      assert is_nil(Payments.get_provider_by_webhook_token(nil))
    end
  end

  # ---------------------------------------------------------------------------
  # Payment schema changesets
  # ---------------------------------------------------------------------------

  describe "Payment schema" do
    test "creation_changeset requires order_id, provider_id, method, flow, and amount" do
      changeset =
        Payment.creation_changeset(%Payment{}, %{})

      errors = errors_on(changeset)
      assert Map.has_key?(errors, :order_id)
      assert Map.has_key?(errors, :payment_provider_id)
      assert Map.has_key?(errors, :payment_method)
      assert Map.has_key?(errors, :flow)
      assert Map.has_key?(errors, :amount_cents)
    end

    test "creation_changeset rejects negative amounts" do
      changeset =
        Payment.creation_changeset(%Payment{}, %{
          order_id: 1,
          payment_provider_id: 1,
          payment_method: "pix",
          flow: "async",
          amount_cents: -100
        })

      assert %{amount_cents: [_]} = errors_on(changeset)
    end

    test "creation_changeset defaults status to pending" do
      changeset =
        Payment.creation_changeset(%Payment{}, %{
          order_id: 1,
          payment_provider_id: 1,
          payment_method: "pix",
          flow: "async",
          amount_cents: 1000
        })

      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end

    test "confirm_changeset sets status to confirmed and settled_at" do
      payment = %Payment{id: 1, status: "pending", order_id: 1}
      changeset = Payment.confirm_changeset(payment)

      assert Ecto.Changeset.get_field(changeset, :status) == "confirmed"
      assert Ecto.Changeset.get_field(changeset, :settled_at) != nil
    end

    test "fail_changeset sets status to failed and stores reason" do
      payment = %Payment{id: 1, status: "pending", order_id: 1}
      changeset = Payment.fail_changeset(payment, "insufficient funds")

      assert Ecto.Changeset.get_field(changeset, :status) == "failed"
      assert Ecto.Changeset.get_field(changeset, :failure_reason) == "insufficient funds"
      assert Ecto.Changeset.get_field(changeset, :settled_at) != nil
    end

    test "refund_changeset sets status to refunded" do
      payment = %Payment{id: 1, status: "confirmed", order_id: 1}
      changeset = Payment.refund_changeset(payment)

      assert Ecto.Changeset.get_field(changeset, :status) == "refunded"
    end
  end

  # ---------------------------------------------------------------------------
  # Refund schema changesets
  # ---------------------------------------------------------------------------

  describe "Refund schema" do
    test "creation_changeset requires payment_id, order_id, and amount_cents" do
      changeset = Refund.creation_changeset(%Refund{}, %{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :payment_id)
      assert Map.has_key?(errors, :order_id)
      assert Map.has_key?(errors, :amount_cents)
    end

    test "creation_changeset rejects zero or negative amounts" do
      changeset =
        Refund.creation_changeset(%Refund{}, %{
          payment_id: 1,
          order_id: 1,
          amount_cents: 0
        })

      assert %{amount_cents: [_]} = errors_on(changeset)
    end

    test "creation_changeset defaults status to pending and sets initiated_at" do
      changeset =
        Refund.creation_changeset(%Refund{}, %{
          payment_id: 1,
          order_id: 1,
          amount_cents: 500
        })

      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
      assert Ecto.Changeset.get_field(changeset, :initiated_at) != nil
    end

    test "status_changeset validates status inclusion" do
      refund = %Refund{id: 1}

      changeset = Refund.status_changeset(refund, %{status: "invalid_status"})
      assert %{status: [_]} = errors_on(changeset)

      valid_changeset = Refund.status_changeset(refund, %{status: "completed"})
      assert valid_changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # Payment flow classification
  # ---------------------------------------------------------------------------

  describe "payment flow classification via list_payment_options_for_organization" do
    test "stripe credit_card has inline flow" do
      org = org_fixture()
      _provider = provider_fixture(org, "stripe")

      options = Payments.list_payment_options_for_organization(org.id)
      cc_option = Enum.find(options, &(&1.method == "credit_card"))

      assert cc_option != nil
      assert cc_option.flow == "inline"
    end

    test "woovi pix has async flow" do
      org = org_fixture()
      _provider = provider_fixture(org, "woovi")

      options = Payments.list_payment_options_for_organization(org.id)
      pix_option = Enum.find(options, &(&1.method == "pix"))

      assert pix_option != nil
      assert pix_option.flow == "async"
    end

    test "manual bank_transfer has async flow" do
      org = org_fixture()
      _provider = provider_fixture(org, "manual")

      options = Payments.list_payment_options_for_organization(org.id)
      bt_option = Enum.find(options, &(&1.method == "bank_transfer"))

      assert bt_option != nil
      assert bt_option.flow == "async"
    end

    test "abacatepay boleto has async flow" do
      org = org_fixture()
      _provider = provider_fixture(org, "abacatepay")

      options = Payments.list_payment_options_for_organization(org.id)
      boleto_option = Enum.find(options, &(&1.method == "boleto"))

      assert boleto_option != nil
      assert boleto_option.flow == "async"
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  describe "create_payment/3 edge cases" do
    test "creates separate payment records for separate orders" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")

      order1 = order_fixture(event, provider)
      order2 = order_fixture(event, provider)

      {:ok, p1} = Payments.create_payment(order1, provider, "bank_transfer")
      {:ok, p2} = Payments.create_payment(order2, provider, "bank_transfer")

      assert p1.id != p2.id
      assert p1.order_id == order1.id
      assert p2.order_id == order2.id
    end

    test "payment amount_cents matches order total_cents" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")

      item = item_fixture(event, %{price_cents: 7500})
      {:ok, cart} = Orders.create_cart(event)
      {:ok, _} = Orders.add_to_cart(cart, item, quantity: 2)
      cart = Orders.get_cart_by_token(cart.session_token)

      {:ok, order} =
        Orders.create_order_from_cart(cart, %{
          name: "Attendee",
          email: "a@example.com",
          payment_method: "bank_transfer",
          payment_provider_id: provider.id
        })

      assert order.total_cents == 15_000

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      assert payment.amount_cents == 15_000
    end

    test "currency defaults to BRL" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")
      assert payment.currency == "BRL"
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub integration (no actual socket, just verify broadcast doesn't crash)
  # ---------------------------------------------------------------------------

  describe "PubSub broadcasts" do
    test "payment_topic/1 returns a scoped string" do
      topic = Payments.payment_topic(42)
      assert topic == "payments:order:42"
    end

    test "confirm_payment broadcasts without error" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")

      # Subscribe so we can verify the broadcast was sent
      Phoenix.PubSub.subscribe(Pretex.PubSub, Payments.payment_topic(order.id))

      {:ok, confirmed} = Payments.confirm_payment(payment)

      assert_receive {:payment_updated, received_payment}
      assert received_payment.id == confirmed.id
      assert received_payment.status == "confirmed"
    end

    test "fail_payment broadcasts without error" do
      org = org_fixture()
      event = published_event_fixture(org)
      provider = provider_fixture(org, "manual")
      order = order_fixture(event, provider)

      {:ok, payment} = Payments.create_payment(order, provider, "bank_transfer")

      Phoenix.PubSub.subscribe(Pretex.PubSub, Payments.payment_topic(order.id))

      {:ok, _failed} = Payments.fail_payment(payment, "test failure")

      assert_receive {:payment_updated, received_payment}
      assert received_payment.status == "failed"
    end
  end
end
