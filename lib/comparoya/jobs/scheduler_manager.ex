defmodule Comparoya.Jobs.SchedulerManager do
  @moduledoc """
  Manager for scheduling jobs based on configurations in the database.
  """

  require Logger
  alias Comparoya.Jobs
  alias Comparoya.Workers.GmailXmlAttachmentWorker
  alias Comparoya.Scheduler

  @doc """
  Initializes the scheduler with jobs from the database.
  Should be called when the application starts.
  """
  def init do
    Logger.info("Initializing job scheduler")

    # Clear existing jobs
    Scheduler.clear()

    # Schedule jobs from database
    schedule_all_jobs()

    :ok
  end

  @doc """
  Schedules all enabled jobs from the database.
  """
  def schedule_all_jobs do
    Jobs.get_enabled_configurations()
    |> Enum.each(&schedule_job/1)
  end

  @doc """
  Schedules a specific job based on its configuration.
  """
  def schedule_job(job_config) do
    Logger.info("Scheduling job: #{job_config.name} (#{job_config.job_type})")

    case job_config.job_type do
      "gmail_xml_attachment" ->
        schedule_gmail_xml_attachment_job(job_config)

      _ ->
        Logger.warning("Unknown job type: #{job_config.job_type}")
        {:error, :unknown_job_type}
    end
  end

  @doc """
  Unschedules a job by its name.
  """
  def unschedule_job(job_name) do
    Logger.info("Unscheduling job: #{job_name}")
    Scheduler.delete_job(job_name)
    :ok
  end

  @doc """
  Reschedules a job after its configuration has been updated.
  """
  def reschedule_job(job_config) do
    Logger.info("Rescheduling job: #{job_config.name}")

    # First unschedule the job
    unschedule_job(job_config.name)

    # Then schedule it again if it's enabled
    if job_config.enabled do
      schedule_job(job_config)
    else
      Logger.info("Job #{job_config.name} is disabled, not rescheduling")
      :ok
    end
  end

  # Private functions

  defp schedule_gmail_xml_attachment_job(job_config) do
    # Create a unique name for the job
    job_name = "gmail_xml_attachment_#{job_config.id}"

    # Create the job
    job = %{
      name: job_name,
      schedule: create_schedule(job_config.interval_minutes),
      task: {__MODULE__, :run_gmail_xml_attachment_job, [job_config.id]},
      overlap: false
    }

    # Add the job to the scheduler
    Scheduler.add_job(job)

    {:ok, job_name}
  end

  @doc """
  Creates a cron schedule based on the interval in minutes.
  """
  def create_schedule(interval_minutes) when interval_minutes >= 60 do
    # For intervals >= 60 minutes, schedule at specific hours
    hours = div(interval_minutes, 60)

    if rem(24, hours) == 0 do
      # If the hours divide evenly into 24, schedule at specific hours
      hour_list = Enum.map(0..(div(24, hours) - 1), fn i -> i * hours end)
      hour_spec = Enum.join(hour_list, ",")

      # Run at the top of those hours
      "0 #{hour_spec} * * *"
    else
      # Otherwise, run every X hours from midnight
      "0 */#{hours} * * *"
    end
  end

  def create_schedule(interval_minutes) when interval_minutes >= 1 do
    # For intervals < 60 minutes, schedule at specific minutes
    if rem(60, interval_minutes) == 0 do
      # If the minutes divide evenly into 60, schedule at specific minutes
      minute_list = Enum.map(0..(div(60, interval_minutes) - 1), fn i -> i * interval_minutes end)
      minute_spec = Enum.join(minute_list, ",")

      # Run at those minutes of every hour
      "#{minute_spec} * * * *"
    else
      # Otherwise, run every X minutes
      "*/#{interval_minutes} * * * *"
    end
  end

  @doc """
  Runs the Gmail XML attachment job.
  This function is called by the scheduler.
  """
  def run_gmail_xml_attachment_job(job_config_id) do
    Logger.info("Running Gmail XML attachment job for configuration #{job_config_id}")

    # Enqueue an Oban job to process the attachments
    %{job_configuration_id: job_config_id}
    |> GmailXmlAttachmentWorker.new()
    |> Oban.insert()
  end
end
