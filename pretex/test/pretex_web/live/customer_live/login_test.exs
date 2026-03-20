defmodule PretexWeb.CustomerLive.LoginTest do
  use PretexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Pretex.CustomersFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/customers/log-in")

      assert html =~ "Entrar na sua conta"
      assert html =~ "Criar conta"
      assert html =~ "Entrar com e-mail"
    end
  end

  describe "customer login - magic link" do
    test "sends magic link email when customer exists", %{conn: conn} do
      customer = customer_fixture()

      {:ok, lv, _html} = live(conn, ~p"/customers/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", customer: %{email: customer.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/customers/log-in")

      assert html =~ "If your email is in our system"

      assert Pretex.Repo.get_by!(Pretex.Customers.CustomerToken, customer_id: customer.id).context ==
               "login"
    end

    test "does not disclose if customer is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", customer: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/customers/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "customer login - password" do
    test "redirects if customer logs in with valid credentials", %{conn: conn} do
      customer = customer_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/customers/log-in")

      form =
        form(lv, "#login_form_password",
          customer: %{
            email: customer.email,
            password: valid_customer_password(),
            remember_me: true
          }
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/customers/log-in")

      form =
        form(lv, "#login_form_password", customer: %{email: "test@email.com", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/customers/log-in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/customers/log-in")

      {:ok, _login_live, login_html} =
        lv
        |> element("a", "Criar conta")
        |> render_click()
        |> follow_redirect(conn, ~p"/customers/register")

      assert login_html =~ "Criar sua conta"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      customer = customer_fixture()
      %{customer: customer, conn: log_in_customer(conn, customer)}
    end

    test "shows login page with email filled in", %{conn: conn, customer: customer} do
      {:ok, _lv, html} = live(conn, ~p"/customers/log-in")

      assert html =~ "Você precisa se autenticar novamente"
      refute html =~ "Criar conta"
      assert html =~ "Entrar com e-mail"

      assert html =~
               ~s(<input type="email" name="customer[email]" id="login_form_magic_email" value="#{customer.email}")
    end
  end
end
