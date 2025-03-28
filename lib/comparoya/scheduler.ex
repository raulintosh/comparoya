defmodule Comparoya.Scheduler do
  @moduledoc """
  Scheduler for running jobs at configurable intervals.
  Uses Quantum for scheduling.
  """
  use Quantum, otp_app: :comparoya

  @doc """
  Clears all jobs from the scheduler.
  """
  def clear do
    jobs()
    |> Enum.each(fn {name, _job} -> delete_job(name) end)
  end
end
