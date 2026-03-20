defmodule Pretex.Accounts2faTest do
  use Pretex.DataCase, async: true

  alias Pretex.Accounts

  import Pretex.AccountsFixtures

  describe "generate_totp_secret/0" do
    test "returns a binary secret" do
      secret = Accounts.generate_totp_secret()
      assert is_binary(secret)
      assert byte_size(secret) > 0
    end

    test "returns a different secret each call" do
      secret1 = Accounts.generate_totp_secret()
      secret2 = Accounts.generate_totp_secret()
      assert secret1 != secret2
    end
  end

  describe "valid_totp_code?/2" do
    test "returns true for a valid TOTP code" do
      secret = Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(secret)
      assert Accounts.valid_totp_code?(secret, code)
    end

    test "returns false for an invalid TOTP code" do
      secret = Accounts.generate_totp_secret()
      refute Accounts.valid_totp_code?(secret, "000000")
    end

    test "returns false for an empty code" do
      secret = Accounts.generate_totp_secret()
      refute Accounts.valid_totp_code?(secret, "")
    end
  end

  describe "enable_totp/2" do
    test "sets totp_secret and totp_enabled_at on the user" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()

      assert {:ok, updated} = Accounts.enable_totp(user, secret)
      assert updated.totp_secret == secret
      assert %DateTime{} = updated.totp_enabled_at
    end

    test "totp_enabled? returns true after enabling" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()

      {:ok, updated} = Accounts.enable_totp(user, secret)
      assert Accounts.User.totp_enabled?(updated)
    end
  end

  describe "disable_totp/1" do
    test "clears totp_secret and totp_enabled_at" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      {:ok, user} = Accounts.enable_totp(user, secret)

      assert {:ok, updated} = Accounts.disable_totp(user)
      assert is_nil(updated.totp_secret)
      assert is_nil(updated.totp_enabled_at)
    end

    test "totp_enabled? returns false after disabling" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      {:ok, user} = Accounts.enable_totp(user, secret)

      {:ok, updated} = Accounts.disable_totp(user)
      refute Accounts.User.totp_enabled?(updated)
    end
  end

  describe "generate_recovery_codes/1" do
    test "returns a list of 8 plaintext codes" do
      user = user_fixture()
      codes = Accounts.generate_recovery_codes(user)

      assert length(codes) == 8
      assert Enum.all?(codes, &is_binary/1)
    end

    test "codes have the expected XXXX-XXXX format" do
      user = user_fixture()
      codes = Accounts.generate_recovery_codes(user)

      assert Enum.all?(codes, fn code ->
               String.match?(code, ~r/^[A-Z2-7]{4}-[A-Z2-7]{4}$/)
             end)
    end

    test "deletes existing codes and generates fresh ones" do
      user = user_fixture()
      first_codes = Accounts.generate_recovery_codes(user)
      second_codes = Accounts.generate_recovery_codes(user)

      assert Accounts.remaining_recovery_codes(user) == 8
      refute MapSet.equal?(MapSet.new(first_codes), MapSet.new(second_codes))
    end
  end

  describe "use_recovery_code/2" do
    setup do
      user = user_fixture()
      codes = Accounts.generate_recovery_codes(user)
      %{user: user, codes: codes}
    end

    test "returns :ok for a valid unused code", %{user: user, codes: codes} do
      [code | _] = codes
      assert :ok = Accounts.use_recovery_code(user, code)
    end

    test "marks the code as used so it cannot be reused", %{user: user, codes: codes} do
      [code | _] = codes
      :ok = Accounts.use_recovery_code(user, code)
      assert :error = Accounts.use_recovery_code(user, code)
    end

    test "returns :error for an already-used code", %{user: user, codes: codes} do
      [code | _] = codes
      :ok = Accounts.use_recovery_code(user, code)
      assert :error = Accounts.use_recovery_code(user, code)
    end

    test "returns :error for an invalid code", %{user: user} do
      assert :error = Accounts.use_recovery_code(user, "INVALID-CODE")
    end

    test "is case-insensitive and trims whitespace", %{user: user, codes: codes} do
      [code | _] = codes
      lowercased = " " <> String.downcase(code) <> " "
      assert :ok = Accounts.use_recovery_code(user, lowercased)
    end
  end

  describe "remaining_recovery_codes/1" do
    test "returns 8 after generating codes" do
      user = user_fixture()
      Accounts.generate_recovery_codes(user)
      assert Accounts.remaining_recovery_codes(user) == 8
    end

    test "decrements after using a code" do
      user = user_fixture()
      [code | _rest] = Accounts.generate_recovery_codes(user)

      :ok = Accounts.use_recovery_code(user, code)
      assert Accounts.remaining_recovery_codes(user) == 7
    end

    test "returns 0 when user has no codes" do
      user = user_fixture()
      assert Accounts.remaining_recovery_codes(user) == 0
    end
  end

  describe "totp_secret_base32/1" do
    test "returns a base32-encoded string" do
      secret = Accounts.generate_totp_secret()
      b32 = Accounts.totp_secret_base32(secret)
      assert is_binary(b32)
      assert String.match?(b32, ~r/^[A-Z2-7]+$/)
    end
  end
end
