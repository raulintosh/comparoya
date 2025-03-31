# This script enqueues a job for the GmailXmlAttachmentWorker
# Run it with: mix run test_gmail_worker.exs

# Get the first user
user = Comparoya.Accounts.list_users() |> List.first()

if user do
  IO.puts("Enqueuing job for user: #{user.email}")

  # Enqueue the job
  %{user_id: user.id}
  |> Comparoya.Workers.GmailXmlAttachmentWorker.new()
  |> Oban.insert()
  |> case do
    {:ok, job} -> IO.puts("Job enqueued with ID: #{job.id}")
    {:error, error} -> IO.puts("Error enqueueing job: #{inspect(error)}")
  end
else
  IO.puts("No users found. Please create a user first.")
end
