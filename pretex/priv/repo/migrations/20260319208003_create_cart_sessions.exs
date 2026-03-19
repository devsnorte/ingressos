defmodule Pretex.Repo.Migrations.CreateCartSessions do
  use Ecto.Migration

  def change do
    create table(:cart_sessions) do
      add(:event_id, references(:events, on_delete: :delete_all), null: false)
      add(:session_token, :string, null: false)
      add(:expires_at, :utc_datetime, null: false)
      add(:status, :string, default: "active", null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:cart_sessions, [:session_token]))
    create(index(:cart_sessions, [:event_id]))
    create(index(:cart_sessions, [:status]))
  end
end
