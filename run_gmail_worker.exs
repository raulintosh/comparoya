# This script directly runs the GmailXmlAttachmentWorker
# Run it with: mix run run_gmail_worker.exs

# Get the first user
user = Comparoya.Accounts.list_users() |> List.first()

if user do
  IO.puts("Running worker for user: #{user.email}")

  # Create a job struct
  job = %Oban.Job{
    args: %{"user_id" => user.id}
  }

  # Run the worker directly
  case Comparoya.Workers.GmailXmlAttachmentWorker.perform(job) do
    :ok -> IO.puts("Worker completed successfully")
    {:error, error} -> IO.puts("Worker failed: #{inspect(error)}")
  end
else
  IO.puts("No users found. Please create a user first.")
end
