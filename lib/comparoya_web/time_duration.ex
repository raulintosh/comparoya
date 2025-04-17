defmodule ComparoyaWeb.TimeDuration do
  @moduledoc """
  Utility module for formatting time durations in a human-readable way.
  """

  @doc """
  Formats a date into a human-readable time duration string (e.g., "2 days ago").

  ## Examples

      iex> TimeDuration.get_time_duration(~D[2023-01-01], ~D[2023-01-03])
      "2 days ago"

      iex> TimeDuration.get_time_duration(~D[2023-01-01], ~D[2023-01-02])
      "1 day ago"

      iex> TimeDuration.get_time_duration(~D[2023-01-01], ~D[2023-01-08])
      "1 week ago"

  """
  def get_time_duration(date, current_date \\ Date.utc_today()) do
    days_diff = Date.diff(current_date, date)

    cond do
      days_diff == 0 -> "hoy"
      days_diff == 1 -> "ayer"
      days_diff < 7 -> "hace #{days_diff} días"
      days_diff < 14 -> "hace 1 semana"
      days_diff < 30 -> "hace #{div(days_diff, 7)} semanas"
      days_diff < 60 -> "hace 1 mes"
      days_diff < 365 -> "hace #{div(days_diff, 30)} meses"
      days_diff < 730 -> "hace 1 año"
      true -> "hace #{div(days_diff, 365)} años"
    end
  end
end
