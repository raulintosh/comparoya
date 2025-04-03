# Comparoya Application Flow Diagrams

This document contains flow diagrams for all major operations in the Comparoya application, showing the modules and functions involved in each process.

## 1. User Authentication Flow (OAuth with Google)

```mermaid
flowchart TD
    A[User visits site] --> B[Router]
    B --> C[AuthController.request]
    C --> D[Ueberauth Strategy]
    D --> E[Google OAuth]
    E --> F[AuthController.callback]
    F --> G{User exists?}
    G -- Yes --> H[Update user with new token]
    G -- No --> I[Create new user]
    H --> J[Create Gmail XML job]
    I --> J
    J --> K[Set session]
    K --> L[Redirect to dashboard]
    
    subgraph "ComparoyaWeb.Router"
        B
    end
    
    subgraph "ComparoyaWeb.AuthController"
        C
        F
    end
    
    subgraph "Comparoya.Accounts"
        M[find_or_create_user]
        G
        H
        I
    end
    
    subgraph "Comparoya.Jobs"
        N[create_job_configuration]
        O[SchedulerManager.schedule_job]
        J
    end
    
    F --> M
    M --> G
```

## 2. Admin Authentication Flow

```mermaid
flowchart TD
    A[Admin visits login page] --> B[Router]
    B --> C[AdminAuthController.login_form]
    C --> D[Render login form]
    D --> E[Admin submits credentials]
    E --> F[AdminAuthController.login]
    F --> G[Accounts.authenticate_user]
    G --> H{Valid credentials?}
    H -- No --> I[Error: Invalid credentials]
    I --> D
    H -- Yes --> J{Is admin?}
    J -- No --> K[Error: Not admin]
    K --> D
    J -- Yes --> L[Set admin session]
    L --> M[Redirect to dashboard]
    
    N[Admin visits register page] --> B
    B --> O[AdminAuthController.register_form]
    O --> P[Render register form]
    P --> Q[Admin submits registration]
    Q --> R[AdminAuthController.register]
    R --> S[Accounts.register_admin]
    S --> T{Registration valid?}
    T -- No --> U[Show errors]
    U --> P
    T -- Yes --> V[Set admin session]
    V --> W[Redirect to dashboard]
    
    subgraph "ComparoyaWeb.Router"
        B
    end
    
    subgraph "ComparoyaWeb.AdminAuthController"
        C
        F
        O
        R
    end
    
    subgraph "Comparoya.Accounts"
        G[authenticate_user]
        S[register_admin]
        X[is_admin?]
    end
    
    G --> H
    J --> X
```

## 3. Gmail XML Attachment Processing Flow

```mermaid
flowchart TD
    A[Scheduled job runs] --> B[GmailXmlAttachmentWorker.perform]
    B --> C[Get job configuration]
    C --> D[Get user]
    D --> E[XmlAttachmentProcessor.process_xml_attachments]
    E --> F[Ensure valid token]
    F --> G{Token valid?}
    G -- No --> H[Refresh token]
    H --> I[Update user token]
    I --> J[List Gmail messages]
    G -- Yes --> J
    J --> K[Process messages]
    K --> L[For each message]
    L --> M[Get message details]
    M --> N[Extract XML attachments]
    N --> O[For each attachment]
    O --> P[Get attachment data]
    P --> Q[Decode Base64 data]
    Q --> R[Upload to DigitalOcean Spaces]
    R --> S[Parse XML]
    S --> T[Call callback function]
    T --> U[InvoiceProcessor.save_invoice]
    U --> V[Update last run timestamp]
    
    subgraph "Comparoya.Workers"
        B[GmailXmlAttachmentWorker.perform]
    end
    
    subgraph "Comparoya.Gmail"
        E[XmlAttachmentProcessor.process_xml_attachments]
        F[ensure_valid_token]
        H[refresh_token]
        J[API.list_messages]
        K[process_messages]
        M[API.get_message]
        N[extract_xml_attachments]
        P[API.get_attachment]
        Q[decode_base64]
        R[upload_to_spaces]
        S[parse_xml]
        U[InvoiceProcessor.save_invoice]
    end
    
    subgraph "Comparoya.Jobs"
        C[get_job_configuration]
        V[update_last_run_at]
    end
    
    subgraph "Comparoya.Accounts"
        D[get_user]
        I[update_user]
    end
    
    subgraph "ExAws.S3"
        W[put_object]
    end
    
    R --> W
```

## 4. Invoice Processing Flow

```mermaid
flowchart TD
    A[InvoiceProcessor.save_invoice] --> B{Invoice exists?}
    B -- Yes --> C[Return existing invoice]
    B -- No --> D[Create invoice]
    D --> E[Create business entity]
    E --> F[Create invoice items]
    F --> G[Create invoice metadata]
    G --> H[Return created invoice]
    
    subgraph "Comparoya.Gmail.InvoiceProcessor"
        A[save_invoice]
    end
    
    subgraph "Comparoya.Invoices"
        I[find_invoice_by_number_and_entity_ruc]
        J[create_invoice]
        K[create_business_entity]
        L[create_invoice_items]
        M[create_invoice_metadata]
    end
    
    A --> I
    I --> B
    D --> J
    E --> K
    F --> L
    G --> M
```

## 5. Job Configuration and Scheduling Flow

```mermaid
flowchart TD
    A[User logs in] --> B[Create Gmail XML job]
    B --> C[Jobs.create_job_configuration]
    C --> D[SchedulerManager.schedule_job]
    D --> E[Add job to Quantum scheduler]
    
    F[Admin creates job] --> G[JobConfigurationController.create]
    G --> H[Jobs.create_job_configuration]
    H --> I[SchedulerManager.schedule_job]
    I --> J[Add job to Quantum scheduler]
    
    K[Admin updates job] --> L[JobConfigurationController.update]
    L --> M[Jobs.update_job_configuration]
    M --> N[SchedulerManager.reschedule_job]
    N --> O[Update job in Quantum scheduler]
    
    P[Admin runs job now] --> Q[JobConfigurationController.run_now]
    Q --> R[Jobs.run_job_now]
    R --> S[Create Oban job]
    
    subgraph "ComparoyaWeb.Controllers"
        G[JobConfigurationController.create]
        L[JobConfigurationController.update]
        Q[JobConfigurationController.run_now]
    end
    
    subgraph "Comparoya.Jobs"
        C[create_job_configuration]
        H[create_job_configuration]
        M[update_job_configuration]
        R[run_job_now]
    end
    
    subgraph "Comparoya.Jobs.SchedulerManager"
        D[schedule_job]
        I[schedule_job]
        N[reschedule_job]
    end
    
    subgraph "Quantum"
        E[add job]
        J[add job]
        O[update job]
    end
    
    subgraph "Oban"
        S[insert job]
    end
```

## 6. System Architecture Overview

```mermaid
flowchart TD
    A[User Browser] <--> B[Phoenix Endpoint]
    B <--> C[Router]
    C <--> D[Controllers]
    D <--> E[Plugs]
    D <--> F[Business Logic]
    F <--> G[Database]
    F <--> H[External Services]
    
    I[Scheduled Jobs] --> J[Oban Workers]
    J --> F
    
    subgraph "ComparoyaWeb"
        B[Endpoint]
        C[Router]
        D[Controllers]
        E[Plugs]
    end
    
    subgraph "Comparoya"
        F[Business Logic]
        I[Scheduler]
        J[Workers]
    end
    
    subgraph "External"
        G[PostgreSQL]
        H[Gmail API, DigitalOcean Spaces]
    end
