defmodule Pretex.PaymentsTest do
  use Pretex.DataCase, async: true

  alias Pretex.Payments
  alias Pretex.Payments.PaymentProvider
  import Pretex.OrganizationsFixtures

  describe "available_providers/0" do
    test "retorna todos os tipos de provedores" do
      providers = Payments.available_providers()
      types = Enum.map(providers, & &1.type)
      assert "manual" in types
      assert "woovi" in types
      assert "stripe" in types
      assert "abacatepay" in types
      assert "asaas" in types
    end

    test "cada provedor possui campos obrigatórios" do
      for provider <- Payments.available_providers() do
        assert is_list(provider.required_fields)
        assert is_list(provider.payment_methods)
        assert is_binary(provider.display_name)
        assert is_binary(provider.description)
      end
    end
  end

  describe "create_provider/1" do
    test "cria um provedor com atributos válidos" do
      org = org_fixture()

      assert {:ok, %PaymentProvider{} = provider} =
               Payments.create_provider(%{
                 organization_id: org.id,
                 type: "stripe",
                 name: "Stripe Principal",
                 credentials: %{
                   "secret_key" => "sk_test_123",
                   "publishable_key" => "pk_test_456"
                 }
               })

      assert provider.type == "stripe"
      assert provider.name == "Stripe Principal"
      assert provider.is_active == false
      assert provider.validation_status == "pending"
      assert provider.webhook_token != nil
    end

    test "rejeita tipo de provedor inválido" do
      org = org_fixture()

      assert {:error, changeset} =
               Payments.create_provider(%{
                 organization_id: org.id,
                 type: "invalid",
                 name: "Bad",
                 credentials: %{}
               })

      assert %{type: [_]} = errors_on(changeset)
    end

    test "rejeita campos obrigatórios ausentes" do
      assert {:error, changeset} = Payments.create_provider(%{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :organization_id)
      assert Map.has_key?(errors, :type)
      assert Map.has_key?(errors, :name)
    end
  end

  describe "list_providers/1" do
    test "retorna provedores de uma organização" do
      org = org_fixture()

      {:ok, _} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "stripe",
          name: "Stripe",
          credentials: %{"secret_key" => "sk_test_x"}
        })

      {:ok, _} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "woovi",
          name: "Woovi",
          credentials: %{"api_key" => "key"}
        })

      providers = Payments.list_providers(org.id)
      assert length(providers) == 2
    end

    test "não retorna provedores de outras organizações" do
      org1 = org_fixture()
      org2 = org_fixture()

      {:ok, _} =
        Payments.create_provider(%{
          organization_id: org1.id,
          type: "stripe",
          name: "Stripe",
          credentials: %{"secret_key" => "sk_test_x"}
        })

      assert Payments.list_providers(org2.id) == []
    end
  end

  describe "validate_provider/1" do
    test "valida credenciais do stripe com formato correto" do
      org = org_fixture()

      {:ok, provider} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "stripe",
          name: "Stripe",
          credentials: %{"secret_key" => "sk_test_valid123"}
        })

      assert {:ok, updated} = Payments.validate_provider(provider)
      assert updated.validation_status == "valid"
      assert updated.is_active == true
      assert updated.last_validated_at != nil
    end

    test "rejeita credenciais do stripe com formato incorreto" do
      org = org_fixture()

      {:ok, provider} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "stripe",
          name: "Stripe",
          credentials: %{"secret_key" => "invalid_key"}
        })

      assert {:error, _reason} = Payments.validate_provider(provider)
      refreshed = Payments.get_provider!(provider.id)
      assert refreshed.validation_status == "invalid"
      assert refreshed.is_active == false
    end

    test "provedor manual sempre valida com sucesso" do
      org = org_fixture()

      {:ok, provider} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "manual",
          name: "Manual",
          credentials: %{"bank_info" => "Banco do Brasil - Ag 1234"}
        })

      assert {:ok, updated} = Payments.validate_provider(provider)
      assert updated.validation_status == "valid"
    end
  end

  describe "mask_credentials/1" do
    test "mascara valores de credenciais mostrando apenas últimos 4 caracteres" do
      org = org_fixture()

      {:ok, provider} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "stripe",
          name: "S",
          credentials: %{"secret_key" => "sk_test_abcdef123456"}
        })

      masked = Payments.mask_credentials(provider)
      assert masked["secret_key"] == "••••3456"
    end

    test "mascara valores curtos completamente" do
      org = org_fixture()

      {:ok, provider} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "manual",
          name: "M",
          credentials: %{"bank_info" => "abc"}
        })

      masked = Payments.mask_credentials(provider)
      assert masked["bank_info"] == "••••"
    end
  end

  describe "set_default_provider/1" do
    test "define provedor como padrão e remove padrão dos outros" do
      org = org_fixture()

      {:ok, p1} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "stripe",
          name: "Stripe",
          credentials: %{"secret_key" => "sk_test_1"},
          is_default: true
        })

      {:ok, p2} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "woovi",
          name: "Woovi",
          credentials: %{"api_key" => "k"}
        })

      {:ok, updated} = Payments.set_default_provider(p2)
      assert updated.is_default == true

      refreshed_p1 = Payments.get_provider!(p1.id)
      assert refreshed_p1.is_default == false
    end
  end

  describe "delete_provider/1" do
    test "remove um provedor" do
      org = org_fixture()

      {:ok, provider} =
        Payments.create_provider(%{
          organization_id: org.id,
          type: "stripe",
          name: "S",
          credentials: %{"secret_key" => "sk_test_x"}
        })

      assert {:ok, _} = Payments.delete_provider(provider)
      assert_raise Ecto.NoResultsError, fn -> Payments.get_provider!(provider.id) end
    end
  end

  describe "adapter behaviour" do
    test "todos os adapters implementam o behaviour" do
      for {_type, mod} <- [
            {"manual", Pretex.Payments.Adapters.Manual},
            {"woovi", Pretex.Payments.Adapters.Woovi},
            {"stripe", Pretex.Payments.Adapters.Stripe},
            {"abacatepay", Pretex.Payments.Adapters.AbacatePay},
            {"asaas", Pretex.Payments.Adapters.Asaas}
          ] do
        assert is_binary(mod.display_name())
        assert is_binary(mod.description())
        assert is_list(mod.required_fields())
        assert is_list(mod.payment_methods())
      end
    end
  end
end
