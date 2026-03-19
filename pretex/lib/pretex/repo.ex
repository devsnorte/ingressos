defmodule Pretex.Repo do
  use Ecto.Repo,
    otp_app: :pretex,
    adapter: Ecto.Adapters.Postgres
end
