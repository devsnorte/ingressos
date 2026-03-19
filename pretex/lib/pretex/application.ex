defmodule Pretex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PretexWeb.Telemetry,
      Pretex.Repo,
      {DNSCluster, query: Application.get_env(:pretex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pretex.PubSub},
      # Start a worker by calling: Pretex.Worker.start_link(arg)
      # {Pretex.Worker, arg},
      # Start to serve requests, typically the last entry
      PretexWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pretex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PretexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
