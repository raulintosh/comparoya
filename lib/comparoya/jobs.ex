defmodule Comparoya.Jobs do
  @moduledoc """
  The Jobs context.
  """

  import Ecto.Query, warn: false
  alias Comparoya.Repo
  alias Comparoya.Jobs.JobConfiguration

  @doc """
  Returns the list of job_configurations.

  ## Examples

      iex> list_job_configurations()
      [%JobConfiguration{}, ...]

  """
  def list_job_configurations do
    Repo.all(JobConfiguration)
  end

  @doc """
  Returns the list of job_configurations for a specific user.

  ## Examples

      iex> list_job_configurations_for_user(user_id)
      [%JobConfiguration{}, ...]

  """
  def list_job_configurations_for_user(user_id) do
    JobConfiguration
    |> where([j], j.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Gets a single job_configuration.

  Raises `Ecto.NoResultsError` if the Job configuration does not exist.

  ## Examples

      iex> get_job_configuration!(123)
      %JobConfiguration{}

      iex> get_job_configuration!(456)
      ** (Ecto.NoResultsError)

  """
  def get_job_configuration!(id), do: Repo.get!(JobConfiguration, id)

  @doc """
  Gets a single job_configuration for a specific user.

  Returns nil if the Job configuration does not exist.

  ## Examples

      iex> get_job_configuration_for_user(123, user_id)
      %JobConfiguration{}

      iex> get_job_configuration_for_user(456, user_id)
      nil

  """
  def get_job_configuration_for_user(id, user_id) do
    JobConfiguration
    |> where([j], j.id == ^id and j.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Creates a job_configuration.

  ## Examples

      iex> create_job_configuration(%{field: value})
      {:ok, %JobConfiguration{}}

      iex> create_job_configuration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_job_configuration(attrs \\ %{}) do
    %JobConfiguration{}
    |> JobConfiguration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a job_configuration.

  ## Examples

      iex> update_job_configuration(job_configuration, %{field: new_value})
      {:ok, %JobConfiguration{}}

      iex> update_job_configuration(job_configuration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_job_configuration(%JobConfiguration{} = job_configuration, attrs) do
    job_configuration
    |> JobConfiguration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a job_configuration.

  ## Examples

      iex> delete_job_configuration(job_configuration)
      {:ok, %JobConfiguration{}}

      iex> delete_job_configuration(job_configuration)
      {:error, %Ecto.Changeset{}}

  """
  def delete_job_configuration(%JobConfiguration{} = job_configuration) do
    Repo.delete(job_configuration)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking job_configuration changes.

  ## Examples

      iex> change_job_configuration(job_configuration)
      %Ecto.Changeset{data: %JobConfiguration{}}

  """
  def change_job_configuration(%JobConfiguration{} = job_configuration, attrs \\ %{}) do
    JobConfiguration.changeset(job_configuration, attrs)
  end

  @doc """
  Updates the last_run_at timestamp for a job configuration.

  ## Examples

      iex> update_last_run_at(job_configuration_id)
      {:ok, %JobConfiguration{}}

  """
  def update_last_run_at(job_configuration_id) do
    JobConfiguration.update_last_run_at(job_configuration_id)
  end

  @doc """
  Gets all enabled job configurations.

  ## Examples

      iex> get_enabled_configurations()
      [%JobConfiguration{}, ...]

  """
  def get_enabled_configurations do
    JobConfiguration.get_enabled_configurations()
  end

  @doc """
  Gets all enabled job configurations for a specific job type.

  ## Examples

      iex> get_enabled_configurations_by_type("gmail_xml_attachment")
      [%JobConfiguration{}, ...]

  """
  def get_enabled_configurations_by_type(job_type) do
    JobConfiguration.get_enabled_configurations_by_type(job_type)
  end

  @doc """
  Gets all enabled job configurations for a specific user.

  ## Examples

      iex> get_enabled_configurations_for_user(user_id)
      [%JobConfiguration{}, ...]

  """
  def get_enabled_configurations_for_user(user_id) do
    JobConfiguration.get_enabled_configurations_for_user(user_id)
  end
end
