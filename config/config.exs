# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :comparoya,
  ecto_repos: [Comparoya.Repo]

# Repo configuration
config :comparoya, Comparoya.Repo, []

# Configure Google Maps API
config :comparoya, :google_maps,
  api_key: System.get_env("GOOGLE_MAPS_API_KEY") || "your_api_key_here"

# Configures the endpoint
config :comparoya, ComparoyaWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: ComparoyaWeb.ErrorHTML, json: ComparoyaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Comparoya.PubSub,
  live_view: [signing_salt: "Yx+Yd+Yd"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs` file.
config :comparoya, Comparoya.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  comparoya: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  comparoya: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Ueberauth for authentication
config :ueberauth, Ueberauth,
  providers: [
    google:
      {Ueberauth.Strategy.Google,
       [
         default_scope: "email profile https://www.googleapis.com/auth/gmail.readonly",
         prompt: "consent",
         access_type: "offline"
       ]}
  ]

# Configure Ueberauth Google strategy
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID") || "your_client_id",
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET") || "your_client_secret"

# Configure ExAws for DigitalOcean Spaces
config :ex_aws,
  access_key_id: System.get_env("DO_SPACES_KEY") || "your_key_here",
  secret_access_key: System.get_env("DO_SPACES_SECRET") || "your_secret_key_here",
  region: "sfo3",
  s3: [
    scheme: "https://",
    host: "comparoya.sfo3.digitaloceanspaces.com",
    region: "sfo3",
    normalize_path: true,
    virtual_host: false
  ]

# Configure Oban for job processing
config :comparoya, Oban,
  repo: Comparoya.Repo,
  plugins: [
    # 1 week
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 */3 * * *", Comparoya.Workers.GmailXmlAttachmentWorker}
     ]}
  ],
  queues: [default: 10, gmail: 5, geocoding: 5]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
