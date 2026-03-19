defmodule Pretex.Repo.Migrations.CreateTicketTypes do
  use Ecto.Migration

  def change do
    create table(:ticket_types) do
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :price_cents, :integer, null: false, default: 0
      add :quantity, :integer
      add :status, :string, default: "active", null: false
      timestamps type: :utc_datetime
    end

    create index(:ticket_types, [:event_id])
  end
end
