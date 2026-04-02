defmodule PretexWeb.SyncControllerTest do
  use PretexWeb.ConnCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.AccountsFixtures
  import Pretex.EventsFixtures
  import Pretex.CatalogFixtures

  alias Pretex.{Devices, Orders}

  defp provisioned_device_with_token(org) do
    user = user_fixture()
    {:ok, token_code} = Devices.generate_init_token(org.id, user.id)

    {:ok, %{device: device, api_token: api_token}} =
      Devices.provision_device(token_code, "Test Device")

    {device, api_token}
  end

  defp confirmed_order_fixture(event) do
    {:ok, cart} = Orders.create_cart(event)
    cart = Orders.get_cart_by_token(cart.session_token)
    item = item_fixture(event)
    {:ok, _} = Orders.add_to_cart(cart, item)
    cart = Orders.get_cart_by_token(cart.session_token)

    {:ok, order} =
      Orders.create_order_from_cart(cart, %{
        name: "Jane Doe",
        email: "jane@example.com",
        payment_method: "pix"
      })

    {:ok, order} = Orders.confirm_order(order)
    Orders.get_order!(order.id)
  end

  defp auth_conn(conn, api_token) do
    put_req_header(conn, "authorization", "Bearer #{api_token}")
  end

  describe "GET /api/sync/manifest" do
    test "returns manifest for authenticated device", %{conn: conn} do
      org = org_fixture()
      {device, api_token} = provisioned_device_with_token(org)
      event = published_event_fixture(org)
      _order = confirmed_order_fixture(event)

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      conn =
        conn
        |> auth_conn(api_token)
        |> get("/api/sync/manifest")

      assert %{"events" => [ev], "server_timestamp" => _} = json_response(conn, 200)
      assert ev["id"] == event.id
      assert length(ev["attendees"]) >= 1
    end

    test "supports incremental sync with since param", %{conn: conn} do
      org = org_fixture()
      {device, api_token} = provisioned_device_with_token(org)
      event = published_event_fixture(org)

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      conn1 =
        conn
        |> auth_conn(api_token)
        |> get("/api/sync/manifest")

      %{"server_timestamp" => ts} = json_response(conn1, 200)

      conn2 =
        build_conn()
        |> auth_conn(api_token)
        |> get("/api/sync/manifest", %{since: ts})

      %{"events" => events} = json_response(conn2, 200)
      assert Enum.all?(events, fn ev -> ev["attendees"] == [] end)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = get(conn, "/api/sync/manifest")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/sync/checkins" do
    test "uploads offline check-ins", %{conn: conn} do
      org = org_fixture()
      {device, api_token} = provisioned_device_with_token(org)
      event = published_event_fixture(org)
      order = confirmed_order_fixture(event)
      [order_item | _] = order.order_items

      {:ok, _} = Devices.assign_device_to_event(device.id, event.id)

      conn =
        conn
        |> auth_conn(api_token)
        |> post("/api/sync/checkins", %{
          "checkins" => [
            %{
              "ticket_code" => order_item.ticket_code,
              "event_id" => event.id,
              "checked_in_at" => "2026-04-02T09:15:00Z"
            }
          ]
        })

      assert %{"inserted" => 1, "processed" => 1} = json_response(conn, 200)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, "/api/sync/checkins", %{"checkins" => []})
      assert json_response(conn, 401)
    end
  end
end
