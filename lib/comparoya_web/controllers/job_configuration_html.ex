defmodule ComparoyaWeb.JobConfigurationHTML do
  use ComparoyaWeb, :html

  import ComparoyaWeb.AdminLayout

  embed_templates "job_configuration_html/*"

  @doc """
  Renders a job configuration form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def job_configuration_form(assigns)
end
