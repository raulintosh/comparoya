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
    JobConfiguration
    |> Repo.all()
    |> Repo.preload(:user)
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
    |> Repo.preload(:user)
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
  def get_job_configuration!(id) do
    JobConfiguration
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

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
    |> case do
      nil -> nil
      job_config -> Repo.preload(job_config, :user)
    end
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

  @doc """
  Sets up Gmail invoice processing jobs for a newly registered user.
  Creates two job configurations:
  1. A historical job that runs once to process invoices from the current and previous year
  2. A continuous job that runs every 5 minutes to process new invoices

  ## Parameters

  * `user_id` - The ID of the user to set up jobs for

  ## Returns

  * `{:ok, [historical_job, continuous_job]}` - The created job configurations
  * `{:error, reason}` - If an error occurs

  ## Examples

      iex> setup_gmail_invoice_jobs(user_id)
      {:ok, [%JobConfiguration{}, %JobConfiguration{}]}

  """
  def setup_gmail_invoice_jobs(user_id) do
    # Create the historical job configuration
    historical_attrs = %{
      name: "Historical Invoice Processing",
      description: "Processes invoices from the current and previous year (runs once)",
      job_type: "gmail_xml_attachment",
      # Not actually used for historical jobs
      interval_minutes: 60,
      enabled: true,
      user_id: user_id,
      config: %{
        "job_type" => "historical",
        "max_results" => 100
      }
    }

    # Create the continuous job configuration
    continuous_attrs = %{
      name: "Continuous Invoice Processing",
      description: "Processes new invoices every 5 minutes",
      job_type: "gmail_xml_attachment",
      interval_minutes: 5,
      enabled: true,
      user_id: user_id,
      config: %{
        "job_type" => "continuous",
        "max_results" => 20
      }
    }

    # Create both job configurations
    with {:ok, historical_job} <- create_job_configuration(historical_attrs),
         {:ok, continuous_job} <- create_job_configuration(continuous_attrs) do
      # Return both job configurations
      {:ok, [historical_job, continuous_job]}
    else
      {:error, changeset} ->
        # If there's an error, return it
        {:error, changeset}
    end
  end
end
