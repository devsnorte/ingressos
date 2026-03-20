defmodule Pretex.Repo.Migrations.AddPaymentProviderIdToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add(:payment_provider_id, references(:payment_providers, on_delete: :nilify_all))
    end

    create(index(:orders, [:payment_provider_id]))
  end
end
