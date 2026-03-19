defmodule Pretex.Repo.Migrations.CreateCustomerRecoveryCodes do
  use Ecto.Migration

  def change do
    create table(:customer_recovery_codes) do
      add :customer_id, references(:customers, on_delete: :delete_all), null: false
      add :code_hash, :string, null: false
      add :used_at, :utc_datetime
      timestamps type: :utc_datetime
    end

    create index(:customer_recovery_codes, [:customer_id])
  end
end
