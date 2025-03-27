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

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar, :provider, :provider_id, :provider_token])
    |> validate_required([:email, :provider, :provider_id])
    |> unique_constraint(:email)
    |> unique_constraint([:provider, :provider_id])
  end

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
      provider_token: auth.credentials.token
    }

    %__MODULE__{}
    |> changeset(params)
  end
end
