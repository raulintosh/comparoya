# Comparoya Security Implementation Guide

This document provides specific implementation recommendations to address the security issues identified in the security analysis. It includes code examples, configuration changes, and best practices for enhancing the security of the Comparoya application.

## 1. XML Validation and Sanitization

### 1.1 Implement XML Schema Validation

Create a module to validate XML against a schema before processing:

```elixir
defmodule Comparoya.Gmail.XmlValidator do
  @moduledoc """
  Module for validating XML files against schemas.
  """

  require Logger

  @doc """
  Validates XML data against a schema.
  Returns {:ok, xml_data} if valid, {:error, reason} if invalid.
  """
  def validate(xml_data, schema_type \\ :invoice) do
    try do
      # First, check for XML well-formedness
      case :erlsom.simple_form(xml_data) do
        {:ok, _, _} ->
          # XML is well-formed, now validate against schema
          schema_path = get_schema_path(schema_type)
          case :erlsom.compile_xsd_file(schema_path) do
            {:ok, schema} ->
              case :erlsom.validate(xml_data, schema) do
                {:ok, _} ->
                  {:ok, xml_data}
                {:error, reason} ->
                  Logger.error("XML validation error: #{inspect(reason)}")
                  {:error, "XML validation failed: #{inspect(reason)}"}
              end
            {:error, reason} ->
              Logger.error("Schema compilation error: #{inspect(reason)}")
              {:error, "Schema compilation failed"}
          end
        {:error, reason} ->
          Logger.error("XML parsing error: #{inspect(reason)}")
          {:error, "XML is not well-formed: #{inspect(reason)}"}
      end
    rescue
      e ->
        Logger.error("XML validation error: #{inspect(e)}")
        {:error, "XML validation failed: #{inspect(e)}"}
    end
  end

  defp get_schema_path(:invoice) do
    Path.join(:code.priv_dir(:comparoya), "schemas/invoice.xsd")
  end
end
```

### 1.2 Disable DTD Processing in XML Parser

Modify the XML parsing in `xml_attachment_processor.ex` to disable DTD processing:

```elixir
defp parse_xml(xml_data) do
  try do
    # First validate the XML
    case Comparoya.Gmail.XmlValidator.validate(xml_data) do
      {:ok, _} ->
        # Parse the XML with DTD disabled
        parsed_xml =
          xml_data
          |> parse(dtd: :none, quiet: false)
          
        # Rest of the parsing logic...
        
      {:error, reason} ->
        Logger.error("XML validation failed: #{reason}")
        raise "Invalid XML: #{reason}"
    end
  rescue
    e ->
      Logger.error("Error parsing XML: #{inspect(e)}")
      reraise e, __STACKTRACE__
  end
end
```

### 1.3 Add XML Sanitization

Add a function to sanitize XML before processing:

```elixir
defp sanitize_xml(xml_data) do
  # Remove potentially dangerous elements and attributes
  xml_data
  |> String.replace(~r/<!\[CDATA\[.*?\]\]>/s, "")  # Remove CDATA sections
  |> String.replace(~r/<!DOCTYPE.*?>/s, "")       # Remove DOCTYPE declarations
  |> String.replace(~r/<!--.*?-->/s, "")          # Remove comments
  |> String.replace(~r/<\?xml-stylesheet.*?\?>/s, "") # Remove xml-stylesheet
end
```

## 2. Authentication Security Enhancements

### 2.1 Encrypt OAuth Tokens

Add encryption for OAuth tokens in the User schema:

```elixir
defmodule Comparoya.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Comparoya.Encryption

  schema "users" do
    # Existing fields...
    field :provider_token, :string
    field :refresh_token, :string
    field :encrypted_provider_token, :binary
    field :encrypted_refresh_token, :binary
    
    # Virtual fields for decrypted values
    field :decrypted_provider_token, :string, virtual: true
    field :decrypted_refresh_token, :string, virtual: true
    
    # Rest of the schema...
  end

  # Modify changeset to encrypt tokens
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :name,
      :avatar,
      :provider,
      :provider_id,
      :provider_token,
      :refresh_token,
      :is_admin
    ])
    |> validate_required([:email, :provider, :provider_id])
    |> unique_constraint(:email)
    |> unique_constraint([:provider, :provider_id])
    |> encrypt_tokens()
  end
  
  defp encrypt_tokens(changeset) do
    case get_change(changeset, :provider_token) do
      nil -> changeset
      token -> 
        put_change(changeset, :encrypted_provider_token, Encryption.encrypt(token))
    end
    |> maybe_encrypt_refresh_token()
  end
  
  defp maybe_encrypt_refresh_token(changeset) do
    case get_change(changeset, :refresh_token) do
      nil -> changeset
      token -> 
        put_change(changeset, :encrypted_refresh_token, Encryption.encrypt(token))
    end
  end
end
```

Create an encryption module:

```elixir
defmodule Comparoya.Encryption do
  @moduledoc """
  Module for encrypting and decrypting sensitive data.
  """
  
  @key_length 32 # AES-256
  @iv_length 16  # AES block size
  
  @doc """
  Encrypts data using AES-256-GCM.
  """
  def encrypt(data) when is_binary(data) do
    # Get the encryption key
    key = get_encryption_key()
    
    # Generate a random IV
    iv = :crypto.strong_rand_bytes(@iv_length)
    
    # Encrypt the data
    {ciphertext, tag} = :crypto.crypto_one_time_aead(
      :aes_256_gcm,
      key,
      iv,
      data,
      "",  # Additional authenticated data (AAD)
      true # Encrypt mode
    )
    
    # Combine IV, ciphertext, and authentication tag
    iv <> tag <> ciphertext
  end
  
  @doc """
  Decrypts data encrypted with encrypt/1.
  """
  def decrypt(encrypted_data) when is_binary(encrypted_data) do
    # Get the encryption key
    key = get_encryption_key()
    
    # Extract IV, tag, and ciphertext
    <<iv::binary-size(@iv_length), tag::binary-size(16), ciphertext::binary>> = encrypted_data
    
    # Decrypt the data
    :crypto.crypto_one_time_aead(
      :aes_256_gcm,
      key,
      iv,
      ciphertext,
      "",  # Additional authenticated data (AAD)
      tag,
      false # Decrypt mode
    )
  end
  
  # Get the encryption key from environment or config
  defp get_encryption_key do
    Application.get_env(:comparoya, :encryption_key) ||
      System.get_env("ENCRYPTION_KEY") ||
      raise "Encryption key not configured"
  end
end
```

Add a migration to update the users table:

```elixir
defmodule Comparoya.Repo.Migrations.AddEncryptedTokensToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :encrypted_provider_token, :binary
      add :encrypted_refresh_token, :binary
    end
  end
end
```

### 2.2 Implement Account Lockout

Add account lockout functionality to the User schema:

```elixir
defmodule Comparoya.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    # Existing fields...
    field :failed_login_attempts, :integer, default: 0
    field :locked_at, :utc_datetime
    
    # Rest of the schema...
  end
  
  # Add a function to check if account is locked
  def locked?(%__MODULE__{locked_at: locked_at}) when not is_nil(locked_at) do
    # Check if the lockout period has expired (e.g., 30 minutes)
    lockout_duration = 30 * 60 # 30 minutes in seconds
    locked_until = DateTime.add(locked_at, lockout_duration, :second)
    DateTime.compare(locked_until, DateTime.utc_now()) == :gt
  end
  
  def locked?(_), do: false
  
  # Add a function to increment failed login attempts
  def increment_failed_attempts(user) do
    # Max attempts before lockout
    max_attempts = 5
    
    new_attempts = (user.failed_login_attempts || 0) + 1
    changes = %{failed_login_attempts: new_attempts}
    
    # Lock the account if max attempts reached
    changes = if new_attempts >= max_attempts do
      Map.put(changes, :locked_at, DateTime.utc_now())
    else
      changes
    end
    
    Ecto.Changeset.change(user, changes)
  end
  
  # Add a function to reset failed login attempts
  def reset_failed_attempts(user) do
    Ecto.Changeset.change(user, %{
      failed_login_attempts: 0,
      locked_at: nil
    })
  end
end
```

Modify the authentication function in `accounts.ex`:

```elixir
def authenticate_user(username, password) do
  user = get_user_by_username(username)

  cond do
    user && Accounts.User.locked?(user) ->
      {:error, :account_locked}
      
    user && Bcrypt.verify_pass(password, user.password_hash) ->
      # Reset failed attempts on successful login
      {:ok, user} = user
        |> Accounts.User.reset_failed_attempts()
        |> Repo.update()
      
      {:ok, user}

    user ->
      # Increment failed attempts
      {:ok, _updated_user} = user
        |> Accounts.User.increment_failed_attempts()
        |> Repo.update()
        
      {:error, :invalid_password}

    true ->
      # Prevent timing attacks by simulating password check
      Bcrypt.no_user_verify()
      {:error, :invalid_username}
  end
end
```

Update the admin login controller to handle account lockouts:

```elixir
def login(conn, %{"user" => %{"username" => username, "password" => password}}) do
  case Accounts.authenticate_user(username, password) do
    {:ok, user} ->
      if Accounts.is_admin?(user) do
        conn
        |> put_session(:admin_user_id, user.id)
        |> configure_session(renew: true)
        |> put_flash(:info, "Welcome back, #{user.name || user.username}!")
        |> redirect(to: ~p"/dashboard")
      else
        conn
        |> put_flash(:error, "You do not have admin privileges.")
        |> render(:login_form, error_message: "You do not have admin privileges.")
      end

    {:error, :account_locked} ->
      conn
      |> put_flash(:error, "Account locked due to too many failed attempts. Please try again later.")
      |> render(:login_form, error_message: "Account locked due to too many failed attempts. Please try again later.")

    {:error, :invalid_username} ->
      conn
      |> put_flash(:error, "Invalid username or password")
      |> render(:login_form, error_message: "Invalid username or password")

    {:error, :invalid_password} ->
      conn
      |> put_flash(:error, "Invalid username or password")
      |> render(:login_form, error_message: "Invalid username or password")
  end
end
```

## 3. Security Logging and Monitoring

### 3.1 Implement Security Logging

Create a security logger module:

```elixir
defmodule Comparoya.SecurityLogger do
  @moduledoc """
  Module for logging security-related events.
  """
  
  require Logger
  
  @doc """
  Logs a security event.
  """
  def log_security_event(event_type, details, metadata \\ %{}) do
    # Create a structured log entry
    log_entry = %{
      timestamp: DateTime.utc_now(),
      event_type: event_type,
      details: details,
      metadata: metadata
    }
    
    # Log to the security log
    Logger.info("SECURITY_EVENT: #{Jason.encode!(log_entry)}", security: true)
    
    # Return the log entry
    log_entry
  end
  
  @doc """
  Logs an authentication event.
  """
  def log_authentication(result, user_identifier, metadata \\ %{}) do
    event_type = case result do
      :success -> "authentication_success"
      :failure -> "authentication_failure"
      :lockout -> "authentication_lockout"
      _ -> "authentication_#{result}"
    end
    
    details = "Authentication #{result} for user #{user_identifier}"
    
    log_security_event(event_type, details, metadata)
  end
  
  @doc """
  Logs an access control event.
  """
  def log_access_control(result, resource, user_identifier, metadata \\ %{}) do
    event_type = case result do
      :granted -> "access_granted"
      :denied -> "access_denied"
      _ -> "access_#{result}"
    end
    
    details = "Access #{result} to #{resource} for user #{user_identifier}"
    
    log_security_event(event_type, details, metadata)
  end
  
  @doc """
  Logs a data access event.
  """
  def log_data_access(operation, resource, user_identifier, metadata \\ %{}) do
    event_type = "data_#{operation}"
    
    details = "Data #{operation} on #{resource} by user #{user_identifier}"
    
    log_security_event(event_type, details, metadata)
  end
end
```

Configure Logger to handle security logs in `config/config.exs`:

```elixir
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :security]

# Add a security log backend
config :logger,
  backends: [:console, {LoggerFileBackend, :security_log}]

# Configure the security log backend
config :logger, :security_log,
  path: "log/security.log",
  level: :info,
  metadata_filter: [security: true]
```

### 3.2 Add Security Logging to Authentication

Update the authentication functions to log security events:

```elixir
def authenticate_user(username, password) do
  user = get_user_by_username(username)

  cond do
    user && Accounts.User.locked?(user) ->
      Comparoya.SecurityLogger.log_authentication(:lockout, username, %{
        user_id: user.id,
        source_ip: get_client_ip()
      })
      {:error, :account_locked}
      
    user && Bcrypt.verify_pass(password, user.password_hash) ->
      # Reset failed attempts on successful login
      {:ok, user} = user
        |> Accounts.User.reset_failed_attempts()
        |> Repo.update()
      
      Comparoya.SecurityLogger.log_authentication(:success, username, %{
        user_id: user.id,
        source_ip: get_client_ip()
      })
      
      {:ok, user}

    user ->
      # Increment failed attempts
      {:ok, updated_user} = user
        |> Accounts.User.increment_failed_attempts()
        |> Repo.update()
        
      Comparoya.SecurityLogger.log_authentication(:failure, username, %{
        user_id: user.id,
        reason: "invalid_password",
        failed_attempts: updated_user.failed_login_attempts,
        source_ip: get_client_ip()
      })
      
      {:error, :invalid_password}

    true ->
      # Prevent timing attacks by simulating password check
      Bcrypt.no_user_verify()
      
      Comparoya.SecurityLogger.log_authentication(:failure, username, %{
        reason: "invalid_username",
        source_ip: get_client_ip()
      })
      
      {:error, :invalid_username}
  end
end

# Helper function to get client IP from connection
defp get_client_ip do
  case Process.get(:current_remote_ip) do
    nil -> "unknown"
    ip -> ip
  end
end
```

Add a plug to capture the client IP:

```elixir
defmodule ComparoyaWeb.Plugs.CaptureClientIP do
  @moduledoc """
  Plug to capture the client IP address.
  """
  
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    # Get the client IP from the connection
    client_ip = conn.remote_ip
      |> Tuple.to_list()
      |> Enum.join(".")
    
    # Store it in the process dictionary for logging
    Process.put(:current_remote_ip, client_ip)
    
    conn
  end
end
```

Add the plug to the router:

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {ComparoyaWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug ComparoyaWeb.Plugs.CaptureClientIP
  plug :fetch_current_user
  plug :fetch_current_admin
end
```

## 4. Secure Configuration Management

### 4.1 Use Environment Variables for Sensitive Configuration

Update `config/runtime.exs` to use environment variables for all sensitive configuration:

```elixir
# Database configuration
config :comparoya, Comparoya.Repo,
  url: System.get_env("DATABASE_URL"),
  ssl: true,
  ssl_opts: [
    verify: :verify_peer,
    cacerts: [
      System.get_env("DATABASE_CA_CERT")
      |> then(fn pem ->
        [{_type, der, _info}] = :public_key.pem_decode(pem)
        der
      end)
    ],
    server_name_indication: System.get_env("DATABASE_HOSTNAME") |> to_charlist(),
    customize_hostname_check: [
      match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
    ]
  ],
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# Secret key base
config :comparoya, ComparoyaWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# Google OAuth configuration
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# S3 configuration
config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION")

config :ex_aws, :s3,
  host: System.get_env("S3_HOST"),
  scheme: "https://"

# Encryption key for sensitive data
config :comparoya, :encryption_key, System.get_env("ENCRYPTION_KEY")
```

### 4.2 Add Security Headers

Add security headers to the endpoint configuration in `lib/comparoya_web/endpoint.ex`:

```elixir
plug Plug.SSL,
  rewrite_on: [:x_forwarded_proto],
  hsts: true,
  secure_renegotiate: true,
  reuse_sessions: true,
  honor_cipher_order: true,
  cipher_suite: :strong

plug :put_secure_browser_headers, %{
  "Content-Security-Policy" => "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'",
  "X-Content-Type-Options" => "nosniff",
  "X-Frame-Options" => "SAMEORIGIN",
  "X-XSS-Protection" => "1; mode=block",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=()"
}
```

## 5. Rate Limiting and Protection Against Brute Force Attacks

### 5.1 Implement Rate Limiting

Add a rate limiting plug:

```elixir
defmodule ComparoyaWeb.Plugs.RateLimiter do
  @moduledoc """
  Plug for rate limiting requests.
  """
  
  import Plug.Conn
  
  @default_scale 60_000 # 1 minute in milliseconds
  @default_limit 100    # 100 requests per minute
  
  def init(opts) do
    scale = Keyword.get(opts, :scale, @default_scale)
    limit = Keyword.get(opts, :limit, @default_limit)
    
    %{scale: scale, limit: limit}
  end
  
  def call(conn, %{scale: scale, limit: limit}) do
    client_ip = conn.remote_ip
      |> Tuple.to_list()
      |> Enum.join(".")
    
    case check_rate(client_ip, scale, limit) do
      :ok ->
        conn
      
      :rate_limited ->
        conn
        |> put_resp_header("retry-after", "#{div(scale, 1000)}")
        |> send_resp(429, "Too Many Requests")
        |> halt()
    end
  end
  
  defp check_rate(client_ip, scale, limit) do
    # Use Redis or another distributed store in production
    # This is a simplified example using process dictionary
    now = System.monotonic_time(:millisecond)
    bucket = now - rem(now, scale)
    
    key = "rate_limit:#{client_ip}:#{bucket}"
    
    count = case Process.get(key) do
      nil -> 1
      count -> count + 1
    end
    
    Process.put(key, count)
    
    if count <= limit do
      :ok
    else
      :rate_limited
    end
  end
end
```

Add rate limiting to sensitive routes in the router:

```elixir
pipeline :rate_limit_auth do
  plug ComparoyaWeb.Plugs.RateLimiter, limit: 10, scale: 60_000 # 10 requests per minute
end

scope "/auth", ComparoyaWeb do
  pipe_through [:browser, :rate_limit_auth]

  get "/:provider", AuthController, :request
  get "/:provider/callback", AuthController, :callback
end

scope "/admin", ComparoyaWeb do
  pipe_through [:browser, :rate_limit_auth]

  get "/login", AdminAuthController, :login_form
  post "/login", AdminAuthController, :login
  get "/register", AdminAuthController, :register_form
  post "/register", AdminAuthController, :register
end
```

## 6. Dependency Management and Vulnerability Scanning

### 6.1 Add Mix Audit for Dependency Scanning

Add the `mix_audit` package to `mix.exs`:

```elixir
defp deps do
  [
    # Existing dependencies...
    {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false}
  ]
end
```

Add a CI/CD step to check for vulnerabilities:

```yaml
# In .gitlab-ci.yaml
dependency_scanning:
  stage: test
  script:
    - mix deps.get
    - mix deps.audit
  only:
    - main
    - merge_requests
```

### 6.2 Add Dependency Update Automation

Add a scheduled job to check for outdated dependencies:

```yaml
# In .gitlab-ci.yaml
dependency_updates:
  stage: maintenance
  script:
    - mix deps.get
    - mix hex.outdated
    - mix hex.audit
  only:
    - schedules
  when: always
```

## 7. Docker Security Enhancements

### 7.1 Use Multi-stage Builds

Update the Dockerfile to use multi-stage builds and reduce attack surface:

```dockerfile
# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
ARG ELIXIR_VERSION=1.18.0
ARG OTP_VERSION=27.1.2
ARG DEBIAN_VERSION=bullseye-20241202-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

# Install minimal runtime dependencies
RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_* \
  && useradd -m -s /bin/bash app

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown app:app /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=app:app /app/_build/${MIX_ENV}/rel/comparoya ./

# Use a non-root user
USER app

# Add tini as init process
RUN apt-get update && apt-get install -y tini
ENTRYPOINT ["/usr/bin/tini", "--"]

# Set security-related environment variables
ENV ENCRYPTION_KEY=""
ENV SECRET_KEY_BASE=""

# Set up health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

CMD ["/bin/bash", "-c", "/app/bin/migrate && /app/bin/server"]
```

### 7.2 Add Docker Security Scanning

Add a CI/CD step to scan Docker images for vulnerabilities:

```yaml
# In .gitlab-ci.yaml
container_scanning:
  stage: test
  image: docker:stable
  services:
    - docker:dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  only:
    - main
    - merge_requests
```

## 8. Error Handling and Logging

### 8.1 Implement Custom Error Pages

Create custom error pages in `lib/comparoya_web/controllers/error_html.ex`:

```elixir
defmodule ComparoyaWeb.ErrorHTML do
  use ComparoyaWeb, :html

  # If you want to customize your error pages,
  # uncomment the embed_templates/1 call below
  # and add pages to the error directory:
  #
  #   * lib/comparoya_web/controllers/error_html/404.html.heex
  #   * lib/comparoya_web/controllers/error_html/500.html.heex
  #
  # embed_templates "error_html/*"

  # The default is to render a plain text page based on
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def render(template, _assigns) do
    case template do
      "404.html" -> render_404()
      "500.html" -> render_500()
      _ -> Phoenix.Controller.status_message_from_template(template)
    end
  end
  
  defp render_404 do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Page Not Found</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        body { font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.5; color: #333; max-width: 800px; margin: 0 auto; padding: 2rem; }
        h1 { font-size: 2rem; margin-bottom: 1rem; }
        p { margin-bottom: 1rem; }
        .btn { display: inline-block; background: #4299e1; color: white; padding: 0.5rem 1rem; text-decoration: none; border-radius: 0.25rem; }
      </style>
    </head>
    <body>
      <h1>Page Not Found</h1>
      <p>The page you are looking for does not exist or has been moved.</p>
      <a href="/" class="btn">Go to Home Page</a>
    </body>
    </html>
    """
  end
  
  defp render_500 do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Server Error</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        body { font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.5; color: #333; max-width: 800px; margin: 0 auto; padding: 2rem; }
        h1 { font-size: 2rem; margin-bottom: 1rem; }
        p { margin-bottom: 1rem; }
        .btn { display: inline-block; background: #4299e1; color: white; padding: 0.5rem 1rem; text-decoration: none; border-radius: 0.25rem; }
      </style>
    </head>
    <body>
      <h1>Server Error</h1>
      <p>We're sorry, but something went wrong on our end. Our team has been notified and is working to fix the issue.</p>
      <a href="/" class="btn">Go to Home Page</a>
    </body>
    </html>
    """
  end
end
```

### 8.2 Enhance Error Logging

Add a module for enhanced error logging:

```elixir
defmodule Comparoya.ErrorLogger do
  @moduledoc """
  Module for enhanced error logging.
  """
  
  require Logger
  
  @doc """
  Logs an error with additional context.
  """
  def log_error(error, context \\ %{}) do
    # Create a structured log entry
    log_entry = %{
      timestamp: DateTime.utc_now(),
      error: format_error(error),
      context: context,
      stacktrace: format_stacktrace(Process.info(self(), :current_stacktrace))
    }
    
    # Log the error
    Logger.error("ERROR: #{Jason.encode!(log_entry)}")
    
    # Return the error for further processing
    error
  end
  
  defp format_error(%{__struct__: struct} = error) do
    %{
      type: struct,
      message: Exception.message(error)
    }
  end
  
  defp format_error(error) when is_binary(error) do
    %{
      type: "String",
      message: error
    }
  end
  
  defp format_error(error) do
    %{
      type: "Unknown",
      message: inspect(error)
    }
  end
  
  defp format_stacktrace({:current_stacktrace, stacktrace}) do
    Enum.map(stacktrace, fn {module, function, arity, location} ->
      file = Keyword.get(location, :file, "unknown")
      line = Keyword.get(location, :line, 0)
      
      %{
        module: inspect(module),
        function: "#{function}/#{arity}",
        file: file,
        line: line
      }
    end)
  end
  
  defp format_stacktrace(_), do: []
end
```

## 9. Secure Password Policies

### 9.1 Implement Strong Password Policies

Enhance the User schema to enforce stronger password policies:

```elixir
defmodule Comparoya.Accounts.User do
  # Existing code...
  
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :username, :password, :is_admin])
    |> validate_required([:email, :username, :password])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_length(:password, min: 12, max: 100) # Increased minimum length
    |> validate_password_strength() # New validation
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
    |> put_change(:provider, "local")
    |> put_change(:provider_id, "local")
  end
  
  # Add password strength validation
  defp validate_password_strength(changeset) do
    password = get_change(changeset, :password)
    
    if password && !strong_password?(password) do
      add_error(changeset, :password, "Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character")
    else
      changeset
    end
  end
  
  defp strong_password?(password) do
    # Check for at least one uppercase letter
    has_uppercase = String.match?(password, ~r/[A-Z]/)
    
    # Check for at least one lowercase letter
    has_lowercase = String.match?(password, ~r/[a-z]/)
    
    # Check for at least one number
    has_number = String.match?(password, ~r/[0-9]/)
    
    # Check for at least one special character
    has_special = String.match?(password, ~r/[^A-Za-z0-9]/)
    
    has_uppercase && has_lowercase && has_number && has_special
  end
end
```

## 10. Conclusion

This implementation guide provides concrete steps to address the security vulnerabilities identified in the Comparoya application. By implementing these recommendations, you can significantly enhance the security posture of your application.

Key security improvements include:

1. **XML Validation and Sanitization**: Protecting against XXE and XML injection attacks
2. **Authentication Security**: Encrypting sensitive tokens and implementing account lockout
3. **Security Logging**: Adding comprehensive security event logging
4. **Secure Configuration**: Using environment variables for sensitive configuration
5. **Rate Limiting**: Protecting against brute force attacks
6. **Dependency Management**: Regularly scanning for vulnerabilities
7. **Docker Security**: Enhancing container security
8. **Error Handling**: Implementing secure error pages and logging
9. **Password Policies**: Enforcing strong password requirements

Remember to implement these changes incrementally, starting with the highest priority items. Regular security assessments should be conducted to ensure the continued security of the application.
