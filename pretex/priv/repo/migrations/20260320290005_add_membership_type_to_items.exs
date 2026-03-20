defmodule Pretex.Repo.Migrations.AddMembershipTypeToItems do
  use Ecto.Migration

  def change do
    alter table(:items) do
      add(:membership_type_id, references(:membership_types, on_delete: :nilify_all))
    end

    create(index(:items, [:membership_type_id]))
  end
end
