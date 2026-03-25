defmodule Pretex.DevicesTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.AccountsFixtures

  alias Pretex.Devices
  alias Pretex.Devices.Device

  describe "generate_init_token/2" do
    test "generates an 8-char token with dash format" do
      org = org_fixture()
      user = user_fixture()

      assert {:ok, token_code} = Devices.generate_init_token(org.id, user.id)
      assert String.match?(token_code, ~r/^[A-Z0-9]{4}-[A-Z0-9]{4}$/)
    end

    test "stores token hashed in the database" do
      org = org_fixture()
      user = user_fixture()

      {:ok, token_code} = Devices.generate_init_token(org.id, user.id)
      hash = Devices.hash_token(token_code)

      assert Pretex.Repo.get_by(Pretex.Devices.DeviceInitToken, token_hash: hash)
    end
  end

  describe "provision_device/2" do
    test "provisions a device with a valid token" do
      org = org_fixture()
      user = user_fixture()
      {:ok, token_code} = Devices.generate_init_token(org.id, user.id)

      assert {:ok, %{device: %Device{} = device, api_token: api_token}} =
               Devices.provision_device(token_code, "iPhone de João")

      assert device.name == "iPhone de João"
      assert device.organization_id == org.id
      assert device.status == "active"
      assert device.provisioned_at != nil
      assert is_binary(api_token)
    end

    test "marks init token as used" do
      org = org_fixture()
      user = user_fixture()
      {:ok, token_code} = Devices.generate_init_token(org.id, user.id)

      {:ok, _} = Devices.provision_device(token_code, "Device")

      hash = Devices.hash_token(token_code)
      token = Pretex.Repo.get_by!(Pretex.Devices.DeviceInitToken, token_hash: hash)
      assert token.used_at != nil
    end

    test "rejects already-used token" do
      org = org_fixture()
      user = user_fixture()
      {:ok, token_code} = Devices.generate_init_token(org.id, user.id)

      {:ok, _} = Devices.provision_device(token_code, "Device 1")

      assert {:error, :token_already_used} =
               Devices.provision_device(token_code, "Device 2")
    end

    test "rejects expired token" do
      org = org_fixture()
      user = user_fixture()
      {:ok, token_code} = Devices.generate_init_token(org.id, user.id)

      hash = Devices.hash_token(token_code)
      token = Pretex.Repo.get_by!(Pretex.Devices.DeviceInitToken, token_hash: hash)

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
      token |> Ecto.Changeset.change(expires_at: past) |> Pretex.Repo.update!()

      assert {:error, :token_expired} =
               Devices.provision_device(token_code, "Device")
    end

    test "rejects invalid token" do
      assert {:error, :invalid_token} =
               Devices.provision_device("ZZZZ-ZZZZ", "Device")
    end
  end

  describe "list_devices/1" do
    test "returns devices for organization" do
      org = org_fixture()
      user = user_fixture()
      {:ok, token1} = Devices.generate_init_token(org.id, user.id)
      {:ok, token2} = Devices.generate_init_token(org.id, user.id)

      {:ok, _} = Devices.provision_device(token1, "Device 1")
      {:ok, _} = Devices.provision_device(token2, "Device 2")

      devices = Devices.list_devices(org.id)
      assert length(devices) == 2
    end

    test "does not return devices from other organizations" do
      org1 = org_fixture()
      org2 = org_fixture()
      user = user_fixture()

      {:ok, token} = Devices.generate_init_token(org1.id, user.id)
      {:ok, _} = Devices.provision_device(token, "Device 1")

      assert Devices.list_devices(org2.id) == []
    end
  end

  describe "revoke_device/1" do
    test "revokes an active device" do
      org = org_fixture()
      user = user_fixture()
      {:ok, token} = Devices.generate_init_token(org.id, user.id)
      {:ok, %{device: device}} = Devices.provision_device(token, "Device")

      assert {:ok, revoked} = Devices.revoke_device(device.id)
      assert revoked.status == "revoked"
    end
  end

  describe "authenticate_device/1" do
    test "authenticates with valid API token" do
      org = org_fixture()
      user = user_fixture()
      {:ok, token_code} = Devices.generate_init_token(org.id, user.id)
      {:ok, %{api_token: api_token}} = Devices.provision_device(token_code, "Device")

      assert {:ok, device} = Devices.authenticate_device(api_token)
      assert device.status == "active"
    end

    test "rejects revoked device" do
      org = org_fixture()
      user = user_fixture()
      {:ok, token_code} = Devices.generate_init_token(org.id, user.id)

      {:ok, %{device: device, api_token: api_token}} =
        Devices.provision_device(token_code, "Device")

      {:ok, _} = Devices.revoke_device(device.id)

      assert {:error, :revoked} = Devices.authenticate_device(api_token)
    end

    test "rejects invalid API token" do
      assert {:error, :invalid} = Devices.authenticate_device("bogus-token")
    end
  end
end
