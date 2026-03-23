defmodule Pretex.Repo.Migrations.CreateCheckIns do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :multi_entry, :boolean, default: false, null: false
    end

    create table(:check_ins) do
      add :order_item_id, references(:order_items, on_delete: :restrict), null: false
      add :event_id, references(:events, on_delete: :restrict), null: false
      add :checked_in_by_id, references(:users, on_delete: :restrict), null: false
      add :checked_in_at, :utc_datetime_usec, null: false
      add :annulled_at, :utc_datetime_usec
      add :annulled_by_id, references(:users, on_delete: :restrict)

      timestamps(type: :utc_datetime)
    end

    create index(:check_ins, [:event_id])
    create index(:check_ins, [:order_item_id])

    create unique_index(:check_ins, [:order_item_id, :event_id],
             where: "annulled_at IS NULL",
             name: :check_ins_active_unique
           )
  end
end
