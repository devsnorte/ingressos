defmodule Pretex.Repo.Migrations.AddTotpToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :totp_secret, :binary
      add :totp_enabled_at, :utc_datetime
    end
  end
end
