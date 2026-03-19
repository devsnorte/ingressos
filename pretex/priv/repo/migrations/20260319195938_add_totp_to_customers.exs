defmodule Pretex.Repo.Migrations.AddTotpToCustomers do
  use Ecto.Migration

  def change do
    alter table(:customers) do
      add :totp_secret, :binary
      add :totp_enabled_at, :utc_datetime
    end
  end
end
