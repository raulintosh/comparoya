defmodule Comparoya.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Comparoya.Repo
  alias Comparoya.Accounts.User
  alias Bcrypt

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

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
  Gets a single user by ID.
  Returns nil if the user does not exist.
  """
  def get_user(id) do
    Repo.get(User, id)
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
  Gets a user by username.
  """
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Registers a new admin user.
  """
  def register_admin(attrs) do
    %User{}
    |> User.registration_changeset(Map.put(attrs, "is_admin", true))
    |> Repo.insert()
  end

  @doc """
  Authenticates a user by username and password.

  Returns `{:ok, user}` if the username and password are valid.
  Returns `{:error, :invalid_credentials}` otherwise.
  """
  def authenticate_user(username, password) do
    user = get_user_by_username(username)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        # Prevent timing attacks by simulating password check
        Bcrypt.no_user_verify()
        {:error, :invalid_username}
    end
  end

  @doc """
  Checks if a user is an admin.
  """
  def is_admin?(%User{is_admin: is_admin}), do: is_admin
  def is_admin?(_), do: false

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
              refresh_token: auth.credentials.refresh_token,
              avatar: auth.info.image || existing_user.avatar
            })
            |> Repo.update()
        end

      existing_user ->
        # Update token and other info
        existing_user
        |> User.changeset(%{
          provider_token: auth.credentials.token,
          refresh_token: auth.credentials.refresh_token,
          name: auth.info.name || existing_user.name,
          avatar: auth.info.image || existing_user.avatar
        })
        |> Repo.update()
    end
  end
end
