defmodule Comparoya.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :avatar, :string
    field :provider, :string
    field :provider_id, :string
    field :provider_token, :string
    field :refresh_token, :string
    field :username, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :is_admin, :boolean, default: false

    timestamps()
  end

  @doc """
  Changeset for OAuth users
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :name,
      :avatar,
      :provider,
      :provider_id,
      :provider_token,
      :refresh_token,
      :is_admin
    ])
    |> validate_required([:email, :provider, :provider_id])
    |> unique_constraint(:email)
    |> unique_constraint([:provider, :provider_id])
  end

  @doc """
  Changeset for admin registration with username/password
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :username, :password, :is_admin])
    |> validate_required([:email, :username, :password])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_length(:password, min: 6, max: 100)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
    |> put_change(:provider, "local")
    |> put_change(:provider_id, "local")
  end

  @doc """
  Changeset for admin login
  """
  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username, :password])
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, password_hash: Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset

  @doc """
  Creates a user from OAuth information
  """
  def from_oauth(auth) do
    params = %{
      email: auth.info.email,
      name: auth.info.name,
      avatar: auth.info.image,
      provider: Atom.to_string(auth.provider),
      provider_id: auth.uid,
      provider_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token
    }

    %__MODULE__{}
    |> changeset(params)
  end
end
