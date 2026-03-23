defmodule Pretex.Repo.Migrations.CreateCheckInListsAndGates do
  use Ecto.Migration

  def change do
    create table(:check_in_lists) do
      add :name, :string, null: false
      add :starts_at_time, :time
      add :ends_at_time, :time
      add :event_id, references(:events, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:check_in_lists, [:event_id])

    create table(:check_in_list_items) do
      add :check_in_list_id, references(:check_in_lists, on_delete: :delete_all), null: false
      add :item_id, references(:items, on_delete: :delete_all), null: false
      add :item_variation_id, references(:item_variations, on_delete: :delete_all)
    end

    create unique_index(:check_in_list_items, [:check_in_list_id, :item_id, :item_variation_id],
             name: :check_in_list_items_unique
           )

    create table(:gates) do
      add :name, :string, null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:gates, [:event_id])

    create table(:gate_check_in_lists, primary_key: false) do
      add :gate_id, references(:gates, on_delete: :delete_all), null: false
      add :check_in_list_id, references(:check_in_lists, on_delete: :delete_all), null: false
    end

    create unique_index(:gate_check_in_lists, [:gate_id, :check_in_list_id])

    alter table(:check_ins) do
      add :check_in_list_id, references(:check_in_lists, on_delete: :restrict)
    end

    drop unique_index(:check_ins, [:order_item_id, :event_id],
           where: "annulled_at IS NULL",
           name: :check_ins_active_unique
         )

    create unique_index(:check_ins, [:order_item_id, :event_id, "COALESCE(check_in_list_id, 0)"],
             where: "annulled_at IS NULL",
             name: :check_ins_active_unique
           )

    create index(:check_ins, [:check_in_list_id])
  end
end
