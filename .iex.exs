# Import all modules for easier access in IEx

# Main modules
alias Comparoya
alias ComparoyaWeb

# Accounts
alias Comparoya.Accounts
alias Comparoya.Accounts.User

# Application
alias Comparoya.Application

# Invoices
alias Comparoya.Invoices
alias Comparoya.Invoices.BusinessEntity
alias Comparoya.Invoices.Invoice
alias Comparoya.Invoices.InvoiceItem
alias Comparoya.Invoices.InvoiceMetadata
alias Comparoya.Invoices.ProductReference
alias Comparoya.Invoices.UnitOfMeasurement

# Jobs
alias Comparoya.Jobs
alias Comparoya.Jobs.JobConfiguration
alias Comparoya.Jobs.SchedulerManager

# Gmail
alias Comparoya.Gmail.Api
alias Comparoya.Gmail.InvoiceProcessor
alias Comparoya.Gmail.XmlAttachmentProcessor

# Workers
alias Comparoya.Workers.GmailXmlAttachmentWorker

# Web
alias ComparoyaWeb.Endpoint
alias ComparoyaWeb.Router
alias ComparoyaWeb.Telemetry
alias ComparoyaWeb.Gettext

# Web Components
alias ComparoyaWeb.CoreComponents
alias ComparoyaWeb.Layouts

# Web Controllers
alias ComparoyaWeb.AdminAuthController
alias ComparoyaWeb.AdminAuthHTML
alias ComparoyaWeb.AuthController
alias ComparoyaWeb.DashboardController
alias ComparoyaWeb.DashboardHTML
alias ComparoyaWeb.ErrorHTML
alias ComparoyaWeb.ErrorJSON
alias ComparoyaWeb.JobConfigurationController
alias ComparoyaWeb.JobConfigurationHTML
alias ComparoyaWeb.PageController
alias ComparoyaWeb.PageHTML

# Web Plugs
alias ComparoyaWeb.Plugs.AdminAuth
alias ComparoyaWeb.Plugs.AuthOrAdmin
alias ComparoyaWeb.Plugs.Auth

# Other important modules
alias Comparoya.Mailer
alias Comparoya.Release
alias Comparoya.Repo
alias Comparoya.Scheduler

# Import Ecto query functions
import Ecto.Query

# Import Phoenix controller functions
import Phoenix.Controller

IO.puts(IO.ANSI.green() <> "Comparoya IEx configuration loaded!" <> IO.ANSI.reset())
IO.puts("All main modules have been aliased for easier access.")
