defmodule Comparoya.Jobs.JobConfiguration do
  @moduledoc """
  Schema for job configurations.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Comparoya.Accounts.User
  alias Comparoya.Repo

  schema "job_configurations" do
    field :name, :string
    field :description, :string
    field :job_type, :string
    field :interval_minutes, :integer
    field :enabled, :boolean, default: true
    field :last_run_at, :utc_datetime
    field :config, :map, default: %{}

    belongs_to :user, User

    timestamps()
  end

  @doc """
  Creates a changeset for a job configuration.
  """
  def changeset(job_configuration, attrs) do
    job_configuration
    |> cast(attrs, [
      :name,
      :description,
      :job_type,
      :interval_minutes,
      :enabled,
      :last_run_at,
      :config,
      :user_id
    ])
    |> validate_required([:name, :job_type, :interval_minutes, :user_id])
    |> validate_number(:interval_minutes, greater_than: 0)
    |> unique_constraint([:name, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Gets all enabled job configurations.
  """
  def get_enabled_configurations do
    __MODULE__
    |> where([j], j.enabled == true)
    |> Repo.all()
  end

  @doc """
  Gets all enabled job configurations for a specific job type.
  """
  def get_enabled_configurations_by_type(job_type) do
    __MODULE__
    |> where([j], j.enabled == true and j.job_type == ^job_type)
    |> Repo.all()
  end

  @doc """
  Gets all enabled job configurations for a specific user.
  """
  def get_enabled_configurations_for_user(user_id) do
    __MODULE__
    |> where([j], j.enabled == true and j.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Updates the last_run_at timestamp for a job configuration.
  """
  def update_last_run_at(id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    __MODULE__
    |> Repo.get(id)
    |> changeset(%{last_run_at: now})
    |> Repo.update()
  end
end
