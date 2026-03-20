defmodule Pretex.Workers.ExpireStaleOrders do
  @moduledoc """
  Oban worker that periodically marks stale pending orders as expired.

  Runs every 5 minutes via the Oban cron plugin (configured in config.exs).
  An order is considered stale when its `expires_at` timestamp is in the past
  and its status is still "pending".

  This is a safety net in addition to the per-order expiry timers. It ensures
  that any orders which slipped through (e.g. due to a server restart) are
  eventually cleaned up.
  """

  use Oban.Worker,
    queue: :scheduled,
    max_attempts: 3,
    unique: [period: 240]

  require Logger

  alias Pretex.Orders

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {count, _} = Orders.expire_stale_orders()

    if count > 0 do
      Logger.info("ExpireStaleOrders: expired #{count} stale order(s)")
    end

    :ok
  end
end
