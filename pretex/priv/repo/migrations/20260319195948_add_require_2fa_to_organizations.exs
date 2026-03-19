defmodule Pretex.Repo.Migrations.AddRequire2faToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :require_2fa, :boolean, default: false, null: false
    end
  end
end
