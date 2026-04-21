defmodule Pretex.Repo.Migrations.CreateSeatingPlans do
  use Ecto.Migration

  def change do
    create table(:seating_plans) do
      add :name, :string, null: false
      add :layout, :map, null: false
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:seating_plans, [:organization_id])

    create table(:seating_sections) do
      add :name, :string, null: false
      add :row_count, :integer
      add :capacity, :integer, null: false
      add :seating_plan_id, references(:seating_plans, on_delete: :delete_all), null: false
      add :item_id, references(:items, on_delete: :nilify_all)
      add :item_variation_id, references(:item_variations, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:seating_sections, [:seating_plan_id])
    create index(:seating_sections, [:item_id])

    create table(:seats) do
      add :label, :string, null: false
      add :row, :string, null: false
      add :number, :integer, null: false
      add :status, :string, null: false, default: "available"
      add :seating_section_id, references(:seating_sections, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:seats, [:seating_section_id])
    create unique_index(:seats, [:seating_section_id, :row, :number])

    create table(:seat_reservations) do
      add :status, :string, null: false, default: "held"
      add :held_until, :utc_datetime
      add :seat_id, references(:seats, on_delete: :delete_all), null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :order_item_id, references(:order_items, on_delete: :nilify_all)
      add :cart_session_id, references(:cart_sessions, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:seat_reservations, [:seat_id])
    create index(:seat_reservations, [:event_id])
    create index(:seat_reservations, [:cart_session_id])
    create index(:seat_reservations, [:order_item_id])

    # Partial unique index: only one active (held/confirmed) reservation per seat per event
    create unique_index(:seat_reservations, [:seat_id, :event_id],
             where: "status != 'released'",
             name: :seat_reservations_seat_id_event_id_active_index
           )

    alter table(:events) do
      add :seating_plan_id, references(:seating_plans, on_delete: :nilify_all)
    end
  end
end
