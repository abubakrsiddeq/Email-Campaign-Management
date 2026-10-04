# Implementation Plan: Email Campaign Management Portal

## Overview

This implementation plan breaks down the Email Campaign Management Portal into incremental, testable steps. The system will be built using Next.js 14, TypeScript, MySQL, and a Node.js background worker. Each task focuses on creating discrete, working functionality that builds upon previous steps, with all components integrated progressively.

## Tasks

- [x] 1. Project setup and core infrastructure
  - Initialize Next.js 14 project with TypeScript and App Router
  - Configure Tailwind CSS and shadcn/ui
  - Set up project directory structure following design specifications
  - Create environment variable configuration (.env.example and .env)
  - Install core dependencies: mysql2, bcrypt, nodemailer, imap-simple, zod
  - Configure tsconfig.json for path aliases (@/lib, @/components, etc.)
  - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.5_

- [x] 2. Database schema and connection setup
  - [x] 2.1 Create SQL migration file with complete database schema
    - Create all 9 tables: administrators, smtp_configurations, imap_configurations, contacts, campaigns, campaign_recipients, email_queue, sessions, worker_heartbeat
    - Define all columns, data types, indexes, foreign keys, and constraints
    - Add comments documenting each table's purpose
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.6, 18.7, 18.8, 18.9, 18.10, 18.11_
  
  - [ ] 2.2 Implement database connection pooling
    - Create lib/db/connection.ts with MySQL connection pool
    - Implement connection configuration from environment variables
    - Add connection health check function
    - Export typed query execution helper
    - _Requirements: 19.5, 22.5_
  
  - [ ]* 2.3 Write unit tests for database connection
    - Test connection pool initialization
    - Test query execution wrapper
    - Test connection failure handling
    - _Requirements: 19.5_

- [ ] 3. Security utilities implementation
  - [ ] 3.1 Implement encryption utilities
    - Create lib/utils/encryption.ts with AES-256 encrypt/decrypt functions
    - Implement secure key management from environment variables
    - Add functions for encrypting and decrypting SMTP/IMAP credentials
    - _Requirements: 2.5, 3.5, 20.2_
  
  - [ ] 3.2 Implement authentication utilities
    - Create lib/utils/validation.ts with password hashing (bcrypt)
    - Add password complexity validation function
    - Add session token generation using crypto.randomBytes
    - Implement email validation using RFC 5322 regex
    - _Requirements: 1.5, 4.4, 5.5, 6.2, 20.1, 20.8_
  
  - [ ]* 3.3 Write unit tests for security utilities
    - Test password hashing and verification
    - Test password complexity validation
    - Test email validation with valid and invalid cases
    - Test encryption/decryption round-trip
    - _Requirements: 20.1, 20.2_

- [ ] 4. Database repositories
  - [ ] 4.1 Create administrator repository
    - Create lib/db/repositories/administratorRepository.ts
    - Implement createAdministrator, findByUsername, findById functions
    - Use parameterized queries for SQL injection prevention
    - _Requirements: 1.1, 1.2, 1.3, 20.4_
  
  - [ ] 4.2 Create session repository
    - Create lib/db/repositories/sessionRepository.ts
    - Implement createSession, validateSession, deleteSession, cleanupExpiredSessions functions
    - _Requirements: 1.2, 1.6, 1.7_
  
  - [ ] 4.3 Create configuration repository
    - Create lib/db/repositories/configRepository.ts
    - Implement saveSMTPConfig, getSMTPConfig, saveIMAPConfig, getIMAPConfig functions
    - Handle credential encryption/decryption in repository layer
    - _Requirements: 2.2, 3.2_
  
  - [ ] 4.4 Create contact repository
    - Create lib/db/repositories/contactRepository.ts
    - Implement createContact, updateContact, deleteContact, findById, findByEmail, listContacts functions
    - Add pagination and search functionality
    - Handle JSON serialization for custom_fields_json column
    - _Requirements: 4.7, 5.8, 6.1, 6.3, 6.4, 6.5, 6.6, 6.7_
  
  - [ ] 4.5 Create campaign repository
    - Create lib/db/repositories/campaignRepository.ts
    - Implement createCampaign, updateCampaign, deleteCampaign, findById, listCampaigns functions
    - Add functions for campaign statistics aggregation
    - Implement addRecipients and getRecipients functions
    - _Requirements: 7.7, 7.8, 8.7, 14.1, 14.2, 14.3, 14.4, 14.5, 17.3_
  
  - [ ] 4.6 Create queue repository
    - Create lib/db/repositories/queueRepository.ts
    - Implement createQueueEntries, getNextQueued, updateStatus, getRecipientReport, retryFailed functions
    - Add pagination and filtering for recipient reports
    - _Requirements: 10.2, 11.2, 11.4, 11.9, 11.10, 15.1, 15.2, 15.3, 15.4, 16.2, 16.4_
  
  - [ ]* 4.7 Write integration tests for repositories
    - Test CRUD operations for each repository
    - Test pagination and filtering
    - Test transaction handling
    - _Requirements: 22.5_

- [ ] 5. Checkpoint - Database layer complete
  - Ensure all repository tests pass
  - Verify database schema is correctly created
  - Confirm connection pooling works as expected
  - Ask the user if questions arise

- [ ] 6. Business logic services
  - [ ] 6.1 Implement authentication service
    - Create lib/services/authService.ts
    - Implement login, logout, validateSession, createInitialAdmin functions
    - Combine repository calls with password verification
    - _Requirements: 1.2, 1.3, 1.4, 1.6, 1.7_
  
  - [ ] 6.2 Implement contact service
    - Create lib/services/contactService.ts
    - Implement createContact, updateContact, deleteContact, getContact, listContacts functions
    - Add validation logic before repository calls
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  
  - [ ] 6.3 Implement import service
    - Create lib/services/importService.ts
    - Implement parseExcelFile and parseCSVFile functions
    - Add column mapping logic
    - Implement bulk contact creation with duplicate handling
    - Return import summary with success/failure counts
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.8, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.9_
  
  - [ ] 6.4 Implement campaign service
    - Create lib/services/campaignService.ts
    - Implement createCampaign, updateCampaign, deleteCampaign, getCampaign, listCampaigns functions
    - Add campaign validation logic
    - Implement sendCampaign function that creates queue entries
    - Implement getCampaignStats and getRecipientReport functions
    - _Requirements: 7.1, 7.2, 7.3, 7.6, 7.7, 7.8, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 10.1, 10.2, 10.3, 10.4, 10.5, 14.1, 14.2, 14.3, 14.4, 14.5, 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 17.1, 17.2, 17.3, 17.4, 17.5_
  
  - [ ] 6.5 Implement configuration service
    - Create lib/services/configService.ts
    - Implement testSMTPConnection, saveSMTPConfig, getSMTPConfig functions
    - Implement testIMAPConnection, saveIMAPConfig, getIMAPConfig functions
    - Add connection testing before saving configurations
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 3.7_
  
  - [ ] 6.6 Implement personalization utility
    - Create lib/utils/personalization.ts
    - Implement token replacement function for {{token}} syntax
    - Handle missing custom fields gracefully
    - Add function to extract tokens from template content
    - _Requirements: 7.4, 7.5, 11.6, 25.4, 25.5, 28.5_
  
  - [ ]* 6.7 Write unit tests for services
    - Test authentication flows (login, logout, session validation)
    - Test campaign creation and validation
    - Test contact import with various file formats
    - Test personalization token replacement
    - _Requirements: 1.2, 1.3, 7.6, 25.1, 25.2, 25.3_

- [ ] 7. Authentication UI and API routes
  - [ ] 7.1 Create authentication middleware
    - Create lib/middleware/auth.ts
    - Implement session validation middleware for protected routes
    - Add redirect logic for unauthenticated access
    - _Requirements: 1.4, 20.9_
  
  - [ ] 7.2 Build login page UI
    - Create app/(auth)/login/page.tsx
    - Create login form with username and password inputs
    - Add client-side validation
    - Display error messages for failed authentication
    - Use shadcn/ui components (Card, Input, Button, Alert)
    - _Requirements: 1.1, 1.3_
  
  - [ ] 7.3 Implement authentication API routes
    - Create app/api/auth/login/route.ts (POST)
    - Create app/api/auth/logout/route.ts (POST)
    - Implement session cookie management with secure flags
    - Add CSRF protection
    - _Requirements: 1.2, 1.3, 1.6, 20.6, 20.7_
  
  - [ ]* 7.4 Write integration tests for authentication
    - Test login with valid credentials
    - Test login with invalid credentials
    - Test logout functionality
    - Test session expiration
    - _Requirements: 1.2, 1.3, 1.6, 1.7_

- [ ] 8. Dashboard layout and navigation
  - [ ] 8.1 Create dashboard layout with sidebar
    - Create app/(dashboard)/layout.tsx
    - Build Sidebar component with navigation links
    - Add Header component with user menu and logout
    - Implement responsive design
    - Apply authentication middleware to dashboard routes
    - _Requirements: 1.4, 24.1, 24.2, 24.3, 24.4, 24.5_
  
  - [ ] 8.2 Build main dashboard page
    - Create app/(dashboard)/dashboard/page.tsx
    - Display statistics cards: total campaigns, total sent, queue size, worker status
    - Show recent campaigns list
    - Implement real-time worker status indicator
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 27.5, 30.5_
  
  - [ ] 8.3 Create shared UI components
    - Create components/ui/pagination.tsx
    - Create components/shared/SearchBar.tsx
    - Create components/shared/LoadingSpinner.tsx
    - Create components/shared/ErrorBoundary.tsx
    - _Requirements: 14.7, 15.7_

- [ ] 9. Contact management UI and API
  - [ ] 9.1 Build contacts list page
    - Create app/(dashboard)/contacts/page.tsx
    - Display paginated contact table with name, email, custom fields
    - Add search and filter functionality
    - Include action buttons (Edit, Delete, Import, Add)
    - _Requirements: 6.6, 6.7_
  
  - [ ] 9.2 Build add/edit contact forms
    - Create app/(dashboard)/contacts/new/page.tsx
    - Create app/(dashboard)/contacts/[id]/edit/page.tsx
    - Create ContactForm component with validation
    - Support custom field input (dynamic key-value pairs)
    - _Requirements: 6.1, 6.2, 6.3, 28.3_
  
  - [ ] 9.3 Build contact import wizard
    - Create app/(dashboard)/contacts/import/page.tsx
    - Create ImportWizard component with multi-step flow
    - Implement file upload (drag-and-drop and browse)
    - Add column mapping interface
    - Display validation results and import summary
    - _Requirements: 4.1, 4.2, 4.3, 4.6, 5.1, 5.2, 5.3, 5.7, 28.1_
  
  - [ ] 9.4 Implement contacts API routes
    - Create app/api/contacts/route.ts (GET, POST)
    - Create app/api/contacts/[id]/route.ts (GET, PUT, DELETE)
    - Create app/api/contacts/import/route.ts (POST)
    - Handle file upload parsing and validation
    - Return appropriate error responses
    - _Requirements: 4.4, 4.5, 4.8, 5.5, 5.6, 5.9, 6.1, 6.2, 6.3, 6.4, 6.5, 20.4, 20.5_
  
  - [ ]* 9.5 Write integration tests for contact management
    - Test contact CRUD operations via API
    - Test contact import with Excel and CSV files
    - Test duplicate email handling
    - Test validation error responses
    - _Requirements: 4.8, 5.9, 6.2_

- [ ] 10. Checkpoint - Contact management complete
  - Ensure contacts can be created, edited, deleted, and imported
  - Verify pagination and search work correctly
  - Test custom fields storage and retrieval
  - Ask the user if questions arise

- [ ] 11. Campaign management UI and API
  - [ ] 11.1 Build campaigns list page
    - Create app/(dashboard)/campaigns/page.tsx
    - Display campaign cards/table with name, status, statistics
    - Show total recipients, sent count, failed count, queued count per campaign
    - Add action buttons (View, Edit, Delete, Create New)
    - Implement sorting by creation date
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7_
  
  - [ ] 11.2 Build campaign creation form
    - Create app/(dashboard)/campaigns/new/page.tsx
    - Create CampaignForm component with rich text editor for HTML body
    - Add plain text editor for plain text body
    - Implement recipient selector with contact filtering
    - Display available personalization tokens with click-to-insert
    - Add character count for subject line with warning at 78 characters
    - Validate required fields (name, subject, both bodies, recipients)
    - Include "Save as Draft" and "Send Campaign" buttons
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 25.1, 25.2, 25.3, 25.4, 25.6, 25.7_
  
  - [ ] 11.3 Build campaign edit page
    - Create app/(dashboard)/campaigns/[id]/edit/page.tsx
    - Pre-populate form with existing campaign data
    - Allow editing name, subject, and bodies
    - Prevent editing if campaign is not in draft status
    - _Requirements: 7.7, 7.8_
  
  - [ ] 11.4 Build campaign preview functionality
    - Create EmailPreview component
    - Implement preview modal with recipient selector
    - Display both HTML and plain text versions with personalization applied
    - Add tab switching between HTML and plain text views
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_
  
  - [ ] 11.5 Build campaign detail and recipient report page
    - Create app/(dashboard)/campaigns/[id]/recipients/page.tsx
    - Display campaign header with name, status, creation date
    - Show campaign-level statistics
    - Implement recipient report table with columns: name, email, status, sent timestamp, error message, retry count
    - Add filtering by delivery status
    - Add search by name or email
    - Include pagination
    - Add "Retry Failed" button and "Export CSV" button
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.8, 16.1, 27.1, 27.2_
  
  - [ ] 11.6 Implement campaigns API routes
    - Create app/api/campaigns/route.ts (GET, POST)
    - Create app/api/campaigns/[id]/route.ts (GET, PUT, DELETE)
    - Create app/api/campaigns/[id]/send/route.ts (POST)
    - Create app/api/campaigns/[id]/preview/route.ts (POST)
    - Create app/api/campaigns/[id]/recipients/route.ts (GET)
    - Implement campaign validation logic
    - Handle queue entry creation on campaign send
    - Return campaign statistics in responses
    - _Requirements: 7.6, 7.7, 7.8, 8.7, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3, 10.4, 10.5, 17.1, 17.2, 17.3, 17.4, 17.5, 25.1, 25.2, 25.3_
  
  - [ ]* 11.7 Write integration tests for campaign management
    - Test campaign creation with validation
    - Test campaign sending and queue entry creation
    - Test campaign preview with personalization
    - Test recipient report filtering and pagination
    - _Requirements: 7.6, 10.1, 10.2, 10.5_

- [ ] 12. Email queue and background worker
  - [ ] 12.1 Implement rate limiter
    - Create src/worker/rateLimiter.ts
    - Track emails sent per minute with rolling window
    - Implement waitIfNeeded function that delays processing when limit reached
    - Support configurable rate limit (5-10 emails/minute)
    - _Requirements: 11.8, 12.1, 12.2, 12.3, 12.4, 12.5_
  
  - [ ] 12.2 Implement email sender with SMTP/IMAP
    - Create src/worker/emailSender.ts
    - Initialize nodemailer SMTP transporter
    - Initialize imap-simple IMAP connection
    - Implement sendEmail function with multipart MIME format
    - Implement copyToSent function using IMAP APPEND
    - Handle connection errors gracefully
    - _Requirements: 11.7, 11.12, 13.1, 13.2, 13.3, 13.4, 13.5, 19.7, 29.1, 29.2, 29.3, 29.4, 29.5_
  
  - [ ] 12.3 Implement queue processor
    - Create src/worker/processor.ts
    - Implement continuous loop that queries for queued entries
    - Update status to 'sending' before processing
    - Retrieve campaign and contact data
    - Personalize subject and bodies using token replacement
    - Call rate limiter before sending
    - Send email via SMTP
    - Copy to IMAP Sent folder
    - Update status to 'sent' with timestamp on success
    - Update status to 'failed' with error message on failure
    - Continue processing on individual failures
    - Sleep when no queued entries found
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 11.10, 11.11, 11.12_
  
  - [ ] 12.4 Implement worker health check
    - Create src/worker/healthCheck.ts
    - Update worker_heartbeat table every 60 seconds
    - Record worker name and status
    - _Requirements: 30.3_
  
  - [ ] 12.5 Implement worker entry point
    - Create src/worker/index.ts
    - Initialize database connection
    - Load SMTP/IMAP configuration from database
    - Start health check interval
    - Start queue processor
    - Handle graceful shutdown on SIGTERM/SIGINT
    - Implement reconnection logic for database failures
    - _Requirements: 11.1, 26.1, 26.4, 26.5_
  
  - [ ]* 12.6 Write unit tests for worker components
    - Test rate limiter enforcement
    - Test personalization token replacement
    - Test SMTP multipart message construction
    - Test error handling for failed sends
    - _Requirements: 11.8, 11.9, 11.10, 12.1_

- [ ] 13. Queue management and retry functionality
  - [ ] 13.1 Implement retry functionality in queue service
    - Add retryFailedEmails function to queueService
    - Reset delivery_status to 'queued' for failed entries
    - Increment retry_count
    - Support retry for specific campaign or specific recipients
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5_
  
  - [ ] 13.2 Create retry API route
    - Create app/api/queue/retry/route.ts (POST)
    - Accept campaignId and optional recipientIds
    - Call retry service function
    - Return count of retried emails
    - _Requirements: 16.1, 16.2_
  
  - [ ] 13.3 Add retry UI to recipient report page
    - Add "Retry Failed" button to campaign detail page
    - Implement confirmation dialog
    - Show success message with retry count
    - Refresh recipient report after retry
    - _Requirements: 16.1_

- [ ] 14. Settings pages for SMTP/IMAP configuration
  - [ ] 14.1 Build SMTP configuration page
    - Create app/(dashboard)/settings/smtp/page.tsx
    - Create SMTPConfigForm component with inputs: host, port, username, password, encryption type
    - Add "Test Connection" button
    - Add "Save Configuration" button
    - Display connection test results
    - Mask password in display, show placeholder when existing config loaded
    - _Requirements: 2.1, 2.3, 2.4_
  
  - [ ] 14.2 Build IMAP configuration page
    - Create app/(dashboard)/settings/imap/page.tsx
    - Create IMAPConfigForm component with inputs: host, port, username, password, encryption type, sent folder name
    - Add "Test Connection" button
    - Add "Save Configuration" button
    - Display connection test results
    - Mask password in display, show placeholder when existing config loaded
    - _Requirements: 3.1, 3.3, 3.4, 3.7_
  
  - [ ] 14.3 Implement configuration API routes
    - Create app/api/config/smtp/route.ts (GET, POST)
    - Create app/api/config/imap/route.ts (GET, POST)
    - Test connections before saving
    - Return masked credentials on GET requests
    - _Requirements: 2.2, 2.3, 2.4, 3.2, 3.3, 3.4_
  
  - [ ]* 14.4 Write integration tests for configuration
    - Test SMTP connection validation
    - Test IMAP connection validation
    - Test configuration save and retrieval
    - Test credential encryption
    - _Requirements: 2.3, 2.5, 3.3, 3.5_

- [ ] 15. Checkpoint - Core features complete
  - Ensure campaigns can be created, sent, and monitored
  - Verify background worker processes queue correctly
  - Test rate limiting functionality
  - Confirm SMTP/IMAP integration works
  - Ensure retry functionality works for failed emails
  - Ask the user if questions arise

- [ ] 16. System health and monitoring
  - [ ] 16.1 Implement health check API
    - Create app/api/health/route.ts (GET)
    - Check database connectivity
    - Query worker_heartbeat for worker status
    - Calculate queue size
    - Return health status: healthy, degraded, or unhealthy
    - _Requirements: 30.1, 30.2, 30.3, 30.4, 30.5_
  
  - [ ] 16.2 Add worker status indicator to dashboard
    - Query health API from dashboard page
    - Display worker status with visual indicator (green/red)
    - Show last heartbeat timestamp
    - Display current queue size
    - _Requirements: 30.4, 30.5_
  
  - [ ]* 16.3 Write tests for health monitoring
    - Test health check API responses
    - Test worker heartbeat detection
    - Test queue size calculation
    - _Requirements: 30.1, 30.2, 30.3_

- [ ] 17. Analytics and reporting
  - [ ] 17.1 Implement campaign analytics functions
    - Add calculateSuccessRate to campaign service
    - Add calculateFailureRate to campaign service
    - Add calculateAverageProcessingTime to campaign service
    - Add calculateTotalProcessingTime to campaign service
    - _Requirements: 27.1, 27.2, 27.3, 27.4_
  
  - [ ] 17.2 Add analytics to campaign detail page
    - Display success rate percentage
    - Display failure rate percentage
    - Display average time from queue to sent
    - Display total processing time for completed campaigns
    - _Requirements: 27.1, 27.2, 27.3, 27.4_
  
  - [ ] 17.3 Implement CSV export for recipient reports
    - Add exportRecipientReportCSV function to campaign service
    - Create download handler in recipient report page
    - Include all columns: name, email, status, sent timestamp, error message, retry count
    - _Requirements: 15.8_

- [ ] 18. Security hardening
  - [ ] 18.1 Implement CSRF protection
    - Add CSRF token generation to session creation
    - Create middleware to validate CSRF tokens on state-changing requests
    - Include CSRF token in all forms and API calls
    - _Requirements: 20.6_
  
  - [ ] 18.2 Implement input sanitization
    - Add HTML sanitization for campaign bodies using DOMPurify
    - Ensure all database queries use parameterized statements
    - Add request validation middleware using Zod schemas
    - _Requirements: 20.4, 20.5_
  
  - [ ] 18.3 Configure secure session cookies
    - Set httpOnly, secure, sameSite flags on session cookies
    - Configure appropriate cookie expiration
    - _Requirements: 20.7_
  
  - [ ]* 18.4 Perform security audit
    - Test for SQL injection vulnerabilities
    - Test for XSS vulnerabilities
    - Verify CSRF protection
    - Verify password hashing and encryption
    - _Requirements: 20.1, 20.2, 20.4, 20.5, 20.6, 20.7_

- [ ] 19. Error handling and logging
  - [ ] 19.1 Implement logging utility
    - Create lib/utils/logger.ts with Winston or similar
    - Configure log levels (info, warn, error)
    - Implement file-based logging with daily rotation
    - Add structured logging format
    - _Requirements: 21.5, 21.6_
  
  - [ ] 19.2 Add logging to critical operations
    - Log all authentication attempts
    - Log SMTP/IMAP connection attempts
    - Log email processing events in worker
    - Log unhandled exceptions with stack traces
    - Log worker startup/shutdown events
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.7_
  
  - [ ] 19.3 Implement error handling middleware
    - Create lib/middleware/errorHandler.ts
    - Catch and log unhandled exceptions
    - Return generic error messages to clients
    - Send detailed errors to logs
    - _Requirements: 21.4_
  
  - [ ]* 19.4 Test error handling and logging
    - Verify all critical operations are logged
    - Test error handling for various failure scenarios
    - Verify log rotation works correctly
    - _Requirements: 21.1, 21.2, 21.3, 21.4_

- [ ] 20. Performance optimization
  - [ ] 20.1 Optimize database queries
    - Add indexes to frequently queried columns (already defined in schema)
    - Implement query result caching where appropriate
    - Use SELECT with specific columns instead of SELECT *
    - _Requirements: 22.4, 22.5_
  
  - [ ] 20.2 Optimize contact import performance
    - Implement batch inserts for contact import
    - Use transactions for atomic import operations
    - Add progress feedback during large imports
    - _Requirements: 22.2_
  
  - [ ]* 20.3 Perform load testing
    - Test dashboard load time under normal load
    - Test contact import with 10,000 rows
    - Test recipient report display with 10,000 recipients
    - Verify performance meets requirements
    - _Requirements: 22.1, 22.2, 22.3_

- [ ] 21. Deployment preparation
  - [ ] 21.1 Create deployment documentation
    - Write comprehensive README.md with installation instructions
    - Document environment variables in .env.example
    - Provide step-by-step setup guide
    - Include troubleshooting section
    - _Requirements: 23.1, 23.3_
  
  - [ ] 21.2 Create database setup scripts
    - Create migration script that runs all SQL schema files
    - Create script to create initial administrator account
    - Document phpMyAdmin setup instructions
    - _Requirements: 23.2, 23.5, 23.6_
  
  - [ ] 21.3 Configure worker deployment
    - Create PM2 configuration file
    - Create systemd service file
    - Create Dockerfile for worker
    - Document worker deployment options
    - _Requirements: 23.4_
  
  - [ ] 21.4 Configure production settings
    - Set up production environment variables
    - Configure HTTPS settings
    - Set secure cookie flags for production
    - Configure CORS settings
    - _Requirements: 20.3_

- [ ] 22. Testing and quality assurance
  - [ ]* 22.1 End-to-end testing
    - Test complete campaign creation and sending flow
    - Test contact import and campaign recipient selection
    - Test authentication and session management
    - Test SMTP/IMAP configuration and connection testing
    - Test recipient reporting and retry functionality
    - _Requirements: All_
  
  - [ ]* 22.2 Browser compatibility testing
    - Test on Chrome 100+
    - Test on Firefox 100+
    - Test on Safari 15+
    - Test on Edge 100+
    - Test responsive design on different screen widths
    - _Requirements: 24.1, 24.2, 24.3, 24.4, 24.5_
  
  - [ ]* 22.3 Worker resilience testing
    - Test worker recovery from database disconnection
    - Test worker handling of SMTP failures
    - Test worker handling of IMAP failures
    - Test worker automatic restart after crash
    - _Requirements: 26.1, 26.2, 26.3, 26.4, 26.5, 26.6_

- [ ] 23. Final checkpoint and deployment
  - Review all implemented features against requirements
  - Verify all security measures are in place
  - Confirm performance requirements are met
  - Validate browser compatibility
  - Test deployment process in staging environment
  - Prepare for production deployment
  - Ask the user if questions arise

## Notes

- Tasks marked with `*` are optional testing tasks and can be skipped for faster MVP delivery
- Each task references specific requirements from the requirements document for traceability
- The implementation follows a bottom-up approach: infrastructure → data layer → business logic → API → UI
- Checkpoints are included at logical breaks to validate progress and catch issues early
- The background worker is implemented as a separate module but shares the codebase with the web application
- Security measures are integrated throughout the implementation, not added as an afterthought
- All database operations use parameterized queries to prevent SQL injection
- Password hashing (bcrypt) and credential encryption (AES-256) are implemented early in the security utilities
- The system is designed for horizontal scalability: multiple worker processes can run in parallel
- SMTP/IMAP configurations are stored encrypted and loaded at worker startup
- Rate limiting is enforced at the worker level with configurable limits

## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1"]
    },
    {
      "id": 1,
      "tasks": ["2.1", "2.2"]
    },
    {
      "id": 2,
      "tasks": ["2.3", "3.1", "3.2"]
    },
    {
      "id": 3,
      "tasks": ["3.3", "4.1", "4.2"]
    },
    {
      "id": 4,
      "tasks": ["4.3", "4.4", "4.5", "4.6"]
    },
    {
      "id": 5,
      "tasks": ["4.7", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6"]
    },
    {
      "id": 6,
      "tasks": ["6.7", "7.1", "7.2"]
    },
    {
      "id": 7,
      "tasks": ["7.3", "7.4"]
    },
    {
      "id": 8,
      "tasks": ["8.1", "8.2", "8.3"]
    },
    {
      "id": 9,
      "tasks": ["9.1", "9.2", "9.3"]
    },
    {
      "id": 10,
      "tasks": ["9.4", "9.5"]
    },
    {
      "id": 11,
      "tasks": ["11.1", "11.2", "11.3", "11.4"]
    },
    {
      "id": 12,
      "tasks": ["11.5", "11.6"]
    },
    {
      "id": 13,
      "tasks": ["11.7", "12.1", "12.2"]
    },
    {
      "id": 14,
      "tasks": ["12.3", "12.4"]
    },
    {
      "id": 15,
      "tasks": ["12.5", "12.6"]
    },
    {
      "id": 16,
      "tasks": ["13.1", "13.2"]
    },
    {
      "id": 17,
      "tasks": ["13.3", "14.1", "14.2"]
    },
    {
      "id": 18,
      "tasks": ["14.3", "14.4"]
    },
    {
      "id": 19,
      "tasks": ["16.1", "16.2"]
    },
    {
      "id": 20,
      "tasks": ["16.3", "17.1"]
    },
    {
      "id": 21,
      "tasks": ["17.2", "17.3", "18.1", "18.2", "18.3"]
    },
    {
      "id": 22,
      "tasks": ["18.4", "19.1"]
    },
    {
      "id": 23,
      "tasks": ["19.2", "19.3"]
    },
    {
      "id": 24,
      "tasks": ["19.4", "20.1", "20.2"]
    },
    {
      "id": 25,
      "tasks": ["20.3", "21.1", "21.2", "21.3", "21.4"]
    },
    {
      "id": 26,
      "tasks": ["22.1", "22.2", "22.3"]
    }
  ]
}
```
