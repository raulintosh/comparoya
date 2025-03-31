# This script updates the first user to have a Google provider
# Run it with: mix run update_user_provider.exs

# Get the first user
user = Comparoya.Accounts.list_users() |> List.first()

if user do
  IO.puts("Updating user: #{user.email}")

  # Update the user to have a Google provider
  attrs = %{
    provider: "google",
    provider_id: "123456789",
    provider_token: "dummy_token",
    refresh_token: "dummy_refresh_token"
  }

  case Comparoya.Accounts.update_user(user, attrs) do
    {:ok, updated_user} ->
      IO.puts("User updated successfully")
      IO.inspect(updated_user, label: "Updated user")

    {:error, changeset} ->
      IO.puts("Error updating user")
      IO.inspect(changeset.errors, label: "Errors")
  end
else
  IO.puts("No users found. Please create a user first.")
end
