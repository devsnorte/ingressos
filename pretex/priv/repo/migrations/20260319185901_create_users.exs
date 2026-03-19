defmodule Pretex.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :citext, null: false)
      add(:name, :string, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:users, [:email]))
  end
end
