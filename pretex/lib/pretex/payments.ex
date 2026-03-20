defmodule Pretex.Payments do
  @moduledoc """
  The Payments context manages BYOG payment provider configuration.
  Each organization configures their own payment providers.
  """

  import Ecto.Query
  alias Pretex.Repo
  alias Pretex.Payments.PaymentProvider

  @adapters %{
    "manual" => Pretex.Payments.Adapters.Manual,
    "woovi" => Pretex.Payments.Adapters.Woovi,
    "stripe" => Pretex.Payments.Adapters.Stripe,
    "abacatepay" => Pretex.Payments.Adapters.AbacatePay,
    "asaas" => Pretex.Payments.Adapters.Asaas
  }

  # -- Provider Types --

  def available_providers do
    Enum.map(@adapters, fn {type, mod} ->
      %{
        type: type,
        display_name: mod.display_name(),
        description: mod.description(),
        required_fields: mod.required_fields(),
        payment_methods: mod.payment_methods()
      }
    end)
    |> Enum.sort_by(& &1.display_name)
  end

  def adapter_for(type) do
    Map.get(@adapters, type)
  end

  def adapter_module!(%PaymentProvider{type: type}) do
    Map.fetch!(@adapters, type)
  end

  # -- CRUD --

  def list_providers(organization_id) do
    PaymentProvider
    |> where([p], p.organization_id == ^organization_id)
    |> order_by([p], asc: :name)
    |> Repo.all()
  end

  def get_provider!(id), do: Repo.get!(PaymentProvider, id)

  def get_provider(id), do: Repo.get(PaymentProvider, id)

  def get_default_provider(organization_id) do
    PaymentProvider
    |> where(
      [p],
      p.organization_id == ^organization_id and p.is_default == true and p.is_active == true
    )
    |> Repo.one()
  end

  def create_provider(attrs) do
    %PaymentProvider{}
    |> PaymentProvider.creation_changeset(attrs)
    |> Repo.insert()
  end

  def update_provider(%PaymentProvider{} = provider, attrs) do
    provider
    |> PaymentProvider.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_provider(%PaymentProvider{} = provider) do
    Repo.delete(provider)
  end

  def change_provider(%PaymentProvider{} = provider, attrs \\ %{}) do
    PaymentProvider.creation_changeset(provider, attrs)
  end

  def count_active_providers(organization_id) do
    PaymentProvider
    |> where([p], p.organization_id == ^organization_id and p.is_active == true)
    |> Repo.aggregate(:count)
  end

  # -- Validation --

  def validate_provider(%PaymentProvider{} = provider) do
    adapter = adapter_module!(provider)

    case adapter.validate_credentials(provider.credentials) do
      {:ok, :valid} ->
        provider
        |> PaymentProvider.validation_changeset(%{
          validation_status: "valid",
          last_validated_at: DateTime.utc_now() |> DateTime.truncate(:second),
          is_active: true
        })
        |> Repo.update()

      {:error, reason} ->
        provider
        |> PaymentProvider.validation_changeset(%{
          validation_status: "invalid",
          last_validated_at: DateTime.utc_now() |> DateTime.truncate(:second),
          is_active: false
        })
        |> Repo.update()

        {:error, reason}
    end
  end

  # -- Credential Masking --

  def mask_credentials(%PaymentProvider{credentials: creds}) when is_map(creds) do
    Map.new(creds, fn {key, value} ->
      masked =
        if is_binary(value) and byte_size(value) > 4 do
          "••••" <> String.slice(value, -4, 4)
        else
          "••••"
        end

      {key, masked}
    end)
  end

  def mask_credentials(_), do: %{}

  # -- Set Default --

  def set_default_provider(%PaymentProvider{} = provider) do
    Repo.transaction(fn ->
      # Unset all defaults for this org
      from(p in PaymentProvider,
        where: p.organization_id == ^provider.organization_id and p.is_default == true
      )
      |> Repo.update_all(set: [is_default: false])

      # Set this one as default
      provider
      |> PaymentProvider.update_changeset(%{is_default: true})
      |> Repo.update!()
    end)
  end
end
