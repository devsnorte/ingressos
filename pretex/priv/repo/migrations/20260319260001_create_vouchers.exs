defmodule Pretex.Repo.Migrations.CreateVouchers do
  use Ecto.Migration

  def change do
    create table(:vouchers) do
      add(:code, :string, null: false)
      add(:effect, :string, null: false, default: "fixed_discount")
      add(:value, :integer, null: false, default: 0)
      add(:max_uses, :integer)
      add(:max_uses_per_code, :integer, null: false, default: 1)
      add(:used_count, :integer, null: false, default: 0)
      add(:valid_until, :utc_datetime)
      add(:active, :boolean, null: false, default: true)
      add(:tag, :string)
      add(:event_id, references(:events, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:vouchers, [:event_id, :code], name: :vouchers_event_id_code_index))
  end
end
