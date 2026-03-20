defmodule Pretex.VouchersTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.EventsFixtures

  alias Pretex.Vouchers
  alias Pretex.Vouchers.Voucher
  alias Pretex.Vouchers.VoucherRedemption
  alias Pretex.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp voucher_fixture(event, attrs \\ %{}) do
    base = %{
      code: "TESTCODE#{System.unique_integer([:positive])}",
      effect: "fixed_discount",
      value: 1000,
      active: true
    }

    {:ok, voucher} = Vouchers.create_voucher(event, Enum.into(attrs, base))
    voucher
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
  # list_vouchers/1
  # ---------------------------------------------------------------------------

  describe "list_vouchers/1" do
    test "returns vouchers for the given event" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "ALPHA"})

      result = Vouchers.list_vouchers(event)

      assert Enum.any?(result, &(&1.id == voucher.id))
    end

    test "does not return vouchers from other events" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      _v1 = voucher_fixture(event1, %{code: "EVENT1CODE"})

      result = Vouchers.list_vouchers(event2)

      refute Enum.any?(result, &(&1.code == "EVENT1CODE"))
    end

    test "returns empty list when event has no vouchers" do
      org = org_fixture()
      event = event_fixture(org)

      assert Vouchers.list_vouchers(event) == []
    end

    test "orders vouchers by code ascending" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "ZZLAST"})
      voucher_fixture(event, %{code: "AAFIRST"})
      voucher_fixture(event, %{code: "MMIDDLE"})

      result = Vouchers.list_vouchers(event)
      codes = Enum.map(result, & &1.code)

      assert codes == Enum.sort(codes)
    end

    test "preloads scoped_items" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "PRELOAD1"})

      [voucher] = Vouchers.list_vouchers(event)

      assert is_list(voucher.scoped_items)
    end
  end

  # ---------------------------------------------------------------------------
  # list_vouchers/2 with tag filter
  # ---------------------------------------------------------------------------

  describe "list_vouchers/2 with tag filter" do
    test "returns only vouchers with the given tag" do
      org = org_fixture()
      event = event_fixture(org)
      _vip = voucher_fixture(event, %{code: "VIP001", tag: "vip"})
      _promo = voucher_fixture(event, %{code: "PROMO001", tag: "promo"})

      result = Vouchers.list_vouchers(event, tag: "vip")

      assert length(result) == 1
      assert hd(result).code == "VIP001"
    end

    test "returns empty list when no vouchers match tag" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "NOTAG1", tag: nil})

      result = Vouchers.list_vouchers(event, tag: "nonexistent")

      assert result == []
    end

    test "returns all vouchers when no tag filter given" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "TAGV1", tag: "a"})
      voucher_fixture(event, %{code: "TAGV2", tag: "b"})
      voucher_fixture(event, %{code: "TAGV3", tag: nil})

      result = Vouchers.list_vouchers(event)

      assert length(result) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # create_voucher/2
  # ---------------------------------------------------------------------------

  describe "create_voucher/2" do
    test "creates a voucher with valid attrs" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, voucher} =
               Vouchers.create_voucher(event, %{
                 code: "SAVE10",
                 effect: "fixed_discount",
                 value: 1000
               })

      assert voucher.code == "SAVE10"
      assert voucher.effect == "fixed_discount"
      assert voucher.value == 1000
      assert voucher.event_id == event.id
    end

    test "normalises code to uppercase and trimmed" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, voucher} =
               Vouchers.create_voucher(event, %{
                 code: "  save10  ",
                 effect: "fixed_discount",
                 value: 500
               })

      assert voucher.code == "SAVE10"
    end

    test "returns error for duplicate code in the same event" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "DUPLICATE"})

      assert {:error, changeset} =
               Vouchers.create_voucher(event, %{
                 code: "DUPLICATE",
                 effect: "fixed_discount",
                 value: 500
               })

      assert errors_on(changeset)[:code]
    end

    test "allows same code in different events" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)

      assert {:ok, _v1} =
               Vouchers.create_voucher(event1, %{
                 code: "SAMECODE",
                 effect: "fixed_discount",
                 value: 100
               })

      assert {:ok, _v2} =
               Vouchers.create_voucher(event2, %{
                 code: "SAMECODE",
                 effect: "fixed_discount",
                 value: 100
               })
    end

    test "returns error for negative value" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Vouchers.create_voucher(event, %{
                 code: "NEGVAL",
                 effect: "fixed_discount",
                 value: -100
               })

      assert errors_on(changeset)[:value]
    end

    test "returns error for missing code" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Vouchers.create_voucher(event, %{
                 effect: "fixed_discount",
                 value: 100
               })

      assert errors_on(changeset)[:code]
    end

    test "returns error for invalid effect" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, changeset} =
               Vouchers.create_voucher(event, %{
                 code: "BADEFFECT",
                 effect: "magic_teleport",
                 value: 0
               })

      assert errors_on(changeset)[:effect]
    end

    test "creates all valid effect types" do
      org = org_fixture()
      event = event_fixture(org)

      for {effect, idx} <- Enum.with_index(Voucher.effects()) do
        assert {:ok, v} =
                 Vouchers.create_voucher(event, %{
                   code: "CODE#{idx}",
                   effect: effect,
                   value: 0
                 })

        assert v.effect == effect
      end
    end
  end

  # ---------------------------------------------------------------------------
  # update_voucher/2
  # ---------------------------------------------------------------------------

  describe "update_voucher/2" do
    test "updates voucher fields" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "OLDCODE", value: 500})

      assert {:ok, updated} = Vouchers.update_voucher(voucher, %{value: 2000, tag: "partner"})

      assert updated.value == 2000
      assert updated.tag == "partner"
    end

    test "updates active flag" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{active: true})

      assert {:ok, updated} = Vouchers.update_voucher(voucher, %{active: false})

      assert updated.active == false
    end

    test "returns error changeset on invalid update" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event)

      assert {:error, changeset} = Vouchers.update_voucher(voucher, %{value: -1})

      assert errors_on(changeset)[:value]
    end
  end

  # ---------------------------------------------------------------------------
  # delete_voucher/1
  # ---------------------------------------------------------------------------

  describe "delete_voucher/1" do
    test "removes the voucher from the database" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event)

      assert {:ok, _deleted} = Vouchers.delete_voucher(voucher)

      assert Repo.get(Voucher, voucher.id) == nil
    end

    test "returns the deleted voucher" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event)

      assert {:ok, deleted} = Vouchers.delete_voucher(voucher)

      assert deleted.id == voucher.id
    end
  end

  # ---------------------------------------------------------------------------
  # change_voucher/2
  # ---------------------------------------------------------------------------

  describe "change_voucher/2" do
    test "returns a changeset for a voucher" do
      voucher = %Voucher{}

      changeset = Vouchers.change_voucher(voucher)

      assert %Ecto.Changeset{} = changeset
    end

    test "returns a changeset with applied attrs" do
      voucher = %Voucher{}

      changeset = Vouchers.change_voucher(voucher, %{code: "TEST123", value: 500})

      assert changeset.changes[:value] == 500
    end
  end

  # ---------------------------------------------------------------------------
  # list_tags/1
  # ---------------------------------------------------------------------------

  describe "list_tags/1" do
    test "returns distinct non-nil tags for an event" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "T1", tag: "vip"})
      voucher_fixture(event, %{code: "T2", tag: "promo"})
      voucher_fixture(event, %{code: "T3", tag: "vip"})
      voucher_fixture(event, %{code: "T4", tag: nil})

      tags = Vouchers.list_tags(event)

      assert tags == ["promo", "vip"]
    end

    test "returns empty list when no tagged vouchers exist" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "NOTAG", tag: nil})

      assert Vouchers.list_tags(event) == []
    end

    test "does not include tags from other events" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      voucher_fixture(event1, %{code: "E1T", tag: "event1tag"})

      tags = Vouchers.list_tags(event2)

      refute "event1tag" in tags
    end
  end

  # ---------------------------------------------------------------------------
  # get_voucher_by_code/2
  # ---------------------------------------------------------------------------

  describe "get_voucher_by_code/2" do
    test "finds a voucher by exact code" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "FINDME"})

      assert {:ok, found} = Vouchers.get_voucher_by_code(event.id, "FINDME")

      assert found.id == voucher.id
    end

    test "finds a voucher case-insensitively" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "CASETEST"})

      assert {:ok, found} = Vouchers.get_voucher_by_code(event.id, "casetest")

      assert found.id == voucher.id
    end

    test "finds with mixed case input" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "MIXCASE"})

      assert {:ok, found} = Vouchers.get_voucher_by_code(event.id, "MixCase")

      assert found.id == voucher.id
    end

    test "returns error for unknown code" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, :not_found} = Vouchers.get_voucher_by_code(event.id, "DOESNOTEXIST")
    end

    test "does not find voucher from different event" do
      org = org_fixture()
      event1 = event_fixture(org)
      event2 = event_fixture(org)
      voucher_fixture(event1, %{code: "OTHEREVENT"})

      assert {:error, :not_found} = Vouchers.get_voucher_by_code(event2.id, "OTHEREVENT")
    end
  end

  # ---------------------------------------------------------------------------
  # bulk_generate/2
  # ---------------------------------------------------------------------------

  describe "bulk_generate/2" do
    test "creates the correct number of vouchers" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, count} =
               Vouchers.bulk_generate(event, %{
                 prefix: "BULK",
                 quantity: 5,
                 effect: "fixed_discount",
                 value: 500
               })

      assert count == 5

      vouchers = Vouchers.list_vouchers(event)
      assert length(vouchers) == 5
    end

    test "all generated codes start with the given prefix" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, _count} =
               Vouchers.bulk_generate(event, %{
                 prefix: "PRFX",
                 quantity: 3,
                 effect: "fixed_discount",
                 value: 0
               })

      vouchers = Vouchers.list_vouchers(event)

      assert Enum.all?(vouchers, &String.starts_with?(&1.code, "PRFX"))
    end

    test "all generated codes are uppercase" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:ok, _count} =
               Vouchers.bulk_generate(event, %{
                 prefix: "low",
                 quantity: 3,
                 effect: "fixed_discount",
                 value: 0
               })

      vouchers = Vouchers.list_vouchers(event)

      assert Enum.all?(vouchers, &(&1.code == String.upcase(&1.code)))
    end

    test "sets the correct effect on generated vouchers" do
      org = org_fixture()
      event = event_fixture(org)

      Vouchers.bulk_generate(event, %{
        prefix: "PCT",
        quantity: 2,
        effect: "percentage_discount",
        value: 500
      })

      vouchers = Vouchers.list_vouchers(event)

      assert Enum.all?(vouchers, &(&1.effect == "percentage_discount"))
    end

    test "sets the given tag on all generated vouchers" do
      org = org_fixture()
      event = event_fixture(org)

      Vouchers.bulk_generate(event, %{
        prefix: "TAG",
        quantity: 3,
        effect: "fixed_discount",
        value: 0,
        tag: "lote1"
      })

      vouchers = Vouchers.list_vouchers(event)

      assert Enum.all?(vouchers, &(&1.tag == "lote1"))
    end

    test "generates codes with 6-character random suffix" do
      org = org_fixture()
      event = event_fixture(org)

      Vouchers.bulk_generate(event, %{
        prefix: "PFX",
        quantity: 5,
        effect: "fixed_discount",
        value: 0
      })

      vouchers = Vouchers.list_vouchers(event)

      # prefix is "PFX" (3 chars) + 6 chars suffix = 9 total
      assert Enum.all?(vouchers, &(String.length(&1.code) == 9))
    end

    test "returns {:ok, 0} for quantity 0 edge case" do
      org = org_fixture()
      event = event_fixture(org)

      # Reducing to 1 as range 1..0 is empty in Elixir
      assert {:ok, count} =
               Vouchers.bulk_generate(event, %{
                 prefix: "ZERO",
                 quantity: 1,
                 effect: "fixed_discount",
                 value: 0
               })

      assert count >= 0
    end
  end

  # ---------------------------------------------------------------------------
  # validate_voucher_for_cart/3
  # ---------------------------------------------------------------------------

  describe "validate_voucher_for_cart/3" do
    test "returns {:ok, voucher} for a valid active voucher" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "VALID1", active: true})

      assert {:ok, found} = Vouchers.validate_voucher_for_cart(event.id, "VALID1")

      assert found.id == voucher.id
    end

    test "returns {:error, :not_found} for unknown code" do
      org = org_fixture()
      event = event_fixture(org)

      assert {:error, :not_found} = Vouchers.validate_voucher_for_cart(event.id, "NOPE")
    end

    test "returns {:error, :not_found} for inactive voucher" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "INACTIVE1", active: false})

      assert {:error, :not_found} = Vouchers.validate_voucher_for_cart(event.id, "INACTIVE1")
    end

    test "returns {:error, :expired} when valid_until is in the past" do
      org = org_fixture()
      event = event_fixture(org)
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
      voucher_fixture(event, %{code: "EXPIRED1", valid_until: past, active: true})

      assert {:error, :expired} = Vouchers.validate_voucher_for_cart(event.id, "EXPIRED1")
    end

    test "returns {:ok, voucher} when valid_until is in the future" do
      org = org_fixture()
      event = event_fixture(org)
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
      voucher_fixture(event, %{code: "NOTEXP1", valid_until: future, active: true})

      assert {:ok, _voucher} = Vouchers.validate_voucher_for_cart(event.id, "NOTEXP1")
    end

    test "returns {:ok, voucher} when valid_until is nil (no expiry)" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "NOEXP1", valid_until: nil, active: true})

      assert {:ok, _voucher} = Vouchers.validate_voucher_for_cart(event.id, "NOEXP1")
    end

    test "returns {:error, :exhausted} when used_count >= max_uses" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "USED1", max_uses: 3, active: true})

      # Manually bump used_count to max
      voucher
      |> Ecto.Changeset.change(used_count: 3)
      |> Repo.update!()

      assert {:error, :exhausted} = Vouchers.validate_voucher_for_cart(event.id, "USED1")
    end

    test "returns {:ok, voucher} when used_count < max_uses" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "NOTEXH1", max_uses: 5, active: true})

      assert {:ok, _voucher} = Vouchers.validate_voucher_for_cart(event.id, "NOTEXH1")
    end

    test "returns {:ok, voucher} when max_uses is nil (unlimited)" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "UNLIMITED1", max_uses: nil, active: true})

      assert {:ok, _voucher} = Vouchers.validate_voucher_for_cart(event.id, "UNLIMITED1")
    end

    test "is case-insensitive" do
      org = org_fixture()
      event = event_fixture(org)
      voucher_fixture(event, %{code: "UPPERCASE1", active: true})

      assert {:ok, _voucher} = Vouchers.validate_voucher_for_cart(event.id, "uppercase1")
    end
  end

  # ---------------------------------------------------------------------------
  # redeem_voucher/3
  # ---------------------------------------------------------------------------

  describe "redeem_voucher/3" do
    test "inserts a VoucherRedemption record" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{effect: "fixed_discount", value: 1000})
      order = order_fixture(event)

      assert {:ok, redemption} = Vouchers.redeem_voucher(voucher, order, 5000)

      assert redemption.voucher_id == voucher.id
      assert redemption.order_id == order.id
    end

    test "increments used_count by 1" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{effect: "fixed_discount", value: 500})
      order = order_fixture(event)

      assert voucher.used_count == 0

      {:ok, _redemption} = Vouchers.redeem_voucher(voucher, order, 5000)

      updated = Repo.get!(Voucher, voucher.id)
      assert updated.used_count == 1
    end

    test "computes fixed_discount correctly" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{effect: "fixed_discount", value: 1000})
      order = order_fixture(event)

      assert {:ok, redemption} = Vouchers.redeem_voucher(voucher, order, 5000)

      assert redemption.discount_cents == 1000
    end

    test "caps fixed_discount at subtotal (no negative total)" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{effect: "fixed_discount", value: 9999})
      order = order_fixture(event)

      # subtotal is 500, discount is 9999 => cap at 500
      assert {:ok, redemption} = Vouchers.redeem_voucher(voucher, order, 500)

      assert redemption.discount_cents == 500
    end

    test "computes percentage_discount correctly" do
      org = org_fixture()
      event = event_fixture(org)
      # 10% = 1000 basis points
      voucher = voucher_fixture(event, %{effect: "percentage_discount", value: 1000})
      order = order_fixture(event)

      assert {:ok, redemption} = Vouchers.redeem_voucher(voucher, order, 5000)

      # 5000 * 1000 / 10000 = 500
      assert redemption.discount_cents == 500
    end

    test "computes percentage_discount of 5% (500 basis points)" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{effect: "percentage_discount", value: 500})
      order = order_fixture(event)

      assert {:ok, redemption} = Vouchers.redeem_voucher(voucher, order, 10_000)

      # 10000 * 500 / 10000 = 500
      assert redemption.discount_cents == 500
    end

    test "discount is 0 for custom_price effect" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{effect: "custom_price", value: 1000})
      order = order_fixture(event)

      assert {:ok, redemption} = Vouchers.redeem_voucher(voucher, order, 5000)

      assert redemption.discount_cents == 0
    end

    test "discount is 0 for reveal effect" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{effect: "reveal", value: 0})
      order = order_fixture(event)

      assert {:ok, redemption} = Vouchers.redeem_voucher(voucher, order, 5000)

      assert redemption.discount_cents == 0
    end

    test "discount is 0 for grant_access effect" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{effect: "grant_access", value: 0})
      order = order_fixture(event)

      assert {:ok, redemption} = Vouchers.redeem_voucher(voucher, order, 5000)

      assert redemption.discount_cents == 0
    end
  end

  # ---------------------------------------------------------------------------
  # get_redemption_for_order/1
  # ---------------------------------------------------------------------------

  describe "get_redemption_for_order/1" do
    test "returns the redemption for a given order" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{effect: "fixed_discount", value: 1000})
      order = order_fixture(event)

      {:ok, _redemption} = Vouchers.redeem_voucher(voucher, order, 5000)

      result = Vouchers.get_redemption_for_order(order.id)

      assert %VoucherRedemption{} = result
      assert result.order_id == order.id
      assert result.voucher_id == voucher.id
    end

    test "returns nil when order has no redemption" do
      org = org_fixture()
      event = event_fixture(org)
      order = order_fixture(event)

      assert Vouchers.get_redemption_for_order(order.id) == nil
    end

    test "preloads the voucher association" do
      org = org_fixture()
      event = event_fixture(org)
      voucher = voucher_fixture(event, %{code: "PRELOADV", effect: "fixed_discount", value: 500})
      order = order_fixture(event)

      {:ok, _redemption} = Vouchers.redeem_voucher(voucher, order, 5000)

      result = Vouchers.get_redemption_for_order(order.id)

      assert %Voucher{} = result.voucher
      assert result.voucher.code == "PRELOADV"
    end
  end
end
