defmodule ComparoyaWeb.AuthController do
  use ComparoyaWeb, :controller
  plug Ueberauth

  alias Comparoya.Accounts

  def request(conn, _params) do
    Phoenix.Controller.redirect(conn, to: Ueberauth.Strategy.Helpers.callback_url(conn))
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.find_or_create_user(auth) do
      {:ok, user} ->
        # Create a job configuration for Gmail XML attachment processing
        create_gmail_xml_job_for_user(user)

        conn
        |> put_flash(:info, "Successfully authenticated.")
        |> put_session(:current_user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: ~p"/dashboard")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: ~p"/")
    end
  end

  # Create a job configuration for Gmail XML attachment processing
  defp create_gmail_xml_job_for_user(user) do
    alias Comparoya.Jobs
    alias Comparoya.Jobs.SchedulerManager

    # Check if the user already has a Gmail XML attachment job
    existing_jobs = Jobs.get_enabled_configurations_by_type("gmail_xml_attachment")
    user_jobs = Enum.filter(existing_jobs, fn job -> job.user_id == user.id end)

    if Enum.empty?(user_jobs) do
      # Create a new job configuration
      job_params = %{
        name: "Gmail XML Invoice Processor",
        description: "Automatically process XML invoices from Gmail attachments",
        job_type: "gmail_xml_attachment",
        interval_minutes: 15,
        enabled: true,
        user_id: user.id,
        config: %{
          query: "has:attachment filename:xml",
          max_results: 10
        }
      }

      case Jobs.create_job_configuration(job_params) do
        {:ok, job_config} ->
          # Schedule the job
          SchedulerManager.schedule_job(job_config)
          {:ok, job_config}

        {:error, _changeset} ->
          {:error, :job_creation_failed}
      end
    else
      # Job already exists
      {:ok, :job_already_exists}
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed.")
    |> redirect(to: ~p"/")
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end
end
