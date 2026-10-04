# Design Document: Email Campaign Management Portal

## 1. Introduction

The Email Campaign Management Portal is a production-ready web application built with Next.js 14, TypeScript, and MySQL that enables administrators to create, send, and track email campaigns with comprehensive recipient-level reporting. The system implements a queue-based architecture with a separate background worker for email processing, ensuring scalable and reliable campaign delivery while respecting rate limits and maintaining IMAP synchronization.

## 2. System Architecture Overview

### 2.1 High-Level Architecture

The system follows a three-tier architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                     Browser (Client)                         │
│              React Components + Tailwind CSS                 │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTPS
                      ↓
┌─────────────────────────────────────────────────────────────┐
│                   Next.js Application                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │             App Router (Next.js 14)                   │  │
│  │  - Server Components                                  │  │
│  │  - Server Actions                                     │  │
│  │  - API Routes                                         │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            Business Logic Layer                       │  │
│  │  - Authentication Service                             │  │
│  │  - Campaign Service                                   │  │
│  │  - Contact Service                                    │  │
│  │  - Configuration Service                              │  │
│  │  - Queue Service                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │             Data Access Layer                         │  │
│  │  - Database Client (mysql2)                           │  │
│  │  - Repository Pattern                                 │  │
│  │  - Connection Pooling                                 │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────────────┐
│                   MySQL Database                             │
│  - InnoDB Engine                                             │
│  - Connection Pool                                           │
│  - Foreign Key Constraints                                   │
└─────────────────────────────────────────────────────────────┘
                      ↑
                      │
┌─────────────────────┴───────────────────────────────────────┐
│              Background Worker Process                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Queue Processor (Node.js)                    │  │
│  │  - Continuous Loop                                    │  │
│  │  - Rate Limiter                                       │  │
│  │  - Email Personalizer                                 │  │
│  │  - Retry Logic                                        │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Email Service                                │  │
│  │  - SMTP Client (nodemailer)                           │  │
│  │  - IMAP Client (imap-simple)                          │  │
│  │  - Multipart MIME Builder                             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────┬───────────────┬───────────────────────┘
                      │               │
                      ↓               ↓
            ┌─────────────────┐  ┌─────────────────┐
            │  SMTP Server    │  │  IMAP Server    │
            │  (External)     │  │  (External)     │
            └─────────────────┘  └─────────────────┘
```

### 2.2 Architecture Principles

1. **Separation of Concerns**: Clear boundaries between presentation, business logic, and data access
2. **Asynchronous Processing**: Campaign sending is decoupled from the web interface via queue
3. **Scalability**: Background worker can be scaled independently of the web application
4. **Resilience**: Failed operations are logged and retryable; worker recovers from crashes
5. **Security**: Multi-layered security with authentication, authorization, encryption, and input validation

### 2.3 Component Communication

- **Web App → Database**: Direct SQL queries via connection pool
- **Web App → Background Worker**: Indirect via database queue table
- **Background Worker → Database**: Polls queue table and updates status
- **Background Worker → SMTP/IMAP**: Direct protocol connections for email operations

## 3. Database Schema

### 3.1 Complete Schema Definition

```sql
-- Database: email_campaign_portal
-- Engine: InnoDB for transactional integrity
-- Charset: utf8mb4 for full Unicode support

-- Table 1: administrators
CREATE TABLE administrators (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 2: smtp_configurations
CREATE TABLE smtp_configurations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    host VARCHAR(255) NOT NULL,
    port INT UNSIGNED NOT NULL,
    username VARCHAR(255) NOT NULL,
    password_encrypted TEXT NOT NULL,
    encryption_type ENUM('TLS', 'SSL') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 3: imap_configurations
CREATE TABLE imap_configurations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    host VARCHAR(255) NOT NULL,
    port INT UNSIGNED NOT NULL,
    username VARCHAR(255) NOT NULL,
    password_encrypted TEXT NOT NULL,
    encryption_type ENUM('TLS', 'SSL') NOT NULL,
    sent_folder_name VARCHAR(255) NOT NULL DEFAULT 'Sent',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 4: contacts
CREATE TABLE contacts (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    custom_fields_json JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 5: campaigns
CREATE TABLE campaigns (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    html_body MEDIUMTEXT NOT NULL,
    plain_text_body MEDIUMTEXT NOT NULL,
    status ENUM('draft', 'queued', 'processing', 'completed', 'cancelled') NOT NULL DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 6: campaign_recipients
CREATE TABLE campaign_recipients (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    campaign_id INT UNSIGNED NOT NULL,
    contact_id INT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE,
    FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE,
    UNIQUE KEY unique_campaign_contact (campaign_id, contact_id),
    INDEX idx_campaign_id (campaign_id),
    INDEX idx_contact_id (contact_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 7: email_queue
CREATE TABLE email_queue (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    campaign_id INT UNSIGNED NOT NULL,
    recipient_id INT UNSIGNED NOT NULL,
    delivery_status ENUM('queued', 'sending', 'sent', 'failed') NOT NULL DEFAULT 'queued',
    personalized_subject VARCHAR(255),
    personalized_html_body MEDIUMTEXT,
    personalized_plain_text_body MEDIUMTEXT,
    error_message TEXT,
    retry_count INT UNSIGNED NOT NULL DEFAULT 0,
    queued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE,
    FOREIGN KEY (recipient_id) REFERENCES contacts(id) ON DELETE CASCADE,
    INDEX idx_delivery_status (delivery_status),
    INDEX idx_campaign_id (campaign_id),
    INDEX idx_queued_at (queued_at),
    INDEX idx_sent_at (sent_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 8: sessions
CREATE TABLE sessions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    administrator_id INT UNSIGNED NOT NULL,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (administrator_id) REFERENCES administrators(id) ON DELETE CASCADE,
    INDEX idx_session_token (session_token),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 9: worker_heartbeat (for system health monitoring)
CREATE TABLE worker_heartbeat (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    worker_name VARCHAR(255) NOT NULL UNIQUE,
    last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status ENUM('active', 'stopped') NOT NULL DEFAULT 'active'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 3.2 Entity Relationship Diagram

```
administrators (1) ──< (N) sessions
                          
campaigns (1) ──< (N) campaign_recipients >── (N) contacts
    │                                             │
    │                                             │
    └──< (N) email_queue >────────────────────────┘

smtp_configurations (standalone)
imap_configurations (standalone)
worker_heartbeat (standalone)
```

### 3.3 Database Indexes Justification

1. **contacts.email**: Unique constraint + index for fast lookups during import and campaign creation
2. **email_queue.delivery_status**: Critical for worker queries to find queued items
3. **email_queue.campaign_id**: Fast joins for campaign reporting
4. **campaigns.created_at**: Efficient sorting in dashboard
5. **sessions.session_token**: Fast authentication checks
6. **sessions.expires_at**: Efficient cleanup of expired sessions

## 4. Next.js Project Structure

### 4.1 Directory Structure

```
email-campaign-portal/
├── src/
│   ├── app/                          # Next.js App Router
│   │   ├── (auth)/                   # Auth layout group
│   │   │   ├── login/
│   │   │   │   └── page.tsx          # Login page
│   │   │   └── layout.tsx            # Auth layout (no sidebar)
│   │   ├── (dashboard)/              # Dashboard layout group
│   │   │   ├── campaigns/
│   │   │   │   ├── page.tsx          # Campaign list
│   │   │   │   ├── new/
│   │   │   │   │   └── page.tsx      # Create campaign
│   │   │   │   └── [id]/
│   │   │   │       ├── page.tsx      # Campaign details
│   │   │   │       ├── edit/
│   │   │   │       │   └── page.tsx  # Edit campaign
│   │   │   │       └── recipients/
│   │   │   │           └── page.tsx  # Recipient report
│   │   │   ├── contacts/
│   │   │   │   ├── page.tsx          # Contact list
│   │   │   │   ├── new/
│   │   │   │   │   └── page.tsx      # Add contact
│   │   │   │   ├── import/
│   │   │   │   │   └── page.tsx      # Import contacts
│   │   │   │   └── [id]/
│   │   │   │       └── edit/
│   │   │   │           └── page.tsx  # Edit contact
│   │   │   ├── settings/
│   │   │   │   ├── smtp/
│   │   │   │   │   └── page.tsx      # SMTP config
│   │   │   │   └── imap/
│   │   │   │       └── page.tsx      # IMAP config
│   │   │   ├── dashboard/
│   │   │   │   └── page.tsx          # Main dashboard
│   │   │   └── layout.tsx            # Dashboard layout (with sidebar)
│   │   ├── api/                      # API routes
│   │   │   ├── auth/
│   │   │   │   ├── login/
│   │   │   │   │   └── route.ts      # POST /api/auth/login
│   │   │   │   └── logout/
│   │   │   │       └── route.ts      # POST /api/auth/logout
│   │   │   ├── campaigns/
│   │   │   │   ├── route.ts          # GET, POST /api/campaigns
│   │   │   │   └── [id]/
│   │   │   │       ├── route.ts      # GET, PUT, DELETE /api/campaigns/:id
│   │   │   │       ├── send/
│   │   │   │       │   └── route.ts  # POST /api/campaigns/:id/send
│   │   │   │       ├── preview/
│   │   │   │       │   └── route.ts  # POST /api/campaigns/:id/preview
│   │   │   │       └── recipients/
│   │   │   │           └── route.ts  # GET /api/campaigns/:id/recipients
│   │   │   ├── contacts/
│   │   │   │   ├── route.ts          # GET, POST /api/contacts
│   │   │   │   ├── import/
│   │   │   │   │   └── route.ts      # POST /api/contacts/import
│   │   │   │   └── [id]/
│   │   │   │       └── route.ts      # GET, PUT, DELETE /api/contacts/:id
│   │   │   ├── config/
│   │   │   │   ├── smtp/
│   │   │   │   │   └── route.ts      # GET, POST /api/config/smtp
│   │   │   │   └── imap/
│   │   │   │       └── route.ts      # GET, POST /api/config/imap
│   │   │   ├── queue/
│   │   │   │   └── retry/
│   │   │   │       └── route.ts      # POST /api/queue/retry
│   │   │   └── health/
│   │   │       └── route.ts          # GET /api/health
│   │   ├── layout.tsx                # Root layout
│   │   └── page.tsx                  # Root redirect
│   ├── components/                   # React components
│   │   ├── ui/                       # shadcn/ui components
│   │   │   ├── button.tsx
│   │   │   ├── input.tsx
│   │   │   ├── card.tsx
│   │   │   ├── table.tsx
│   │   │   ├── dialog.tsx
│   │   │   ├── form.tsx
│   │   │   ├── select.tsx
│   │   │   ├── badge.tsx
│   │   │   ├── alert.tsx
│   │   │   └── ...
│   │   ├── campaigns/
│   │   │   ├── CampaignCard.tsx
│   │   │   ├── CampaignForm.tsx
│   │   │   ├── CampaignStats.tsx
│   │   │   ├── RecipientTable.tsx
│   │   │   └── EmailPreview.tsx
│   │   ├── contacts/
│   │   │   ├── ContactTable.tsx
│   │   │   ├── ContactForm.tsx
│   │   │   ├── ImportWizard.tsx
│   │   │   └── ContactFilter.tsx
│   │   ├── layout/
│   │   │   ├── Sidebar.tsx
│   │   │   ├── Header.tsx
│   │   │   └── MainLayout.tsx
│   │   └── shared/
│   │       ├── Pagination.tsx
│   │       ├── SearchBar.tsx
│   │       ├── LoadingSpinner.tsx
│   │       └── ErrorBoundary.tsx
│   ├── lib/                          # Core business logic
│   │   ├── db/
│   │   │   ├── connection.ts         # Database connection pool
│   │   │   ├── repositories/
│   │   │   │   ├── administratorRepository.ts
│   │   │   │   ├── campaignRepository.ts
│   │   │   │   ├── contactRepository.ts
│   │   │   │   ├── queueRepository.ts
│   │   │   │   ├── sessionRepository.ts
│   │   │   │   └── configRepository.ts
│   │   │   └── migrations/
│   │   │       └── 001_initial_schema.sql
│   │   ├── services/
│   │   │   ├── authService.ts        # Authentication logic
│   │   │   ├── campaignService.ts    # Campaign operations
│   │   │   ├── contactService.ts     # Contact operations
│   │   │   ├── queueService.ts       # Queue management
│   │   │   ├── importService.ts      # File import logic
│   │   │   ├── emailService.ts       # Email operations
│   │   │   └── configService.ts      # Configuration management
│   │   ├── utils/
│   │   │   ├── encryption.ts         # AES-256 encryption
│   │   │   ├── validation.ts         # Input validation
│   │   │   ├── personalization.ts    # Token replacement
│   │   │   ├── emailValidator.ts     # RFC 5322 validation
│   │   │   └── logger.ts             # Logging utility
│   │   ├── types/
│   │   │   ├── models.ts             # TypeScript interfaces
│   │   │   └── api.ts                # API request/response types
│   │   └── middleware/
│   │       ├── auth.ts               # Auth middleware
│   │       └── errorHandler.ts       # Error handling
│   └── worker/                       # Background worker
│       ├── index.ts                  # Worker entry point
│       ├── processor.ts              # Queue processor
│       ├── emailSender.ts            # SMTP/IMAP operations
│       ├── rateLimiter.ts            # Rate limiting logic
│       └── healthCheck.ts            # Heartbeat updater
├── public/
│   └── images/
├── prisma/                           # Alternative: Prisma ORM (optional)
│   └── schema.prisma
├── .env                              # Environment variables
├── .env.example
├── next.config.js
├── tailwind.config.ts
├── tsconfig.json
├── package.json
└── README.md
```

### 4.2 Configuration Files

#### `.env` Structure
```env
# Database
DATABASE_HOST=localhost
DATABASE_PORT=3306
DATABASE_NAME=email_campaign_portal
DATABASE_USER=root
DATABASE_PASSWORD=your_password

# Application
APP_URL=http://localhost:3000
SESSION_SECRET=your_random_secret_key
ENCRYPTION_KEY=your_32_byte_encryption_key

# Worker
WORKER_RATE_LIMIT=8
WORKER_POLL_INTERVAL=5000

# Logging
LOG_LEVEL=info
LOG_DIR=./logs
```

## 5. Component Hierarchy and UI Design

### 5.1 Component Architecture

```
App
├── RootLayout
│   └── body
│       ├── AuthLayout (auth routes)
│       │   └── LoginPage
│       │       ├── Card
│       │       ├── Form
│       │       │   ├── Input (username)
│       │       │   ├── Input (password)
│       │       │   └── Button (submit)
│       │       └── Alert (errors)
│       │
│       └── DashboardLayout (protected routes)
│           ├── Sidebar
│           │   ├── Logo
│           │   └── NavLinks
│           │       ├── DashboardLink
│           │       ├── CampaignsLink
│           │       ├── ContactsLink
│           │       └── SettingsLink
│           ├── Header
│           │   ├── PageTitle
│           │   └── UserMenu
│           │       └── LogoutButton
│           └── MainContent
│               ├── DashboardPage
│               │   ├── StatsCards
│               │   │   ├── TotalCampaignsCard
│               │   │   ├── TotalSentCard
│               │   │   ├── QueueSizeCard
│               │   │   └── WorkerStatusCard
│               │   └── RecentCampaignsList
│               │
│               ├── CampaignsPage
│               │   ├── PageHeader
│               │   │   ├── Title
│               │   │   └── CreateButton
│               │   ├── SearchBar
│               │   ├── CampaignTable
│               │   │   └── CampaignCard[] (map)
│               │   │       ├── CampaignName
│               │   │       ├── CampaignStats
│               │   │       │   ├── TotalRecipients
│               │   │       │   ├── SentCount
│               │   │       │   ├── FailedCount
│               │   │       │   └── QueuedCount
│               │   │       └── ActionButtons
│               │   │           ├── ViewButton
│               │   │           ├── EditButton
│               │   │           └── DeleteButton
│               │   └── Pagination
│               │
│               ├── CreateCampaignPage
│               │   └── CampaignForm
│               │       ├── Input (name)
│               │       ├── Input (subject)
│               │       ├── RichTextEditor (HTML body)
│               │       ├── Textarea (plain text body)
│               │       ├── TokenHelper
│               │       │   └── TokenList (available tokens)
│               │       ├── RecipientSelector
│               │       │   ├── ContactFilter
│               │       │   └── ContactCheckboxList
│               │       ├── PreviewButton
│               │       └── ActionButtons
│               │           ├── SaveDraftButton
│               │           └── SendButton
│               │
│               ├── CampaignDetailPage
│               │   ├── CampaignHeader
│               │   │   ├── CampaignName
│               │   │   ├── Status
│               │   │   └── CreatedDate
│               │   ├── CampaignStats
│               │   ├── RecipientReportTable
│               │   │   ├── SearchBar
│               │   │   ├── StatusFilter
│               │   │   ├── RecipientRow[] (map)
│               │   │   │   ├── RecipientName
│               │   │   │   ├── RecipientEmail
│               │   │   │   ├── StatusBadge
│               │   │   │   ├── SentTimestamp
│               │   │   │   ├── ErrorMessage
│               │   │   │   └── RetryCount
│               │   │   └── Pagination
│               │   ├── ActionButtons
│               │   │   ├── RetryFailedButton
│               │   │   └── ExportCSVButton
│               │   └── EmailPreviewDialog
│               │       ├── RecipientSelector
│               │       ├── HTMLPreview
│               │       └── PlainTextPreview
│               │
│               ├── ContactsPage
│               │   ├── PageHeader
│               │   │   ├── Title
│               │   │   ├── ImportButton
│               │   │   └── AddButton
│               │   ├── ContactFilter
│               │   │   ├── SearchInput
│               │   │   └── CustomFieldFilters
│               │   ├── ContactTable
│               │   │   ├── TableHeader
│               │   │   ├── ContactRow[] (map)
│               │   │   │   ├── Name
│               │   │   │   ├── Email
│               │   │   │   ├── CustomFields
│               │   │   │   └── ActionButtons
│               │   │   │       ├── EditButton
│               │   │   │       └── DeleteButton
│               │   │   └── Pagination
│               │   └── ImportDialog
│               │       └── ImportWizard
│               │           ├── FileUpload
│               │           ├── ColumnMapping
│               │           ├── ValidationResults
│               │           └── ImportSummary
│               │
│               └── SettingsPage
│                   ├── SMTPConfigForm
│                   │   ├── Input (host)
│                   │   ├── Input (port)
│                   │   ├── Input (username)
│                   │   ├── Input (password)
│                   │   ├── Select (encryption)
│                   │   ├── TestConnectionButton
│                   │   └── SaveButton
│                   └── IMAPConfigForm
│                       ├── Input (host)
│                       ├── Input (port)
│                       ├── Input (username)
│                       ├── Input (password)
│                       ├── Select (encryption)
│                       ├── Input (sent folder)
│                       ├── TestConnectionButton
│                       └── SaveButton
```

### 5.2 UI Design Patterns

#### Design System
- **Color Palette**: Using Tailwind's default palette with custom primary color
  - Primary: Blue (for actions, links)
  - Success: Green (sent emails, success states)
  - Warning: Yellow (warnings, pending states)
  - Danger: Red (failed emails, delete actions)
  - Neutral: Gray scale (backgrounds, borders, text)

- **Typography**: 
  - Headings: Font weight 600-700, size scale from text-sm to text-3xl
  - Body: Font weight 400, text-sm to text-base
  - Monospace: For email addresses and technical values

- **Spacing**: Consistent use of Tailwind spacing (4px grid)

- **Components**: All UI components from shadcn/ui for consistency

#### Responsive Design
- Desktop-first approach (1024px - 1920px)
- Flexible grid layouts
- Tables become scrollable on smaller screens
- Sidebar collapses to hamburger menu on tablets

### 5.3 Key UI Interactions

1. **Campaign Creation Flow**:
   - Form validation in real-time
   - Token insertion via click
   - Preview before sending
   - Confirmation dialog on send

2. **Contact Import Flow**:
   - Drag-and-drop file upload
   - Automatic column detection
   - Manual column mapping interface
   - Validation with error highlighting
   - Import summary with success/failure counts

3. **Recipient Report**:
   - Real-time status updates (via polling or websocket)
   - Filterable by status
   - Searchable by name/email
   - Exportable to CSV
   - Retry failed emails in bulk

## 6. API Route Structure

### 6.1 API Endpoints

#### Authentication
```typescript
POST /api/auth/login
  Request: { username: string, password: string }
  Response: { success: boolean, sessionToken: string }

POST /api/auth/logout
  Request: { sessionToken: string }
  Response: { success: boolean }
```

#### Campaigns
```typescript
GET /api/campaigns
  Query: { page: number, limit: number, sort: string }
  Response: { campaigns: Campaign[], total: number }

POST /api/campaigns
  Request: { name: string, subject: string, htmlBody: string, plainTextBody: string, recipientIds: number[] }
  Response: { campaign: Campaign }

GET /api/campaigns/:id
  Response: { campaign: Campaign, stats: CampaignStats }

PUT /api/campaigns/:id
  Request: { name?: string, subject?: string, htmlBody?: string, plainTextBody?: string }
  Response: { campaign: Campaign }

DELETE /api/campaigns/:id
  Response: { success: boolean }

POST /api/campaigns/:id/send
  Response: { success: boolean, queuedCount: number }

POST /api/campaigns/:id/preview
  Request: { recipientId: number }
  Response: { personalizedSubject: string, personalizedHtml: string, personalizedPlainText: string }

GET /api/campaigns/:id/recipients
  Query: { page: number, limit: number, status?: string, search?: string }
  Response: { recipients: RecipientReport[], total: number }
```

#### Contacts
```typescript
GET /api/contacts
  Query: { page: number, limit: number, search?: string, customFields?: string }
  Response: { contacts: Contact[], total: number }

POST /api/contacts
  Request: { name: string, email: string, customFields?: Record<string, any> }
  Response: { contact: Contact }

GET /api/contacts/:id
  Response: { contact: Contact }

PUT /api/contacts/:id
  Request: { name?: string, email?: string, customFields?: Record<string, any> }
  Response: { contact: Contact }

DELETE /api/contacts/:id
  Response: { success: boolean }

POST /api/contacts/import
  Request: FormData { file: File, columnMapping: Record<string, string> }
  Response: { imported: number, failed: number, updated: number, errors: ImportError[] }
```

#### Configuration
```typescript
GET /api/config/smtp
  Response: { config: SMTPConfig } // Credentials masked

POST /api/config/smtp
  Request: { host: string, port: number, username: string, password: string, encryption: 'TLS' | 'SSL' }
  Response: { success: boolean, testResult: ConnectionTestResult }

GET /api/config/imap
  Response: { config: IMAPConfig } // Credentials masked

POST /api/config/imap
  Request: { host: string, port: number, username: string, password: string, encryption: 'TLS' | 'SSL', sentFolderName: string }
  Response: { success: boolean, testResult: ConnectionTestResult }
```

#### Queue Management
```typescript
POST /api/queue/retry
  Request: { campaignId: number, recipientIds?: number[] }
  Response: { retriedCount: number }
```

#### Health Check
```typescript
GET /api/health
  Response: { 
    status: 'healthy' | 'degraded' | 'unhealthy',
    database: boolean,
    worker: { active: boolean, lastHeartbeat: string },
    queueSize: number
  }
```

### 6.2 API Error Handling

All API routes return consistent error responses:
```typescript
{
  error: string,           // Human-readable error message
  code: string,            // Machine-readable error code
  details?: any            // Optional additional details
}
```

HTTP Status Codes:
- 200: Success
- 201: Created
- 400: Bad Request (validation errors)
- 401: Unauthorized (invalid/expired session)
- 403: Forbidden (insufficient permissions)
- 404: Not Found
- 409: Conflict (duplicate email, etc.)
- 500: Internal Server Error

### 6.3 API Middleware Chain

```
Request → CORS → Request Logger → Auth Check → Rate Limiter → Route Handler → Response Logger → Error Handler → Response
```

## 7. Background Worker Architecture

### 7.1 Worker Process Flow

```
┌─────────────────────────────────────────────────────────┐
│              Background Worker Start                     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│         Initialize Database Connection                   │
│         Load SMTP/IMAP Configuration                     │
│         Initialize Rate Limiter                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│              Start Heartbeat Timer                       │
│         (Update worker_heartbeat every 60s)              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
        ┌────────────┴────────────┐
        │   Continuous Loop       │
        └────────────┬────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│   Query email_queue WHERE delivery_status = 'queued'     │
│              ORDER BY queued_at ASC LIMIT 1              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
              ┌──────┴───────┐
              │  Any queued  │
              │   entries?   │
              └──────┬───────┘
                 No  │  Yes
      ┌─────────────┴─────────────┐
      │                           │
      ↓                           ↓
┌───────────┐      ┌──────────────────────────────────────┐
│   Sleep   │      │  Update delivery_status = 'sending'  │
│   5 sec   │      └──────────────┬───────────────────────┘
└─────┬─────┘                     │
      │                           ↓
      │         ┌─────────────────────────────────────────┐
      │         │     Retrieve Campaign & Contact Data    │
      │         └──────────────┬──────────────────────────┘
      │                        │
      │                        ↓
      │         ┌─────────────────────────────────────────┐
      │         │  Personalize: Replace {{tokens}} with   │
      │         │     recipient data in subject/body      │
      │         └──────────────┬──────────────────────────┘
      │                        │
      │                        ↓
      │         ┌─────────────────────────────────────────┐
      │         │        Check Rate Limit                 │
      │         │   (5-10 emails per minute)              │
      │         └──────────────┬──────────────────────────┘
      │                        │
      │                 ┌──────┴───────┐
      │                 │  Rate limit  │
      │                 │   exceeded?  │
      │                 └──────┬───────┘
      │                    No  │  Yes
      │         ┌──────────────┴────────────┐
      │         │                           │
      │         ↓                           ↓
      │  ┌────────────────┐      ┌──────────────────┐
      │  │  Send via SMTP │      │  Sleep until     │
      │  │  (multipart)   │      │  next minute     │
      │  └────────┬───────┘      └────────┬─────────┘
      │           │                       │
      │      ┌────┴─────┐                 │
      │      │ Success? │                 │
      │      └────┬─────┘                 │
      │       Yes │ No                    │
      │   ┌───────┴───────┐               │
      │   ↓               ↓               │
      │ ┌─────┐      ┌─────────┐          │
      │ │Copy │      │  Update │          │
      │ │ to  │      │  status │          │
      │ │IMAP │      │= 'failed'         │
      │ │Sent │      │  + error │          │
      │ └──┬──┘      └────┬────┘          │
      │    │              │               │
      │    ↓              │               │
      │ ┌──────┐          │               │
      │ │Update│          │               │
      │ │status│          │               │
      │ │='sent│          │               │
      │ │+ sent│          │               │
      │ │_at   │          │               │
      │ └───┬──┘          │               │
      │     │             │               │
      └─────┴─────────────┴───────────────┘
                     │
                     ↓
            ┌────────────────┐
            │  Loop continues│
            └────────────────┘
```

### 7.2 Worker Components

#### 7.2.1 Queue Processor (`processor.ts`)
```typescript
class QueueProcessor {
  private db: DatabaseConnection;
  private emailSender: EmailSender;
  private rateLimiter: RateLimiter;
  private running: boolean = false;

  async start(): Promise<void>;
  async stop(): Promise<void>;
  private async processNextEmail(): Promise<void>;
  private async handleSendSuccess(queueId: number, sentAt: Date): Promise<void>;
  private async handleSendFailure(queueId: number, error: Error): Promise<void>;
}
```

#### 7.2.2 Email Sender (`emailSender.ts`)
```typescript
class EmailSender {
  private smtpClient: Nodemailer.Transporter;
  private imapClient: ImapSimple.Connection;

  async initialize(): Promise<void>;
  async sendEmail(to: string, subject: string, htmlBody: string, plainBody: string): Promise<void>;
  async copyToSent(emailMessage: string, sentDate: Date): Promise<void>;
  private buildMultipartMessage(subject: string, htmlBody: string, plainBody: string): string;
}
```

#### 7.2.3 Rate Limiter (`rateLimiter.ts`)
```typescript
class RateLimiter {
  private limit: number; // emails per minute
  private sentInCurrentMinute: number = 0;
  private currentMinuteStart: Date;

  async waitIfNeeded(): Promise<void>;
  recordEmailSent(): void;
  private resetIfNewMinute(): void;
}
```

#### 7.2.4 Health Check (`healthCheck.ts`)
```typescript
class HealthCheck {
  private db: DatabaseConnection;
  private workerName: string = 'main-worker';

  async start(): Promise<void>; // Start 60-second interval
  private async updateHeartbeat(): Promise<void>;
}
```

### 7.3 Worker Deployment

#### Process Manager Options

**Option 1: PM2 (Recommended for development/small deployments)**
```bash
pm2 start dist/worker/index.js --name email-worker
pm2 save
pm2 startup
```

**Option 2: systemd (Recommended for production Linux)**
```ini
# /etc/systemd/system/email-worker.service
[Unit]
Description=Email Campaign Background Worker
After=network.target mysql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/email-campaign-portal
ExecStart=/usr/bin/node /var/www/email-campaign-portal/dist/worker/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

**Option 3: Docker**
```dockerfile
# Dockerfile.worker
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY dist/worker ./dist/worker
COPY dist/lib ./dist/lib
CMD ["node", "dist/worker/index.js"]
```

### 7.4 Worker Error Recovery

1. **Database Connection Loss**: Retry every 30 seconds with exponential backoff
2. **SMTP Connection Loss**: Mark current email as failed, continue to next
3. **IMAP Connection Loss**: Log error, email still marked as sent (IMAP sync is optional)
4. **Process Crash**: Process manager automatically restarts
5. **Unhandled Exception**: Log full stack trace, continue processing

## 8. SMTP/IMAP Integration Design

### 8.1 SMTP Configuration

#### Library: `nodemailer`
```typescript
import nodemailer from 'nodemailer';

interface SMTPConfig {
  host: string;
  port: number;
  secure: boolean; // true for SSL, false for TLS
  auth: {
    user: string;
    pass: string;
  };
}

const createTransporter = (config: SMTPConfig) => {
  return nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.secure,
    auth: config.auth,
    tls: {
      rejectUnauthorized: true // Enforce valid certificates
    }
  });
};
```

#### Email Message Structure
```typescript
const message = {
  from: config.auth.user,
  to: recipient.email,
  subject: personalizedSubject,
  text: personalizedPlainText,
  html: personalizedHtml,
  messageId: `<campaign-${campaignId}-recipient-${recipientId}@${domain}>`,
  date: new Date()
};
```

### 8.2 IMAP Configuration

#### Library: `imap-simple`
```typescript
import imaps from 'imap-simple';

interface IMAPConfig {
  imap: {
    user: string;
    password: string;
    host: string;
    port: number;
    tls: boolean;
    tlsOptions: { rejectUnauthorized: boolean };
  };
}

const createIMAPConnection = async (config: IMAPConfig) => {
  return await imaps.connect(config);
};
```

#### Sent Folder Synchronization
```typescript
async function appendToSent(
  connection: ImapSimple.Connection,
  sentFolderName: string,
  rawMessage: string,
  sentDate: Date
): Promise<void> {
  await connection.append(rawMessage, {
    mailbox: sentFolderName,
    flags: ['\\Seen'],
    date: sentDate
  });
}
```

### 8.3 Multipart MIME Construction

```typescript
function buildMultipartMessage(
  from: string,
  to: string,
  subject: string,
  plainText: string,
  html: string,
  messageId: string,
  date: Date
): string {
  const boundary = `----=_Part_${Date.now()}_${Math.random()}`;
  
  return `From: ${from}
To: ${to}
Subject: ${subject}
Message-ID: ${messageId}
Date: ${date.toUTCString()}
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="${boundary}"

--${boundary}
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: quoted-printable

${plainText}

--${boundary}
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: quoted-printable

${html}

--${boundary}--`;
}
```

### 8.4 Connection Testing

Both SMTP and IMAP configurations include connection testing:
```typescript
async function testSMTPConnection(config: SMTPConfig): Promise<ConnectionTestResult> {
  try {
    const transporter = createTransporter(config);
    await transporter.verify();
    return { success: true, message: 'Connection successful' };
  } catch (error) {
    return { 
      success: false, 
      message: `Connection failed: ${error.message}`,
      details: error
    };
  }
}

async function testIMAPConnection(config: IMAPConfig): Promise<ConnectionTestResult> {
  try {
    const connection = await createIMAPConnection(config);
    await connection.openBox(config.sentFolderName);
    await connection.end();
    return { success: true, message: 'Connection successful' };
  } catch (error) {
    return { 
      success: false, 
      message: `Connection failed: ${error.message}`,
      details: error
    };
  }
}
```

## 9. Queue Processing Flow

### 9.1 Campaign Send Flow

```
Administrator clicks "Send Campaign"
             ↓
┌────────────────────────────────────────┐
│  1. Validate campaign                  │
│     - Has recipients                   │
│     - Has subject and both bodies      │
│     - Not already sent                 │
└────────────┬───────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│  2. Update campaign status = 'queued'  │
└────────────┬───────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│  3. For each recipient:                │
│     - Personalize subject/body         │
│     - Insert into email_queue          │
│     - Set status = 'queued'            │
│     - Set queued_at = NOW()            │
└────────────┬───────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│  4. Return success to administrator    │
│     "Campaign queued: N emails"        │
└────────────────────────────────────────┘

(Background worker picks up from here)
```

### 9.2 Worker Processing Flow

```
Worker queries for queued emails
             ↓
┌────────────────────────────────────────┐
│  SELECT * FROM email_queue             │
│  WHERE delivery_status = 'queued'      │
│  ORDER BY queued_at ASC                │
│  LIMIT 1                               │
└────────────┬───────────────────────────┘
             ↓
        ┌────┴─────┐
        │   Found  │
        │   email? │
        └────┬─────┘
          No │ Yes
   ┌─────────┴─────────┐
   ↓                   ↓
┌──────┐     ┌───────────────────────────┐
│Sleep │     │ UPDATE email_queue        │
│5 sec │     │ SET delivery_status =     │
└──┬───┘     │     'sending'             │
   │         │ WHERE id = ?              │
   │         └────────┬──────────────────┘
   │                  ↓
   │         ┌───────────────────────────┐
   │         │ Check rate limit          │
   │         └────────┬──────────────────┘
   │                  ↓
   │            ┌─────┴──────┐
   │            │   Within   │
   │            │   limit?   │
   │            └─────┬──────┘
   │              Yes │ No
   │       ┌──────────┴───────────┐
   │       ↓                      ↓
   │  ┌─────────┐        ┌──────────────┐
   │  │  Send   │        │ Wait until   │
   │  │  email  │        │ next minute  │
   │  │via SMTP │        └──────┬───────┘
   │  └────┬────┘               │
   │       │                    │
   │   ┌───┴────┐               │
   │   │Success?│               │
   │   └───┬────┘               │
   │   Yes │ No                 │
   │  ┌────┴────┐               │
   │  ↓         ↓               │
   │┌───┐   ┌───────┐           │
   ││Copy   │Update │           │
   ││to  │   │status │           │
   ││IMAP│   │='failed│          │
   │└─┬─┘   └───┬───┘           │
   │  │         │               │
   │  ↓         │               │
   │┌────────┐  │               │
   ││Update  │  │               │
   ││status= │  │               │
   ││'sent'  │  │               │
   │└────┬───┘  │               │
   │     │      │               │
   └─────┴──────┴───────────────┘
             ↓
    Loop continues
```

### 9.3 Status Transitions

```
Campaign Level:
draft → queued → processing → completed

Queue Entry Level:
queued → sending → sent
  │       │
  │       └──→ failed → (retry) → queued
  │
  └───────────→ failed
```

### 9.4 Personalization Process

```typescript
function personalizeContent(template: string, recipient: Contact): string {
  let personalized = template;
  
  // Standard fields
  personalized = personalized.replace(/\{\{name\}\}/g, recipient.name);
  personalized = personalized.replace(/\{\{email\}\}/g, recipient.email);
  
  // Custom fields
  if (recipient.customFields) {
    for (const [key, value] of Object.entries(recipient.customFields)) {
      const regex = new RegExp(`\\{\\{${key}\\}\\}`, 'g');
      personalized = personalized.replace(regex, String(value));
    }
  }
  
  // Replace any remaining unreplaced tokens with empty string
  personalized = personalized.replace(/\{\{[^}]+\}\}/g, '');
  
  return personalized;
}
```

## 10. Security Implementation

### 10.1 Authentication

#### Password Hashing
```typescript
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 10;

async function hashPassword(password: string): Promise<string> {
  return await bcrypt.hash(password, SALT_ROUNDS);
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return await bcrypt.compare(password, hash);
}
```

#### Password Validation
```typescript
function validatePassword(password: string): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  
  if (password.length < 8) {
    errors.push('Password must be at least 8 characters');
  }
  if (!/[A-Z]/.test(password)) {
    errors.push('Password must contain at least one uppercase letter');
  }
  if (!/[a-z]/.test(password)) {
    errors.push('Password must contain at least one lowercase letter');
  }
  if (!/[0-9]/.test(password)) {
    errors.push('Password must contain at least one number');
  }
  
  return { valid: errors.length === 0, errors };
}
```

#### Session Management
```typescript
import { randomBytes } from 'crypto';

function generateSessionToken(): string {
  return randomBytes(32).toString('hex');
}

async function createSession(administratorId: number): Promise<string> {
  const token = generateSessionToken();
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
  
  await db.query(
    'INSERT INTO sessions (administrator_id, session_token, expires_at) VALUES (?, ?, ?)',
    [administratorId, token, expiresAt]
  );
  
  return token;
}

async function validateSession(token: string): Promise<{ valid: boolean; administratorId?: number }> {
  const [rows] = await db.query(
    'SELECT administrator_id FROM sessions WHERE session_token = ? AND expires_at > NOW()',
    [token]
  );
  
  if (rows.length === 0) {
    return { valid: false };
  }
  
  return { valid: true, administratorId: rows[0].administrator_id };
}
```

#### Cookie Configuration
```typescript
const sessionCookie = {
  name: 'session_token',
  options: {
    httpOnly: true,      // Prevent JavaScript access
    secure: true,        // HTTPS only (in production)
    sameSite: 'strict',  // CSRF protection
    maxAge: 86400,       // 24 hours in seconds
    path: '/'
  }
};
```

### 10.2 Credential Encryption

#### AES-256 Encryption
```typescript
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const KEY = Buffer.from(process.env.ENCRYPTION_KEY!, 'hex'); // 32 bytes

function encrypt(plaintext: string): string {
  const iv = randomBytes(16);
  const cipher = createCipheriv(ALGORITHM, KEY, iv);
  
  let encrypted = cipher.update(plaintext, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  const authTag = cipher.getAuthTag();
  
  // Format: iv:authTag:encrypted
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
}

function decrypt(ciphertext: string): string {
  const [ivHex, authTagHex, encrypted] = ciphertext.split(':');
  
  const iv = Buffer.from(ivHex, 'hex');
  const authTag = Buffer.from(authTagHex, 'hex');
  
  const decipher = createDecipheriv(ALGORITHM, KEY, iv);
  decipher.setAuthTag(authTag);
  
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}
```

### 10.3 Input Validation and Sanitization

#### SQL Injection Prevention
```typescript
// ALWAYS use parameterized queries
// ✅ GOOD:
await db.query('SELECT * FROM contacts WHERE email = ?', [userInput]);

// ❌ BAD:
await db.query(`SELECT * FROM contacts WHERE email = '${userInput}'`);
```

#### XSS Prevention
```typescript
import DOMPurify from 'isomorphic-dompurify';

function sanitizeHtml(html: string): string {
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'u', 'a', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'img'],
    ALLOWED_ATTR: ['href', 'src', 'alt', 'title', 'style'],
    ALLOW_DATA_ATTR: false
  });
}

// In React components:
<div dangerouslySetInnerHTML={{ __html: sanitizeHtml(userContent) }} />
```

#### Email Validation (RFC 5322)
```typescript
function validateEmail(email: string): boolean {
  // RFC 5322 compliant regex (simplified)
  const regex = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
  return regex.test(email);
}
```

### 10.4 CSRF Protection

#### Next.js Implementation
```typescript
import { NextRequest, NextResponse } from 'next/server';
import { randomBytes } from 'crypto';

// Generate CSRF token
function generateCSRFToken(): string {
  return randomBytes(32).toString('hex');
}

// Middleware to validate CSRF token
export async function middleware(request: NextRequest) {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    const csrfToken = request.headers.get('x-csrf-token');
    const sessionToken = request.cookies.get('session_token')?.value;
    
    if (!csrfToken || !sessionToken) {
      return NextResponse.json({ error: 'CSRF token missing' }, { status: 403 });
    }
    
    // Validate CSRF token against session
    const valid = await validateCSRFToken(sessionToken, csrfToken);
    if (!valid) {
      return NextResponse.json({ error: 'Invalid CSRF token' }, { status: 403 });
    }
  }
  
  return NextResponse.next();
}
```

#### Client-Side Usage
```typescript
// Store CSRF token in meta tag
<meta name="csrf-token" content={csrfToken} />

// Include in fetch requests
const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

fetch('/api/campaigns', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken
  },
  body: JSON.stringify(data)
});
```

### 10.5 Authorization Middleware

```typescript
import { NextRequest, NextResponse } from 'next/server';

export async function authMiddleware(request: NextRequest) {
  // Public routes
  const publicPaths = ['/login', '/api/auth/login'];
  if (publicPaths.includes(request.nextUrl.pathname)) {
    return NextResponse.next();
  }
  
  // Check session
  const sessionToken = request.cookies.get('session_token')?.value;
  if (!sessionToken) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  
  const { valid, administratorId } = await validateSession(sessionToken);
  if (!valid) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  
  // Add administrator ID to request headers for downstream use
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-administrator-id', String(administratorId));
  
  return NextResponse.next({
    request: {
      headers: requestHeaders
    }
  });
}
```

## 11. Technology Choices and Justifications

### 11.1 Framework and Language

#### Next.js 14 with TypeScript
**Justification:**
- **Server Components**: Reduce JavaScript bundle size and improve initial load times
- **App Router**: Modern routing with layouts, nested routes, and streaming
- **API Routes**: Built-in API endpoints without separate backend
- **TypeScript**: Type safety reduces bugs, improves maintainability, excellent IDE support
- **Performance**: Automatic code splitting, image optimization, and caching
- **Developer Experience**: Hot reload, excellent documentation, large community

### 11.2 Database

#### MySQL with mysql2 Client
**Justification:**
- **Requirement Compliance**: Explicitly required by specifications with phpMyAdmin access
- **Transactional Integrity**: InnoDB engine supports ACID transactions for queue operations
- **JSON Support**: Native JSON column type for contact custom fields
- **Connection Pooling**: mysql2 provides efficient connection management
- **Performance**: Proven at scale with proper indexing
- **phpMyAdmin**: GUI access for database administration

**Why not Prisma ORM?**
- While Prisma provides excellent type safety and developer experience, raw SQL with mysql2 offers:
  - More control over query optimization
  - Simpler deployment (no migration generation step)
  - Direct SQL allows easier troubleshooting
  - Lower abstraction layer for better performance tuning
- However, Prisma can be added later if team prefers it

### 11.3 UI Component Library

#### shadcn/ui with Tailwind CSS
**Justification:**
- **Copy-Paste Approach**: Components are copied into project, allowing full customization
- **No Runtime Overhead**: Unlike component libraries with JavaScript dependencies
- **Tailwind Integration**: Seamless integration with utility-first CSS
- **Accessibility**: Built on Radix UI primitives with ARIA attributes
- **Customizable**: Easy to modify without fighting library constraints
- **Modern Design**: Professional, clean aesthetic out of the box

### 11.4 Email Libraries

#### nodemailer for SMTP
**Justification:**
- **Most Popular**: De facto standard for Node.js email sending
- **Multipart Support**: Easy construction of HTML + plain text emails
- **Wide Provider Support**: Works with all major SMTP providers
- **Connection Pooling**: Efficient for sending multiple emails
- **Well Maintained**: Active development and security updates

#### imap-simple for IMAP
**Justification:**
- **Promise-Based**: Modern async/await API
- **Simplified API**: Easier than raw imap library
- **Append Support**: Required for Sent folder synchronization
- **TLS Support**: Secure connections to IMAP servers

### 11.5 Authentication

#### bcrypt for Password Hashing
**Justification:**
- **Industry Standard**: Widely trusted and vetted
- **Adaptive Hashing**: Cost factor can be increased as hardware improves
- **Salt Included**: Automatic salt generation and storage
- **Timing Attack Resistant**: Constant-time comparison

#### Native crypto for Session Tokens
**Justification:**
- **Built-in**: No external dependencies
- **Cryptographically Secure**: Uses CSPRNG
- **Simple**: Easy to generate and validate

### 11.6 Background Worker

#### Node.js Process (Not Separate Service)
**Justification:**
- **Shared Codebase**: Can reuse services, utilities, and types from web app
- **Simple Deployment**: Single repository, consistent environment
- **Database Access**: Same connection pooling and query patterns
- **TypeScript**: Type safety across entire codebase
- **Process Managers**: PM2, systemd, or Docker can ensure reliability

**Why not Bull/BullMQ?**
- Adds Redis dependency
- Our simple queue doesn't need Redis features
- Database queue is sufficient for rate of 5-10 emails/minute
- Simpler architecture for initial deployment

### 11.7 Validation

#### Zod (Optional, Recommended)
**Justification:**
- **Runtime Validation**: Validates API payloads at runtime
- **Type Inference**: TypeScript types automatically derived from schemas
- **Composable**: Build complex validation from simple schemas
- **Error Messages**: Clear validation error reporting

**Alternative**: Manual validation functions (used in examples above)

## 12. Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Session Creation for Valid Credentials

*For any* valid administrator credentials (username and password), submitting them to the login endpoint should create a session with a unique session token and expiration time.

**Validates: Requirements 1.2**

### Property 2: Session Rejection for Invalid Credentials

*For any* invalid administrator credentials (non-existent username or incorrect password), submitting them to the login endpoint should not create a session and should return an authentication error.

**Validates: Requirements 1.3**

### Property 3: Password Storage Security

*For any* administrator password stored in the database, the stored value should be a bcrypt hash with cost factor >= 10 and should not equal the plaintext password.

**Validates: Requirements 1.5, 20.1**

### Property 4: Session Termination on Logout

*For any* active session, calling the logout endpoint with that session token should invalidate the session such that subsequent requests with that token are rejected.

**Validates: Requirements 1.6**

### Property 5: Configuration Storage Round-Trip

*For any* SMTP or IMAP configuration saved to the database, retrieving it should return equivalent data with credentials properly encrypted in storage and decrypted on retrieval.

**Validates: Requirements 2.2, 3.2**

### Property 6: Credential Encryption

*For any* SMTP or IMAP credentials stored in the database, the stored password value should be AES-256 encrypted and not equal to the plaintext password.

**Validates: Requirements 2.5, 3.5, 20.2**

### Property 7: Email Validation

*For any* email address validated by the system, it should pass if and only if it conforms to RFC 5322 format.

**Validates: Requirements 4.4, 6.2**

### Property 8: Import Duplicate Handling

*For any* contact import where an email address already exists in the database, the existing contact record should be updated with the new data rather than creating a duplicate.

**Validates: Requirements 4.8, 5.9**

### Property 9: Import Error Isolation

*For any* contact import containing both valid and invalid email addresses, the invalid rows should be marked as failed while all valid rows should be successfully imported.

**Validates: Requirements 4.5, 5.6**

### Property 10: Contact Deletion

*For any* contact that is deleted, subsequent queries for that contact by ID should return not found, and the contact should not appear in contact list results.

**Validates: Requirements 6.5**

### Property 11: Personalization Token Recognition

*For any* campaign content containing text in the format `{{token_name}}`, the system should recognize it as a personalization token and replace it with corresponding recipient data during email processing.

**Validates: Requirements 7.4**

### Property 12: Campaign Content Validation

*For any* campaign submission, validation should fail if either the subject, HTML body, or plain text body is empty.

**Validates: Requirements 7.6, 25.1, 25.2, 25.3**

### Property 13: Queue Entry Creation

*For any* campaign with N recipients that is sent, exactly N queue entries should be created in the email_queue table with delivery_status = 'queued'.

**Validates: Requirements 10.1, 10.2**

### Property 14: Queue Timestamp Recording

*For any* queue entry created, the queued_at timestamp should be set to the time of creation.

**Validates: Requirements 10.5**

### Property 15: FIFO Queue Processing

*For any* set of queued email entries, the background worker should process them in the order they were queued (earliest queued_at first).

**Validates: Requirements 11.3**

### Property 16: Status Transition to Sending

*For any* queue entry with status 'queued' that the worker begins processing, the status should transition to 'sending' before any email operations are performed.

**Validates: Requirements 11.4**

### Property 17: Personalization Token Replacement

*For any* email queue entry processed, all personalization tokens in the subject and body should be replaced with the correct recipient-specific data from the contacts table.

**Validates: Requirements 11.6**

### Property 18: Rate Limit Enforcement

*For any* one-minute time window during background worker operation, the number of emails sent should not exceed the configured rate limit (5-10 emails).

**Validates: Requirements 11.8, 12.1**

### Property 19: Success Status Transition

*For any* email that is sent successfully via SMTP, the queue entry status should be updated to 'sent' and the sent_at timestamp should be recorded.

**Validates: Requirements 11.9**

### Property 20: Failure Status Transition

*For any* email that fails to send via SMTP, the queue entry status should be updated to 'failed' and the error message should be recorded.

**Validates: Requirements 11.10**

### Property 21: Processing Resilience

*For any* batch of queue entries being processed where some fail, the successful entries should still complete and be marked as 'sent' despite the failures.

**Validates: Requirements 11.11**

### Property 22: Multipart Email Format

*For any* email sent by the background worker, the SMTP message should contain both HTML and plain text alternatives in multipart/alternative MIME format.

**Validates: Requirements 11.12, 29.1, 29.2, 29.3**

### Property 23: Campaign Statistics Accuracy

*For any* campaign, the displayed statistics (total recipients, sent count, failed count, queued count) should match the actual counts from the email_queue table for that campaign.

**Validates: Requirements 14.2, 14.3, 14.4, 14.5**

### Property 24: Retry Status Reset

*For any* failed queue entry that is retried, its delivery_status should transition from 'failed' to 'queued' and its retry_count should increment by 1.

**Validates: Requirements 16.2, 16.4**

### Property 25: Password Complexity Enforcement

*For any* password submitted during administrator account creation or update, it should be rejected if it does not meet complexity requirements (minimum 8 characters, at least one uppercase, one lowercase, one number).

**Validates: Requirements 20.8**

### Property 26: Protected Route Authentication

*For any* request to a protected route (any route except /login and /api/auth/login) without a valid session token, the request should be rejected with an authentication error.

**Validates: Requirements 20.9**

### Property 27: Parameterized Query Usage

*For any* database query that includes user-provided input, the query should use parameterized statements (prepared statements) rather than string concatenation.

**Validates: Requirements 20.4**

### Property 28: Custom Field Storage Round-Trip

*For any* contact with custom fields stored as JSON, retrieving the contact should return the custom fields with the same keys and values that were stored.

**Validates: Requirements 28.2**

### Property 29: Missing Token Replacement

*For any* personalization token in a campaign that references a custom field not present in a recipient's data, the token should be replaced with an empty string rather than causing an error.

**Validates: Requirements 28.5**

### Property 30: Analytics Calculation Accuracy

*For any* campaign, the calculated analytics (success rate, failure rate, average processing time) should correctly reflect the actual data from the email_queue table entries for that campaign.

**Validates: Requirements 27.1, 27.2, 27.3, 27.4**

## 13. Error Handling and Logging

### 13.1 Logging Architecture

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ 
      filename: 'logs/error.log', 
      level: 'error',
      maxsize: 10485760, // 10MB
      maxFiles: 30
    }),
    new winston.transports.File({ 
      filename: 'logs/combined.log',
      maxsize: 10485760,
      maxFiles: 30
    })
  ]
});

// Console logging in development
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple()
  }));
}
```

### 13.2 Log Event Types

```typescript
// Authentication
logger.info('Authentication attempt', { username, success: true, ip });
logger.warn('Authentication failed', { username, reason: 'Invalid password', ip });

// SMTP/IMAP
logger.info('SMTP connection test', { host, port, success: true });
logger.error('SMTP connection failed', { host, port, error: error.message });

// Email Processing
logger.info('Email sent', { campaignId, recipientId, queueId, sentAt });
logger.error('Email send failed', { campaignId, recipientId, queueId, error: error.message, stack: error.stack });

// Worker
logger.info('Worker started', { workerName: 'main-worker', pid: process.pid });
logger.info('Worker shutdown', { workerName: 'main-worker', reason: 'SIGTERM' });

// Errors
logger.error('Unhandled exception', { error: error.message, stack: error.stack });
```

### 13.3 Error Handling Patterns

```typescript
// API Route Error Handler
export async function errorHandler(error: Error, req: NextRequest): Promise<NextResponse> {
  // Log error
  logger.error('API error', {
    path: req.nextUrl.pathname,
    method: req.method,
    error: error.message,
    stack: error.stack
  });
  
  // Return appropriate response
  if (error instanceof ValidationError) {
    return NextResponse.json(
      { error: error.message, code: 'VALIDATION_ERROR', details: error.details },
      { status: 400 }
    );
  }
  
  if (error instanceof AuthenticationError) {
    return NextResponse.json(
      { error: 'Authentication required', code: 'AUTH_ERROR' },
      { status: 401 }
    );
  }
  
  // Generic error (don't expose internal details)
  return NextResponse.json(
    { error: 'An error occurred', code: 'INTERNAL_ERROR' },
    { status: 500 }
  );
}
```

## 14. Performance Optimization

### 14.1 Database Optimizations

1. **Connection Pooling**:
```typescript
const pool = mysql.createPool({
  host: process.env.DATABASE_HOST,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
  database: process.env.DATABASE_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});
```

2. **Indexes** (defined in schema section)

3. **Query Optimization**:
   - Use LIMIT for pagination
   - Use COUNT(*) with LIMIT for total counts
   - Avoid SELECT * in favor of specific columns
   - Use JOINs efficiently

### 14.2 Caching Strategy

```typescript
// Cache SMTP/IMAP configurations (they rarely change)
const configCache = new Map<string, any>();

async function getCachedSMTPConfig(): Promise<SMTPConfig> {
  if (configCache.has('smtp')) {
    return configCache.get('smtp');
  }
  
  const config = await fetchSMTPConfigFromDB();
  configCache.set('smtp', config);
  
  // Expire after 5 minutes
  setTimeout(() => configCache.delete('smtp'), 5 * 60 * 1000);
  
  return config;
}
```

### 14.3 Pagination

```typescript
interface PaginationParams {
  page: number;
  limit: number;
}

interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

async function paginateContacts(params: PaginationParams): Promise<PaginatedResponse<Contact>> {
  const offset = (params.page - 1) * params.limit;
  
  const [contacts] = await db.query(
    'SELECT * FROM contacts ORDER BY created_at DESC LIMIT ? OFFSET ?',
    [params.limit, offset]
  );
  
  const [countResult] = await db.query('SELECT COUNT(*) as total FROM contacts');
  const total = countResult[0].total;
  
  return {
    data: contacts,
    pagination: {
      page: params.page,
      limit: params.limit,
      total,
      totalPages: Math.ceil(total / params.limit)
    }
  };
}
```

## 15. Testing Strategy

### 15.1 Unit Tests

**Property-Based Tests** (minimum 100 iterations each):
- Authentication: Password hashing, session creation, validation
- Personalization: Token replacement with various recipient data
- Validation: Email format, password complexity, input sanitization
- Encryption: Credential encryption/decryption round-trips
- Rate Limiting: Email sending rate enforcement

**Example-Based Unit Tests**:
- Specific edge cases (empty inputs, special characters)
- Error handling paths
- Configuration validation

### 15.2 Integration Tests

- Database operations with test database
- SMTP/IMAP connections with test servers
- API endpoints with authentication
- File import with sample Excel/CSV files

### 15.3 Test Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    setupFiles: ['./src/__tests__/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['src/**/*.ts'],
      exclude: ['src/**/*.test.ts', 'src/__tests__/**']
    }
  }
});
```

## 16. Deployment Guide

### 16.1 Environment Setup

1. **Install Dependencies**:
```bash
npm install
```

2. **Configure Environment Variables**:
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Initialize Database**:
```bash
mysql -u root -p < src/lib/db/migrations/001_initial_schema.sql
```

4. **Create Initial Administrator**:
```bash
npm run create-admin
```

5. **Build Application**:
```bash
npm run build
```

### 16.2 Web Application Deployment

**Development**:
```bash
npm run dev
```

**Production (PM2)**:
```bash
pm2 start npm --name "email-portal-web" -- start
pm2 save
pm2 startup
```

**Production (Docker)**:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY .next ./.next
COPY public ./public
EXPOSE 3000
CMD ["npm", "start"]
```

### 16.3 Background Worker Deployment

See section 7.3 for detailed worker deployment options (PM2, systemd, Docker).

### 16.4 Nginx Configuration

```nginx
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/ssl/certs/example.com.crt;
    ssl_certificate_key /etc/ssl/private/example.com.key;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 17. Maintenance and Monitoring

### 17.1 Database Maintenance

```sql
-- Clean up expired sessions (daily cron job)
DELETE FROM sessions WHERE expires_at < NOW();

-- Archive completed campaigns older than 90 days
-- (Create archive tables and move old data)

-- Optimize tables monthly
OPTIMIZE TABLE email_queue;
OPTIMIZE TABLE contacts;
OPTIMIZE TABLE campaigns;
```

### 17.2 Monitoring Metrics

1. **Application Metrics**:
   - API response times
   - Error rates
   - Active sessions

2. **Worker Metrics**:
   - Queue size
   - Processing rate
   - Failure rate
   - Heartbeat status

3. **Database Metrics**:
   - Connection pool usage
   - Query performance
   - Table sizes

### 17.3 Alerting

Set up alerts for:
- Worker heartbeat missing (> 2 minutes)
- Queue size exceeds threshold (> 10,000)
- High email failure rate (> 10%)
- Database connection failures
- Disk space low

## 18. Conclusion

This design document provides a comprehensive blueprint for building a production-ready Email Campaign Management Portal. The architecture emphasizes:

- **Scalability**: Queue-based processing allows independent scaling of web and worker components
- **Reliability**: Comprehensive error handling, retry logic, and process management
- **Security**: Multi-layered security with authentication, encryption, and input validation
- **Maintainability**: Clear separation of concerns, type safety, and extensive documentation
- **Performance**: Database optimization, connection pooling, and efficient query patterns

The correctness properties defined in section 12 serve as executable specifications that guide testing and ensure the system behaves correctly across all valid inputs.

Next steps:
1. Review and validate requirements with stakeholders
2. Set up development environment
3. Implement database schema
4. Build core authentication system
5. Develop campaign management features
6. Implement background worker
7. Comprehensive testing (unit, integration, property-based)
8. Deployment to production environment
