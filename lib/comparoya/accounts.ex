defmodule Comparoya.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Comparoya.Repo
  alias Comparoya.Accounts.User

  @doc """
  Gets a single user by email.
  Returns nil if the user does not exist.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a single user by provider and provider_id.
  Returns nil if the user does not exist.
  """
  def get_user_by_provider(provider, provider_id) do
    Repo.get_by(User, provider: provider, provider_id: provider_id)
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Finds or creates a user from OAuth information.
  """
  def find_or_create_user(auth) do
    provider = Atom.to_string(auth.provider)

    case get_user_by_provider(provider, auth.uid) do
      nil ->
        # Check if user exists with same email
        case get_user_by_email(auth.info.email) do
          nil ->
            # Create new user
            User.from_oauth(auth)
            |> Repo.insert()

          existing_user ->
            # Update existing user with OAuth info
            existing_user
            |> User.changeset(%{
              provider: provider,
              provider_id: auth.uid,
              provider_token: auth.credentials.token,
              avatar: auth.info.image || existing_user.avatar
            })
            |> Repo.update()
        end

      existing_user ->
        # Update token and other info
        existing_user
        |> User.changeset(%{
          provider_token: auth.credentials.token,
          name: auth.info.name || existing_user.name,
          avatar: auth.info.image || existing_user.avatar
        })
        |> Repo.update()
    end
  end
end
