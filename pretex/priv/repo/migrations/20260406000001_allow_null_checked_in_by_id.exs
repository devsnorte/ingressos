defmodule Pretex.Repo.Migrations.AllowNullCheckedInById do
  use Ecto.Migration

  def change do
    alter table(:check_ins) do
      modify :checked_in_by_id, :bigint, null: true, from: {:bigint, null: false}
    end
  end
end
