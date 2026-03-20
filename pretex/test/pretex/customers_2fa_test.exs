defmodule Pretex.Customers2faTest do
  use Pretex.DataCase, async: true

  alias Pretex.Customers

  import Pretex.CustomersFixtures

  describe "generate_totp_secret/0" do
    test "returns a binary secret" do
      secret = Customers.generate_totp_secret()
      assert is_binary(secret)
      assert byte_size(secret) > 0
    end

    test "returns a different secret each call" do
      secret1 = Customers.generate_totp_secret()
      secret2 = Customers.generate_totp_secret()
      assert secret1 != secret2
    end
  end

  describe "valid_totp_code?/2" do
    test "returns true for a valid TOTP code" do
      secret = Customers.generate_totp_secret()
      code = NimbleTOTP.verification_code(secret)
      assert Customers.valid_totp_code?(secret, code)
    end

    test "returns false for an invalid TOTP code" do
      secret = Customers.generate_totp_secret()
      refute Customers.valid_totp_code?(secret, "000000")
    end

    test "returns false for an empty code" do
      secret = Customers.generate_totp_secret()
      refute Customers.valid_totp_code?(secret, "")
    end
  end

  describe "enable_totp/2" do
    test "sets totp_secret and totp_enabled_at on the customer" do
      customer = customer_fixture()
      secret = Customers.generate_totp_secret()

      assert {:ok, updated} = Customers.enable_totp(customer, secret)
      assert updated.totp_secret == secret
      assert %DateTime{} = updated.totp_enabled_at
    end

    test "totp_enabled? returns true after enabling" do
      customer = customer_fixture()
      secret = Customers.generate_totp_secret()

      {:ok, updated} = Customers.enable_totp(customer, secret)
      assert Customers.Customer.totp_enabled?(updated)
    end
  end

  describe "disable_totp/1" do
    test "clears totp_secret and totp_enabled_at" do
      customer = customer_fixture()
      secret = Customers.generate_totp_secret()
      {:ok, customer} = Customers.enable_totp(customer, secret)

      assert {:ok, updated} = Customers.disable_totp(customer)
      assert is_nil(updated.totp_secret)
      assert is_nil(updated.totp_enabled_at)
    end

    test "totp_enabled? returns false after disabling" do
      customer = customer_fixture()
      secret = Customers.generate_totp_secret()
      {:ok, customer} = Customers.enable_totp(customer, secret)

      {:ok, updated} = Customers.disable_totp(customer)
      refute Customers.Customer.totp_enabled?(updated)
    end
  end

  describe "generate_recovery_codes/1" do
    test "returns a list of 8 plaintext codes" do
      customer = customer_fixture()
      codes = Customers.generate_recovery_codes(customer)

      assert length(codes) == 8
      assert Enum.all?(codes, &is_binary/1)
    end

    test "codes have the expected XXXX-XXXX format" do
      customer = customer_fixture()
      codes = Customers.generate_recovery_codes(customer)

      assert Enum.all?(codes, fn code ->
               String.match?(code, ~r/^[A-Z2-7]{4}-[A-Z2-7]{4}$/)
             end)
    end

    test "deletes existing codes and generates fresh ones" do
      customer = customer_fixture()
      first_codes = Customers.generate_recovery_codes(customer)
      second_codes = Customers.generate_recovery_codes(customer)

      assert Customers.remaining_recovery_codes(customer) == 8
      refute MapSet.equal?(MapSet.new(first_codes), MapSet.new(second_codes))
    end
  end

  describe "use_recovery_code/2" do
    setup do
      customer = customer_fixture()
      codes = Customers.generate_recovery_codes(customer)
      %{customer: customer, codes: codes}
    end

    test "returns :ok for a valid unused code", %{customer: customer, codes: codes} do
      [code | _] = codes
      assert :ok = Customers.use_recovery_code(customer, code)
    end

    test "marks the code as used so it cannot be reused", %{customer: customer, codes: codes} do
      [code | _] = codes
      :ok = Customers.use_recovery_code(customer, code)
      assert :error = Customers.use_recovery_code(customer, code)
    end

    test "returns :error for an already-used code", %{customer: customer, codes: codes} do
      [code | _] = codes
      :ok = Customers.use_recovery_code(customer, code)
      assert :error = Customers.use_recovery_code(customer, code)
    end

    test "returns :error for an invalid code", %{customer: customer} do
      assert :error = Customers.use_recovery_code(customer, "INVALID-CODE")
    end

    test "is case-insensitive and trims whitespace", %{customer: customer, codes: codes} do
      [code | _] = codes
      lowercased = " " <> String.downcase(code) <> " "
      assert :ok = Customers.use_recovery_code(customer, lowercased)
    end
  end

  describe "remaining_recovery_codes/1" do
    test "returns 8 after generating codes" do
      customer = customer_fixture()
      Customers.generate_recovery_codes(customer)
      assert Customers.remaining_recovery_codes(customer) == 8
    end

    test "decrements after using a code" do
      customer = customer_fixture()
      [code | _rest] = Customers.generate_recovery_codes(customer)

      :ok = Customers.use_recovery_code(customer, code)
      assert Customers.remaining_recovery_codes(customer) == 7
    end

    test "returns 0 when customer has no codes" do
      customer = customer_fixture()
      assert Customers.remaining_recovery_codes(customer) == 0
    end
  end

  describe "totp_secret_base32/1" do
    test "returns a base32-encoded string" do
      secret = Customers.generate_totp_secret()
      b32 = Customers.totp_secret_base32(secret)
      assert is_binary(b32)
      assert String.match?(b32, ~r/^[A-Z2-7]+$/)
    end
  end
end
