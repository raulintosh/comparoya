defmodule ComparoyaWeb.JobConfigurationController do
  use ComparoyaWeb, :controller

  import ComparoyaWeb.Plugs.AdminAuth

  alias Comparoya.Jobs
  alias Comparoya.Jobs.JobConfiguration
  alias Comparoya.Jobs.SchedulerManager

  plug :require_admin

  def index(conn, _params) do
    job_configurations =
      cond do
        # Admin users can see all job configurations
        conn.assigns[:current_admin] ->
          Jobs.list_job_configurations()

        # Regular users can only see their own job configurations
        conn.assigns[:current_user] ->
          Jobs.list_job_configurations_for_user(conn.assigns.current_user.id)

        # Fallback (should not happen due to plug)
        true ->
          []
      end

    render(conn, :index,
      job_configurations: job_configurations,
      current_admin: conn.assigns[:current_admin]
    )
  end

  def new(conn, _params) do
    changeset = Jobs.change_job_configuration(%JobConfiguration{})

    # If admin, fetch all users for the dropdown
    users = if conn.assigns[:current_admin], do: Comparoya.Accounts.list_users(), else: []

    render(conn, :new,
      changeset: changeset,
      current_admin: conn.assigns[:current_admin],
      users: users
    )
  end

  def create(conn, %{"job_configuration" => job_configuration_params}) do
    # Add the user_id to the params
    job_configuration_params =
      cond do
        # Admin users can create job configurations for any user
        conn.assigns[:current_admin] ->
          # If user_id is already provided, use it, otherwise use admin's ID
          if Map.has_key?(job_configuration_params, "user_id") do
            job_configuration_params
          else
            Map.put(job_configuration_params, "user_id", conn.assigns.current_admin.id)
          end

        # Regular users can only create job configurations for themselves
        conn.assigns[:current_user] ->
          Map.put(job_configuration_params, "user_id", conn.assigns.current_user.id)

        # Fallback (should not happen due to plug)
        true ->
          job_configuration_params
      end

    case Jobs.create_job_configuration(job_configuration_params) do
      {:ok, job_configuration} ->
        # Schedule the job if it's enabled
        if job_configuration.enabled do
          SchedulerManager.schedule_job(job_configuration)
        end

        conn
        |> put_flash(:info, "Job configuration created successfully.")
        |> redirect(to: ~p"/admin/job_configurations")

      {:error, %Ecto.Changeset{} = changeset} ->
        # If admin, fetch all users for the dropdown
        users = if conn.assigns[:current_admin], do: Comparoya.Accounts.list_users(), else: []

        render(conn, :new,
          changeset: changeset,
          current_admin: conn.assigns[:current_admin],
          users: users
        )
    end
  end

  def show(conn, %{"id" => id}) do
    job_configuration = get_job_configuration(conn, id)

    if job_configuration do
      render(conn, :show,
        job_configuration: job_configuration,
        current_admin: conn.assigns[:current_admin]
      )
    else
      conn
      |> put_flash(:error, "Job configuration not found.")
      |> redirect(to: ~p"/admin/job_configurations")
    end
  end

  def edit(conn, %{"id" => id}) do
    job_configuration = get_job_configuration(conn, id)

    if job_configuration do
      changeset = Jobs.change_job_configuration(job_configuration)

      # If admin, fetch all users for the dropdown
      users = if conn.assigns[:current_admin], do: Comparoya.Accounts.list_users(), else: []

      render(conn, :edit,
        job_configuration: job_configuration,
        changeset: changeset,
        current_admin: conn.assigns[:current_admin],
        users: users
      )
    else
      conn
      |> put_flash(:error, "Job configuration not found.")
      |> redirect(to: ~p"/admin/job_configurations")
    end
  end

  def update(conn, %{"id" => id, "job_configuration" => job_configuration_params}) do
    job_configuration = get_job_configuration(conn, id)

    if job_configuration do
      case Jobs.update_job_configuration(job_configuration, job_configuration_params) do
        {:ok, job_configuration} ->
          # Reschedule the job
          SchedulerManager.reschedule_job(job_configuration)

          conn
          |> put_flash(:info, "Job configuration updated successfully.")
          |> redirect(to: ~p"/admin/job_configurations/#{job_configuration}")

        {:error, %Ecto.Changeset{} = changeset} ->
          # If admin, fetch all users for the dropdown
          users = if conn.assigns[:current_admin], do: Comparoya.Accounts.list_users(), else: []

          render(conn, :edit,
            job_configuration: job_configuration,
            changeset: changeset,
            current_admin: conn.assigns[:current_admin],
            users: users
          )
      end
    else
      conn
      |> put_flash(:error, "Job configuration not found.")
      |> redirect(to: ~p"/admin/job_configurations")
    end
  end

  def delete(conn, %{"id" => id}) do
    job_configuration = get_job_configuration(conn, id)

    if job_configuration do
      # Unschedule the job
      SchedulerManager.unschedule_job(job_configuration.name)

      # Delete the job configuration
      {:ok, _job_configuration} = Jobs.delete_job_configuration(job_configuration)

      conn
      |> put_flash(:info, "Job configuration deleted successfully.")
      |> redirect(to: ~p"/admin/job_configurations")
    else
      conn
      |> put_flash(:error, "Job configuration not found.")
      |> redirect(to: ~p"/admin/job_configurations")
    end
  end

  def run_now(conn, %{"id" => id}) do
    job_configuration = get_job_configuration(conn, id)

    if job_configuration do
      # Run the job immediately
      SchedulerManager.run_gmail_xml_attachment_job(job_configuration.id)

      conn
      |> put_flash(:info, "Job started successfully.")
      |> redirect(to: ~p"/admin/job_configurations/#{job_configuration}")
    else
      conn
      |> put_flash(:error, "Job configuration not found.")
      |> redirect(to: ~p"/admin/job_configurations")
    end
  end

  # Helper function to get job configuration based on user role
  defp get_job_configuration(conn, id) do
    cond do
      # Admin users can access any job configuration
      conn.assigns[:current_admin] ->
        Jobs.get_job_configuration!(id)

      # Regular users can only access their own job configurations
      conn.assigns[:current_user] ->
        Jobs.get_job_configuration_for_user(id, conn.assigns.current_user.id)

      # Fallback (should not happen due to plug)
      true ->
        nil
    end
  rescue
    # Handle case where job configuration doesn't exist
    Ecto.NoResultsError -> nil
  end
end
