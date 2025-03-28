# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Comparoya.Repo.insert!(%Comparoya.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Comparoya.Accounts

# Create admin user if it doesn't exist
case Accounts.get_user_by_username("admin") do
  nil ->
    {:ok, _} =
      Accounts.register_admin(%{
        "email" => "admin@example.com",
        "name" => "Administrator",
        "username" => "admin",
        "password" => "adminpassword"
      })

    IO.puts("Admin user created")

  _user ->
    IO.puts("Admin user already exists")
end
