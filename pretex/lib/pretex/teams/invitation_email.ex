defmodule Pretex.Teams.InvitationEmail do
  import Swoosh.Email

  def invite(invitation, organization) do
    invite_url = "https://pretex.io/invitations/#{invitation.token}"

    new()
    |> to(invitation.email)
    |> from({"Pretex", "noreply@pretex.io"})
    |> subject("You've been invited to join #{organization.name} on Pretex")
    |> text_body("""
    Hi there!

    You've been invited to join #{organization.name} on Pretex as a #{format_role(invitation.role)}.

    Click the link below to accept your invitation:

    #{invite_url}

    This invitation expires on #{format_date(invitation.expires_at)}.

    If you did not expect this invitation, you can safely ignore this email.

    — The Pretex Team
    """)
  end

  defp format_role("admin"), do: "Admin"
  defp format_role("event_manager"), do: "Event Manager"
  defp format_role("checkin_operator"), do: "Check-in Operator"
  defp format_role(role), do: role

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y")
  end
end
