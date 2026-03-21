defmodule Pretex.Repo.Migrations.AddTransferNoteToPayments do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      add(:transfer_note, :text)
    end
  end
end
