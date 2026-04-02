defmodule PretexWeb.Plugs.DeviceAuthTest do
  use PretexWeb.ConnCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.AccountsFixtures

  alias PretexWeb.Plugs.DeviceAuth
  alias Pretex.Devices

  defp provisioned_device_with_token(org) do
    user = user_fixture()
    {:ok, token_code} = Devices.generate_init_token(org.id, user.id)

    {:ok, %{device: device, api_token: api_token}} =
      Devices.provision_device(token_code, "Test Device")

    {device, api_token}
  end

  describe "call/2" do
    test "assigns device when valid token provided" do
      org = org_fixture()
      {device, api_token} = provisioned_device_with_token(org)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{api_token}")
        |> DeviceAuth.call([])

      assert conn.assigns.current_device.id == device.id
      refute conn.halted
    end

    test "returns 401 when no token provided" do
      conn =
        build_conn()
        |> DeviceAuth.call([])

      assert conn.status == 401
      assert conn.halted
    end

    test "returns 401 when token is invalid" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid_token")
        |> DeviceAuth.call([])

      assert conn.status == 401
      assert conn.halted
    end

    test "returns 401 when device is revoked" do
      org = org_fixture()
      {device, api_token} = provisioned_device_with_token(org)
      {:ok, _} = Devices.revoke_device(device.id)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{api_token}")
        |> DeviceAuth.call([])

      assert conn.status == 401
      assert conn.halted
    end
  end
end
