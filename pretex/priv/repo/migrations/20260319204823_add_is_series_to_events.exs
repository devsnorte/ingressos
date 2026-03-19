defmodule Pretex.Repo.Migrations.AddIsSeriesToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:is_series, :boolean, default: false, null: false)
    end
  end
end
