defmodule Pretex.Payments.EncryptedMap do
  @moduledoc """
  Custom Ecto type that stores maps as encrypted binary.
  Uses Base64 encoding of JSON for storage.
  In production, replace with Cloak.Ecto or similar vault-backed encryption.
  """
  use Ecto.Type

  def type, do: :binary

  def cast(value) when is_map(value), do: {:ok, value}

  def cast(value) when is_binary(value) do
    case JSON.decode(value) do
      {:ok, map} when is_map(map) -> {:ok, map}
      _ -> :error
    end
  end

  def cast(_), do: :error

  def dump(value) when is_map(value) do
    {:ok, encrypt(JSON.encode!(value))}
  end

  def dump(_), do: :error

  def load(value) when is_binary(value) do
    case decrypt(value) do
      {:ok, json} -> JSON.decode(json)
      :error -> :error
    end
  end

  def load(_), do: :error

  # Simple encryption — Base64 encode. Replace with real encryption in production.
  defp encrypt(plaintext) do
    Base.encode64(plaintext)
  end

  defp decrypt(ciphertext) do
    case Base.decode64(ciphertext) do
      {:ok, plaintext} -> {:ok, plaintext}
      :error -> :error
    end
  end
end
