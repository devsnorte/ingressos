defmodule Pretex.Devices do
  @moduledoc "Manages device provisioning and authentication."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Devices.{Device, DeviceAssignment, DeviceInitToken}

  @token_expiry_hours 24

  def hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  end

  def generate_init_token(organization_id, user_id) do
    code = generate_short_code()
    hash = hash_token(code)

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@token_expiry_hours * 3600, :second)
      |> DateTime.truncate(:second)

    %DeviceInitToken{}
    |> DeviceInitToken.changeset(%{expires_at: expires_at})
    |> Ecto.Changeset.put_change(:token_hash, hash)
    |> Ecto.Changeset.put_change(:organization_id, organization_id)
    |> Ecto.Changeset.put_change(:created_by_id, user_id)
    |> Repo.insert()
    |> case do
      {:ok, _} -> {:ok, code}
      {:error, cs} -> {:error, cs}
    end
  end

  def provision_device(token_code, device_name) do
    hash = hash_token(token_code)

    case Repo.get_by(DeviceInitToken, token_hash: hash) do
      nil ->
        {:error, :invalid_token}

      %{used_at: used_at} when not is_nil(used_at) ->
        {:error, :token_already_used}

      token ->
        if DateTime.compare(token.expires_at, DateTime.utc_now()) == :lt do
          {:error, :token_expired}
        else
          create_device_from_token(token, device_name)
        end
    end
  end

  defp create_device_from_token(token, device_name) do
    api_token = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    api_token_hash = hash_token(api_token)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      token
      |> Ecto.Changeset.change(used_at: now)
      |> Repo.update!()

      device =
        %Device{}
        |> Device.changeset(%{name: device_name})
        |> Ecto.Changeset.put_change(:api_token_hash, api_token_hash)
        |> Ecto.Changeset.put_change(:organization_id, token.organization_id)
        |> Ecto.Changeset.put_change(:provisioned_by_id, token.created_by_id)
        |> Ecto.Changeset.put_change(:provisioned_at, now)
        |> Repo.insert!()

      %{device: device, api_token: api_token}
    end)
  end

  def list_devices(organization_id) do
    Device
    |> where([d], d.organization_id == ^organization_id)
    |> order_by([d], desc: d.provisioned_at)
    |> preload(:provisioned_by)
    |> Repo.all()
  end

  def get_device!(id), do: Repo.get!(Device, id)

  def revoke_device(device_id) do
    device = Repo.get!(Device, device_id)

    device
    |> Ecto.Changeset.change(status: "revoked")
    |> Repo.update()
  end

  def authenticate_device(api_token) do
    hash = hash_token(api_token)

    case Repo.get_by(Device, api_token_hash: hash) do
      nil ->
        {:error, :invalid}

      %{status: "revoked"} ->
        {:error, :revoked}

      device ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        device |> Ecto.Changeset.change(last_seen_at: now) |> Repo.update()
    end
  end

  def assign_device_to_event(device_id, event_id) do
    %DeviceAssignment{}
    |> DeviceAssignment.changeset(%{device_id: device_id, event_id: event_id})
    |> Repo.insert()
  end

  def unassign_device_from_event(device_id, event_id) do
    DeviceAssignment
    |> where([a], a.device_id == ^device_id and a.event_id == ^event_id)
    |> Repo.delete_all()

    :ok
  end

  def list_device_assignments(device_id) do
    DeviceAssignment
    |> where([a], a.device_id == ^device_id)
    |> preload(:event)
    |> Repo.all()
  end

  defp generate_short_code do
    part = fn ->
      :crypto.strong_rand_bytes(2)
      |> Base.encode32(case: :upper, padding: false)
      |> String.slice(0, 4)
    end

    "#{part.()}-#{part.()}"
  end
end
