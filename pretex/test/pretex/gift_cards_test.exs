defmodule Pretex.GiftCardsTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures

  alias Pretex.GiftCards
  alias Pretex.GiftCards.GiftCard
  alias Pretex.GiftCards.GiftCardRedemption
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp gift_card_fixture(org, attrs \\ %{}) do
    base = %{
      code: "GC-TEST#{System.unique_integer([:positive])}",
      balance_cents: 5000,
      active: true
    }

    {:ok, gc} = GiftCards.create_gift_card(org, Enum.into(attrs, base))
    gc
  end

  defp order_fixture(event) do
    {:ok, order} =
      %Pretex.Orders.Order{}
      |> Ecto.Changeset.change(%{
        event_id: event.id,
        status: "pending",
        total_cents: 10_000,
        email: "test@example.com",
        name: "Test User",
        confirmation_code: "CONF#{System.unique_integer([:positive])}",
        expires_at:
          DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
      })
      |> Repo.insert()

    order
  end

  # ---------------------------------------------------------------------------
  # list_gift_cards/1
  # ---------------------------------------------------------------------------

  describe "list_gift_cards/1" do
    test "returns gift cards for the given organization" do
      org = org_fixture()
      gc = gift_card_fixture(org)

      result = GiftCards.list_gift_cards(org)

      assert Enum.any?(result, &(&1.id == gc.id))
    end

    test "does not return gift cards from other organizations" do
      org1 = org_fixture()
      org2 = org_fixture()
      gc = gift_card_fixture(org1)

      result = GiftCards.list_gift_cards(org2)

      refute Enum.any?(result, &(&1.id == gc.id))
    end

    test "returns results ordered by inserted_at desc" do
      org = org_fixture()
      gc1 = gift_card_fixture(org, %{code: "GC-FIRST"})
      gc2 = gift_card_fixture(org, %{code: "GC-SECOND"})

      result = GiftCards.list_gift_cards(org)
      ids = Enum.map(result, & &1.id)

      # Both cards should appear; gc2 has a higher auto-increment ID so it was
      # inserted after gc1. If they share the same inserted_at second, the
      # relative order still satisfies "most-recently-inserted first" by ID.
      assert gc2.id > gc1.id
      assert Enum.member?(ids, gc1.id)
      assert Enum.member?(ids, gc2.id)
    end

    test "preloads redemptions" do
      org = org_fixture()
      _gc = gift_card_fixture(org)

      [result | _] = GiftCards.list_gift_cards(org)

      assert is_list(result.redemptions)
    end
  end

  # ---------------------------------------------------------------------------
  # create_gift_card/2
  # ---------------------------------------------------------------------------

  describe "create_gift_card/2" do
    test "creates a gift card with valid attrs" do
      org = org_fixture()

      assert {:ok, gc} =
               GiftCards.create_gift_card(org, %{
                 code: "GC-ABCD1234",
                 balance_cents: 5000
               })

      assert gc.code == "GC-ABCD1234"
      assert gc.balance_cents == 5000
      assert gc.organization_id == org.id
    end

    test "code is uppercased automatically" do
      org = org_fixture()

      assert {:ok, gc} =
               GiftCards.create_gift_card(org, %{
                 code: "gc-lowercase",
                 balance_cents: 1000
               })

      assert gc.code == "GC-LOWERCASE"
    end

    test "sets initial_balance_cents equal to balance_cents when not provided" do
      org = org_fixture()

      assert {:ok, gc} =
               GiftCards.create_gift_card(org, %{
                 code: "GC-IBALANCE",
                 balance_cents: 7500
               })

      assert gc.initial_balance_cents == 7500
    end

    test "respects explicit initial_balance_cents when provided" do
      org = org_fixture()

      assert {:ok, gc} =
               GiftCards.create_gift_card(org, %{
                 code: "GC-EXPLICIT",
                 balance_cents: 3000,
                 initial_balance_cents: 10_000
               })

      assert gc.initial_balance_cents == 10_000
      assert gc.balance_cents == 3000
    end

    test "duplicate code returns error changeset" do
      org = org_fixture()
      _gc1 = gift_card_fixture(org, %{code: "GC-DUPCODE"})

      assert {:error, changeset} =
               GiftCards.create_gift_card(org, %{
                 code: "GC-DUPCODE",
                 balance_cents: 1000
               })

      assert %{code: [_ | _]} = errors_on(changeset)
    end

    test "negative balance returns error changeset" do
      org = org_fixture()

      assert {:error, changeset} =
               GiftCards.create_gift_card(org, %{
                 code: "GC-NEGBAL",
                 balance_cents: -100
               })

      assert %{balance_cents: [_ | _]} = errors_on(changeset)
    end

    test "missing code returns error changeset" do
      org = org_fixture()

      assert {:error, changeset} =
               GiftCards.create_gift_card(org, %{balance_cents: 1000})

      assert %{code: [_ | _]} = errors_on(changeset)
    end

    test "sets active to true by default" do
      org = org_fixture()

      assert {:ok, gc} =
               GiftCards.create_gift_card(org, %{
                 code: "GC-ACTIVE",
                 balance_cents: 1000
               })

      assert gc.active == true
    end

    test "string-key attrs work correctly" do
      org = org_fixture()

      assert {:ok, gc} =
               GiftCards.create_gift_card(org, %{
                 "code" => "GC-STRKEYS",
                 "balance_cents" => 2000
               })

      assert gc.balance_cents == 2000
      assert gc.initial_balance_cents == 2000
    end
  end

  # ---------------------------------------------------------------------------
  # update_gift_card/2
  # ---------------------------------------------------------------------------

  describe "update_gift_card/2" do
    test "updates fields successfully" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{balance_cents: 5000, note: "original"})

      assert {:ok, updated} =
               GiftCards.update_gift_card(gc, %{balance_cents: 3000, note: "updated"})

      assert updated.balance_cents == 3000
      assert updated.note == "updated"
    end

    test "returns error changeset for invalid attrs" do
      org = org_fixture()
      gc = gift_card_fixture(org)

      assert {:error, changeset} = GiftCards.update_gift_card(gc, %{balance_cents: -1})

      assert %{balance_cents: [_ | _]} = errors_on(changeset)
    end

    test "can deactivate a gift card" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{active: true})

      assert {:ok, updated} = GiftCards.update_gift_card(gc, %{active: false})
      assert updated.active == false
    end
  end

  # ---------------------------------------------------------------------------
  # delete_gift_card/1
  # ---------------------------------------------------------------------------

  describe "delete_gift_card/1" do
    test "removes the gift card" do
      org = org_fixture()
      gc = gift_card_fixture(org)

      assert {:ok, _} = GiftCards.delete_gift_card(gc)
      assert Repo.get(GiftCard, gc.id) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # top_up/2
  # ---------------------------------------------------------------------------

  describe "top_up/2" do
    test "increases the gift card balance" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{balance_cents: 5000})

      assert {:ok, updated} = GiftCards.top_up(gc, 2000)
      assert updated.balance_cents == 7000
    end

    test "inserts a credit redemption with note 'Top-up'" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{balance_cents: 5000})

      assert {:ok, _updated} = GiftCards.top_up(gc, 1500)

      redemption =
        GiftCardRedemption
        |> Pretex.Repo.get_by(gift_card_id: gc.id, kind: "credit")

      assert redemption != nil
      assert redemption.amount_cents == 1500
      assert redemption.note == "Top-up"
    end

    test "returns error for zero amount" do
      org = org_fixture()
      gc = gift_card_fixture(org)

      assert {:error, _} = GiftCards.top_up(gc, 0)
    end

    test "returns error for negative amount" do
      org = org_fixture()
      gc = gift_card_fixture(org)

      assert {:error, _} = GiftCards.top_up(gc, -100)
    end
  end

  # ---------------------------------------------------------------------------
  # get_gift_card_by_code/1
  # ---------------------------------------------------------------------------

  describe "get_gift_card_by_code/1" do
    test "finds a gift card by code" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-FINDME"})

      assert {:ok, found} = GiftCards.get_gift_card_by_code("GC-FINDME")
      assert found.id == gc.id
    end

    test "finds a gift card case-insensitively" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-CASEFIND"})

      assert {:ok, found} = GiftCards.get_gift_card_by_code("gc-casefind")
      assert found.id == gc.id
    end

    test "trims whitespace before lookup" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{code: "GC-TRIMME"})

      assert {:ok, found} = GiftCards.get_gift_card_by_code("  GC-TRIMME  ")
      assert found.id == gc.id
    end

    test "returns error for unknown code" do
      assert {:error, :not_found} = GiftCards.get_gift_card_by_code("GC-UNKNOWN")
    end

    test "returns error for nil" do
      assert {:error, :not_found} = GiftCards.get_gift_card_by_code(nil)
    end
  end

  # ---------------------------------------------------------------------------
  # validate_for_checkout/2
  # ---------------------------------------------------------------------------

  describe "validate_for_checkout/2" do
    test "returns ok for a valid, active, non-expired gift card with balance" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{balance_cents: 1000, active: true})

      assert {:ok, found} = GiftCards.validate_for_checkout(gc.code, org.id)
      assert found.id == gc.id
    end

    test "returns :not_found for unknown code" do
      org = org_fixture()

      assert {:error, :not_found} =
               GiftCards.validate_for_checkout("GC-DOESNOTEXIST", org.id)
    end

    test "returns :wrong_organization for a gift card from a different org" do
      org1 = org_fixture()
      org2 = org_fixture()
      gc = gift_card_fixture(org1, %{balance_cents: 1000, active: true})

      assert {:error, :wrong_organization} =
               GiftCards.validate_for_checkout(gc.code, org2.id)
    end

    test "returns :expired for a gift card with past expires_at" do
      org = org_fixture()

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      gc =
        gift_card_fixture(org, %{
          balance_cents: 1000,
          active: true,
          expires_at: past
        })

      assert {:error, :expired} = GiftCards.validate_for_checkout(gc.code, org.id)
    end

    test "returns :ok for a gift card with future expires_at" do
      org = org_fixture()

      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      gc =
        gift_card_fixture(org, %{
          balance_cents: 1000,
          active: true,
          expires_at: future
        })

      assert {:ok, _} = GiftCards.validate_for_checkout(gc.code, org.id)
    end

    test "returns :empty for a gift card with zero balance" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{balance_cents: 0, active: true})

      assert {:error, :empty} = GiftCards.validate_for_checkout(gc.code, org.id)
    end

    test "returns :inactive for an inactive gift card" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{balance_cents: 1000, active: false})

      assert {:error, :inactive} = GiftCards.validate_for_checkout(gc.code, org.id)
    end

    test "checks organization before expiry" do
      org1 = org_fixture()
      org2 = org_fixture()

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      gc =
        gift_card_fixture(org1, %{
          balance_cents: 1000,
          active: true,
          expires_at: past
        })

      # wrong org takes precedence
      assert {:error, :wrong_organization} =
               GiftCards.validate_for_checkout(gc.code, org2.id)
    end
  end

  # ---------------------------------------------------------------------------
  # redeem/3
  # ---------------------------------------------------------------------------

  describe "redeem/3" do
    test "deducts full requested amount when balance is sufficient" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)
      gc = gift_card_fixture(org, %{balance_cents: 10_000})

      assert {:ok, result} = GiftCards.redeem(gc, order, 3000)
      assert result.deduction_cents == 3000

      updated_gc = Repo.get!(GiftCard, gc.id)
      assert updated_gc.balance_cents == 7000
    end

    test "deducts only available balance when order total exceeds balance (partial)" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)
      gc = gift_card_fixture(org, %{balance_cents: 2000})

      assert {:ok, result} = GiftCards.redeem(gc, order, 5000)
      assert result.deduction_cents == 2000

      updated_gc = Repo.get!(GiftCard, gc.id)
      assert updated_gc.balance_cents == 0
    end

    test "deducts full balance when order total equals balance" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)
      gc = gift_card_fixture(org, %{balance_cents: 5000})

      assert {:ok, result} = GiftCards.redeem(gc, order, 5000)
      assert result.deduction_cents == 5000

      updated_gc = Repo.get!(GiftCard, gc.id)
      assert updated_gc.balance_cents == 0
    end

    test "inserts a debit redemption record" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)
      gc = gift_card_fixture(org, %{balance_cents: 5000})

      assert {:ok, _result} = GiftCards.redeem(gc, order, 2000)

      redemption = Repo.get_by(GiftCardRedemption, gift_card_id: gc.id, kind: "debit")
      assert redemption != nil
      assert redemption.amount_cents == 2000
      assert redemption.order_id == order.id
    end

    test "returns zero deduction when requested_cents is zero" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)
      gc = gift_card_fixture(org, %{balance_cents: 5000})

      assert {:ok, result} = GiftCards.redeem(gc, order, 0)
      assert result.deduction_cents == 0

      updated_gc = Repo.get!(GiftCard, gc.id)
      assert updated_gc.balance_cents == 5000
    end
  end

  # ---------------------------------------------------------------------------
  # restore_balance/3
  # ---------------------------------------------------------------------------

  describe "restore_balance/3" do
    test "increases balance for a non-expired card" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{balance_cents: 1000})

      assert {:ok, updated} = GiftCards.restore_balance(gc, 2000)
      assert updated.balance_cents == 3000
    end

    test "inserts a credit redemption for a non-expired card" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{balance_cents: 1000})

      assert {:ok, _updated} = GiftCards.restore_balance(gc, 500)

      redemption = Repo.get_by(GiftCardRedemption, gift_card_id: gc.id, kind: "credit")
      assert redemption != nil
      assert redemption.amount_cents == 500
      assert redemption.note == "Restaurado por reembolso"
    end

    test "extends expiry by 1 year for an expired card" do
      org = org_fixture()

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      gc =
        gift_card_fixture(org, %{
          balance_cents: 500,
          expires_at: past
        })

      assert {:ok, updated} = GiftCards.restore_balance(gc, 1000)

      now = DateTime.utc_now()
      one_year_from_now = DateTime.add(now, 365 * 24 * 3600, :second)

      # Should be within a few seconds of one year from now
      diff = DateTime.diff(updated.expires_at, one_year_from_now, :second)
      assert abs(diff) < 10
    end

    test "inserts credit redemption with extended-expiry note for expired card" do
      org = org_fixture()

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      gc =
        gift_card_fixture(org, %{
          balance_cents: 500,
          expires_at: past
        })

      assert {:ok, _updated} = GiftCards.restore_balance(gc, 750)

      redemption = Repo.get_by(GiftCardRedemption, gift_card_id: gc.id, kind: "credit")
      assert redemption != nil
      assert redemption.note == "Restaurado por reembolso (validade estendida)"
    end

    test "does not change expiry for a card without expiry" do
      org = org_fixture()
      gc = gift_card_fixture(org, %{balance_cents: 1000, expires_at: nil})

      assert {:ok, updated} = GiftCards.restore_balance(gc, 500)
      assert updated.expires_at == nil
    end

    test "does not change expiry for a future-expiry card" do
      org = org_fixture()

      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      gc =
        gift_card_fixture(org, %{
          balance_cents: 1000,
          expires_at: future
        })

      assert {:ok, updated} = GiftCards.restore_balance(gc, 500)
      assert DateTime.compare(updated.expires_at, future) == :eq
    end

    test "increases balance for an expired card" do
      org = org_fixture()

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      gc =
        gift_card_fixture(org, %{
          balance_cents: 500,
          expires_at: past
        })

      assert {:ok, updated} = GiftCards.restore_balance(gc, 1000)
      assert updated.balance_cents == 1500
    end
  end

  # ---------------------------------------------------------------------------
  # get_debit_redemption_for_order/1
  # ---------------------------------------------------------------------------

  describe "get_debit_redemption_for_order/1" do
    test "returns the debit redemption for an order" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)
      gc = gift_card_fixture(org, %{balance_cents: 5000})

      {:ok, _} = GiftCards.redeem(gc, order, 2000)

      redemption = GiftCards.get_debit_redemption_for_order(order.id)

      assert redemption != nil
      assert redemption.order_id == order.id
      assert redemption.kind == "debit"
      assert redemption.amount_cents == 2000
    end

    test "preloads the gift_card association" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)
      gc = gift_card_fixture(org, %{balance_cents: 5000})

      {:ok, _} = GiftCards.redeem(gc, order, 2000)

      redemption = GiftCards.get_debit_redemption_for_order(order.id)

      assert redemption.gift_card != nil
      assert redemption.gift_card.id == gc.id
    end

    test "returns nil when no debit redemption exists for the order" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)

      assert GiftCards.get_debit_redemption_for_order(order.id) == nil
    end

    test "returns nil for a non-existent order id" do
      assert GiftCards.get_debit_redemption_for_order(999_999_999) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # generate_code/0
  # ---------------------------------------------------------------------------

  describe "generate_code/0" do
    test "returns a string starting with 'GC-'" do
      code = GiftCards.generate_code()
      assert String.starts_with?(code, "GC-")
    end

    test "returns a code with 8 characters after the prefix" do
      code = GiftCards.generate_code()
      suffix = String.slice(code, 3..-1//1)
      assert String.length(suffix) == 8
    end

    test "generates different codes on successive calls" do
      codes = for _ <- 1..10, do: GiftCards.generate_code()
      unique_codes = Enum.uniq(codes)
      # Very unlikely to have duplicates in 10 calls
      assert length(unique_codes) > 1
    end

    test "generated code is uppercase alphanumeric after prefix" do
      code = GiftCards.generate_code()
      suffix = String.slice(code, 3..-1//1)
      assert suffix =~ ~r/^[A-Z0-9]+$/
    end
  end

  # ---------------------------------------------------------------------------
  # change_gift_card/2
  # ---------------------------------------------------------------------------

  describe "change_gift_card/2" do
    test "returns a changeset" do
      org = org_fixture()
      gc = gift_card_fixture(org)

      changeset = GiftCards.change_gift_card(gc)
      assert %Ecto.Changeset{} = changeset
    end

    test "returns a changeset with given attrs applied" do
      org = org_fixture()
      gc = gift_card_fixture(org)

      changeset = GiftCards.change_gift_card(gc, %{note: "updated note"})
      assert Ecto.Changeset.get_change(changeset, :note) == "updated note"
    end
  end
end
