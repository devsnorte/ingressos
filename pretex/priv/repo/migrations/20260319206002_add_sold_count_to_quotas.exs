defmodule Pretex.Repo.Migrations.AddSoldCountToQuotas do
  use Ecto.Migration

  def change do
    alter table(:quotas) do
      add(:sold_count, :integer, default: 0, null: false)
    end
  end
end
