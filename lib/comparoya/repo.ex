defmodule Comparoya.Repo do
  use Ecto.Repo,
    otp_app: :comparoya,
    adapter: Ecto.Adapters.Postgres
end
