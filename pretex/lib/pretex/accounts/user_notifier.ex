defmodule Pretex.Accounts.UserNotifier do
  import Swoosh.Email

  alias Pretex.Mailer

  defp deliver(to, subject, body) do
    email =
      new()
      |> to(to)
      |> from({"Pretex", "noreply@pretex.io"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc "Sends a magic login link to a staff user."
  def deliver_login_instructions(user, url) do
    deliver(user.email, "Your Pretex staff login link", """

    ==============================

    Hi #{user.email},

    Click the link below to log in to the Pretex admin area.
    This link is valid for 10 minutes.

    #{url}

    If you didn't request this, please ignore this email.

    ==============================
    """)
  end
end
