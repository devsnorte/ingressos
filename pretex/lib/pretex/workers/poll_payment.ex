defmodule Pretex.Workers.PollPayment do
  @moduledoc """
  Oban worker that polls the gateway for async payment status updates.

  Used for Pix, boleto, and bank transfer payments where confirmation
  arrives asynchronously — either via webhook or by polling the provider API.

  Uses the snooze pattern: if the payment is still pending, the job snoozes
  for 30 seconds and retries. The worker also checks whether the order has
  expired and the quota is exhausted; in that case it handles the late payment
  by confirming + immediately refunding.

  Enqueue with:

      Pretex.Workers.PollPayment.new(%{
        "payment_id" => payment.id,
        "order_id" => order.id
      })
      |> Oban.insert()
  """

  use Oban.Worker,
    queue: :payments,
    max_attempts: 120,
    unique: [period: 60, keys: ["payment_id"]]

  require Logger

  alias Pretex.Payments
  alias Pretex.Orders

  @snooze_seconds 30
  # Stop polling after 3 days (the maximum async reservation window)
  @max_poll_seconds 3 * 24 * 60 * 60

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"payment_id" => payment_id, "order_id" => order_id},
        inserted_at: inserted_at
      }) do
    payment = Payments.get_payment(payment_id)

    cond do
      is_nil(payment) ->
        # Payment deleted — cancel the job
        {:cancel, "payment #{payment_id} not found"}

      payment.status in ~w(confirmed failed refunded cancelled) ->
        # Already settled — nothing to do
        :ok

      poll_window_expired?(inserted_at) ->
        # Exceeded the maximum polling window — mark as failed
        Logger.warning(
          "PollPayment: payment #{payment_id} exceeded polling window, marking failed"
        )

        case Payments.fail_payment(payment, "payment window expired — no confirmation received") do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      true ->
        handle_pending_payment(payment, order_id)
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("PollPayment: unexpected args #{inspect(args)}")
    {:cancel, "missing required args"}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp handle_pending_payment(payment, order_id) do
    case Payments.check_async_status(payment) do
      :confirmed ->
        Logger.info("PollPayment: payment #{payment.id} confirmed via polling")
        handle_confirmed(payment, order_id)

      :failed ->
        Logger.info("PollPayment: payment #{payment.id} failed via polling")

        case Payments.fail_payment(payment, "gateway reported failure during polling") do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      :pending ->
        {:snooze, @snooze_seconds}

      other ->
        Logger.warning(
          "PollPayment: unexpected status #{inspect(other)} for payment #{payment.id}"
        )

        {:snooze, @snooze_seconds}
    end
  end

  # Called when we have a confirmed payment — but we still need to check
  # whether the order can actually be fulfilled (quota may be exhausted).
  defp handle_confirmed(payment, order_id) do
    order = Orders.get_order!(order_id)

    cond do
      order_still_valid?(order) ->
        # Happy path — confirm the payment and order
        case Payments.confirm_payment(payment) do
          {:ok, _} ->
            Logger.info("PollPayment: order #{order_id} confirmed")
            :ok

          {:error, reason} ->
            {:error, reason}
        end

      late_payment_scenario?(order) ->
        # Order expired AND quota is exhausted — auto-refund
        Logger.warning(
          "PollPayment: late payment for expired order #{order_id} with no quota — initiating refund"
        )

        case Payments.handle_late_payment(payment) do
          {:ok, _refund} -> :ok
          {:error, reason} -> {:error, reason}
        end

      true ->
        # Order expired but quota is still available — re-confirm the order
        # and then confirm the payment so the attendee gets their ticket
        case Orders.reactivate_and_confirm_order(order) do
          {:ok, _order} ->
            case Payments.confirm_payment(payment) do
              {:ok, _} -> :ok
              {:error, reason} -> {:error, reason}
            end

          {:error, :quota_exhausted} ->
            Logger.warning(
              "PollPayment: quota exhausted for order #{order_id} — initiating refund"
            )

            case Payments.handle_late_payment(payment) do
              {:ok, _refund} -> :ok
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # The order is still pending (not expired) and therefore valid to confirm.
  defp order_still_valid?(%{status: "pending", expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :gt
  end

  defp order_still_valid?(_order), do: false

  # The order has expired and cannot be reactivated.
  defp late_payment_scenario?(%{status: status}) when status in ~w(expired cancelled), do: true
  defp late_payment_scenario?(_), do: false

  defp poll_window_expired?(nil), do: false

  defp poll_window_expired?(inserted_at) do
    age_seconds = DateTime.diff(DateTime.utc_now(), inserted_at, :second)
    age_seconds > @max_poll_seconds
  end
end
