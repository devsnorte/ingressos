defmodule Pretex.Customers.CustomerNotifier do
  import Swoosh.Email

  alias Pretex.Mailer
  alias Pretex.Customers.Customer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Pretex", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a customer email.
  """
  def deliver_update_email_instructions(customer, url) do
    deliver(customer.email, "Update email instructions", """

    ==============================

    Hi #{customer.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(customer, url) do
    case customer do
      %Customer{confirmed_at: nil} -> deliver_confirmation_instructions(customer, url)
      _ -> deliver_magic_link_instructions(customer, url)
    end
  end

  defp deliver_magic_link_instructions(customer, url) do
    deliver(customer.email, "Log in instructions", """

    ==============================

    Hi #{customer.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(customer, url) do
    deliver(customer.email, "Confirmation instructions", """

    ==============================

    Hi #{customer.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
