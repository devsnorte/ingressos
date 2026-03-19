defmodule PretexWeb.CustomerAuthTest do
  use PretexWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias Pretex.Customers
  alias Pretex.Customers.Scope
  alias PretexWeb.CustomerAuth

  import Pretex.CustomersFixtures

  @remember_me_cookie "_pretex_web_customer_remember_me"
  @remember_me_cookie_max_age 60 * 60 * 24 * 14

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, PretexWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{customer: %{customer_fixture() | authenticated_at: DateTime.utc_now(:second)}, conn: conn}
  end

  describe "log_in_customer/3" do
    test "stores the customer token in the session", %{conn: conn, customer: customer} do
      conn = CustomerAuth.log_in_customer(conn, customer)
      assert token = get_session(conn, :customer_token)

      assert get_session(conn, :live_socket_id) ==
               "customers_sessions:#{Base.url_encode64(token)}"

      assert redirected_to(conn) == ~p"/"
      assert Customers.get_customer_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, customer: customer} do
      conn =
        conn |> put_session(:to_be_removed, "value") |> CustomerAuth.log_in_customer(customer)

      refute get_session(conn, :to_be_removed)
    end

    test "keeps session when re-authenticating", %{conn: conn, customer: customer} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_customer(customer))
        |> put_session(:to_be_removed, "value")
        |> CustomerAuth.log_in_customer(customer)

      assert get_session(conn, :to_be_removed)
    end

    test "clears session when customer does not match when re-authenticating", %{
      conn: conn,
      customer: customer
    } do
      other_customer = customer_fixture()

      conn =
        conn
        |> assign(:current_scope, Scope.for_customer(other_customer))
        |> put_session(:to_be_removed, "value")
        |> CustomerAuth.log_in_customer(customer)

      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, customer: customer} do
      conn =
        conn
        |> put_session(:customer_return_to, "/hello")
        |> CustomerAuth.log_in_customer(customer)

      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, customer: customer} do
      conn =
        conn
        |> fetch_cookies()
        |> CustomerAuth.log_in_customer(customer, %{"remember_me" => "true"})

      assert get_session(conn, :customer_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :customer_remember_me) == true

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :customer_token)
      assert max_age == @remember_me_cookie_max_age
    end

    test "redirects to settings when customer is already logged in", %{
      conn: conn,
      customer: customer
    } do
      conn =
        conn
        |> assign(:current_scope, Scope.for_customer(customer))
        |> CustomerAuth.log_in_customer(customer)

      assert redirected_to(conn) == ~p"/customers/settings"
    end

    test "writes a cookie if remember_me was set in previous session", %{
      conn: conn,
      customer: customer
    } do
      conn =
        conn
        |> fetch_cookies()
        |> CustomerAuth.log_in_customer(customer, %{"remember_me" => "true"})

      assert get_session(conn, :customer_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :customer_remember_me) == true

      conn =
        conn
        |> recycle()
        |> Map.replace!(:secret_key_base, PretexWeb.Endpoint.config(:secret_key_base))
        |> fetch_cookies()
        |> init_test_session(%{customer_remember_me: true})

      # the conn is already logged in and has the remember_me cookie set,
      # now we log in again and even without explicitly setting remember_me,
      # the cookie should be set again
      conn = conn |> CustomerAuth.log_in_customer(customer, %{})
      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :customer_token)
      assert max_age == @remember_me_cookie_max_age
      assert get_session(conn, :customer_remember_me) == true
    end
  end

  describe "logout_customer/1" do
    test "erases session and cookies", %{conn: conn, customer: customer} do
      customer_token = Customers.generate_customer_session_token(customer)

      conn =
        conn
        |> put_session(:customer_token, customer_token)
        |> put_req_cookie(@remember_me_cookie, customer_token)
        |> fetch_cookies()
        |> CustomerAuth.log_out_customer()

      refute get_session(conn, :customer_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Customers.get_customer_by_session_token(customer_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "customers_sessions:abcdef-token"
      PretexWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> CustomerAuth.log_out_customer()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if customer is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> CustomerAuth.log_out_customer()
      refute get_session(conn, :customer_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_scope_for_customer/2" do
    test "authenticates customer from session", %{conn: conn, customer: customer} do
      customer_token = Customers.generate_customer_session_token(customer)

      conn =
        conn
        |> put_session(:customer_token, customer_token)
        |> CustomerAuth.fetch_current_scope_for_customer([])

      assert conn.assigns.current_scope.customer.id == customer.id
      assert conn.assigns.current_scope.customer.authenticated_at == customer.authenticated_at
      assert get_session(conn, :customer_token) == customer_token
    end

    test "authenticates customer from cookies", %{conn: conn, customer: customer} do
      logged_in_conn =
        conn
        |> fetch_cookies()
        |> CustomerAuth.log_in_customer(customer, %{"remember_me" => "true"})

      customer_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> CustomerAuth.fetch_current_scope_for_customer([])

      assert conn.assigns.current_scope.customer.id == customer.id
      assert conn.assigns.current_scope.customer.authenticated_at == customer.authenticated_at
      assert get_session(conn, :customer_token) == customer_token
      assert get_session(conn, :customer_remember_me)

      assert get_session(conn, :live_socket_id) ==
               "customers_sessions:#{Base.url_encode64(customer_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, customer: customer} do
      _ = Customers.generate_customer_session_token(customer)
      conn = CustomerAuth.fetch_current_scope_for_customer(conn, [])
      refute get_session(conn, :customer_token)
      refute conn.assigns.current_scope
    end

    test "reissues a new token after a few days and refreshes cookie", %{
      conn: conn,
      customer: customer
    } do
      logged_in_conn =
        conn
        |> fetch_cookies()
        |> CustomerAuth.log_in_customer(customer, %{"remember_me" => "true"})

      token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      offset_customer_token(token, -10, :day)
      {customer, _} = Customers.get_customer_by_session_token(token)

      conn =
        conn
        |> put_session(:customer_token, token)
        |> put_session(:customer_remember_me, true)
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> CustomerAuth.fetch_current_scope_for_customer([])

      assert conn.assigns.current_scope.customer.id == customer.id
      assert conn.assigns.current_scope.customer.authenticated_at == customer.authenticated_at
      assert new_token = get_session(conn, :customer_token)
      assert new_token != token
      assert %{value: new_signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert new_signed_token != signed_token
      assert max_age == @remember_me_cookie_max_age
    end
  end

  describe "on_mount :mount_current_scope" do
    setup %{conn: conn} do
      %{conn: CustomerAuth.fetch_current_scope_for_customer(conn, [])}
    end

    test "assigns current_scope based on a valid customer_token", %{
      conn: conn,
      customer: customer
    } do
      customer_token = Customers.generate_customer_session_token(customer)
      session = conn |> put_session(:customer_token, customer_token) |> get_session()

      {:cont, updated_socket} =
        CustomerAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.customer.id == customer.id
    end

    test "assigns nil to current_scope assign if there isn't a valid customer_token", %{
      conn: conn
    } do
      customer_token = "invalid_token"
      session = conn |> put_session(:customer_token, customer_token) |> get_session()

      {:cont, updated_socket} =
        CustomerAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end

    test "assigns nil to current_scope assign if there isn't a customer_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        CustomerAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_authenticated" do
    test "authenticates current_scope based on a valid customer_token", %{
      conn: conn,
      customer: customer
    } do
      customer_token = Customers.generate_customer_session_token(customer)
      session = conn |> put_session(:customer_token, customer_token) |> get_session()

      {:cont, updated_socket} =
        CustomerAuth.on_mount(:require_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.customer.id == customer.id
    end

    test "redirects to login page if there isn't a valid customer_token", %{conn: conn} do
      customer_token = "invalid_token"
      session = conn |> put_session(:customer_token, customer_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: PretexWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        CustomerAuth.on_mount(:require_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_scope == nil
    end

    test "redirects to login page if there isn't a customer_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: PretexWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        CustomerAuth.on_mount(:require_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_sudo_mode" do
    test "allows customers that have authenticated in the last 10 minutes", %{
      conn: conn,
      customer: customer
    } do
      customer_token = Customers.generate_customer_session_token(customer)
      session = conn |> put_session(:customer_token, customer_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: PretexWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:cont, _updated_socket} =
               CustomerAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end

    test "redirects when authentication is too old", %{conn: conn, customer: customer} do
      eleven_minutes_ago = DateTime.utc_now(:second) |> DateTime.add(-11, :minute)
      customer = %{customer | authenticated_at: eleven_minutes_ago}
      customer_token = Customers.generate_customer_session_token(customer)
      {customer, token_inserted_at} = Customers.get_customer_by_session_token(customer_token)
      assert DateTime.compare(token_inserted_at, customer.authenticated_at) == :gt
      session = conn |> put_session(:customer_token, customer_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: PretexWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:halt, _updated_socket} =
               CustomerAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end
  end

  describe "require_authenticated_customer/2" do
    setup %{conn: conn} do
      %{conn: CustomerAuth.fetch_current_scope_for_customer(conn, [])}
    end

    test "redirects if customer is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> CustomerAuth.require_authenticated_customer([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/customers/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> CustomerAuth.require_authenticated_customer([])

      assert halted_conn.halted
      assert get_session(halted_conn, :customer_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> CustomerAuth.require_authenticated_customer([])

      assert halted_conn.halted
      assert get_session(halted_conn, :customer_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> CustomerAuth.require_authenticated_customer([])

      assert halted_conn.halted
      refute get_session(halted_conn, :customer_return_to)
    end

    test "does not redirect if customer is authenticated", %{conn: conn, customer: customer} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_customer(customer))
        |> CustomerAuth.require_authenticated_customer([])

      refute conn.halted
      refute conn.status
    end
  end

  describe "disconnect_sessions/1" do
    test "broadcasts disconnect messages for each token" do
      tokens = [%{token: "token1"}, %{token: "token2"}]

      for %{token: token} <- tokens do
        PretexWeb.Endpoint.subscribe("customers_sessions:#{Base.url_encode64(token)}")
      end

      CustomerAuth.disconnect_sessions(tokens)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "customers_sessions:dG9rZW4x"
      }

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "customers_sessions:dG9rZW4y"
      }
    end
  end
end
