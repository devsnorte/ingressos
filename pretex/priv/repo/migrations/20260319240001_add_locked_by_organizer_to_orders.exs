defmodule Pretex.Repo.Migrations.AddLockedByOrganizerToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add(:locked_by_organizer, :boolean, default: false, null: false)
    end
  end
end
