defmodule Pretex.Repo.Migrations.AddAttendeeInfoToCartSessions do
  use Ecto.Migration

  def change do
    alter table(:cart_sessions) do
      add(:attendee_name, :string)
      add(:attendee_email, :string)
    end
  end
end
