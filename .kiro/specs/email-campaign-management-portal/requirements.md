# Requirements Document

## Introduction

The Email Campaign Management Portal is a web-based system that enables administrators to create, send, and track email campaigns to multiple recipients. The system provides SMTP/IMAP integration, contact management, campaign composition with personalization, queue-based email processing, and comprehensive recipient-level reporting. The portal ensures secure authentication, rate-limited email delivery, and synchronization of sent emails to the configured IMAP Sent folder.

## Glossary

- **Portal**: The Email Campaign Management Portal web application
- **Administrator**: An authenticated user with access to the Portal
- **Campaign**: A collection of personalized emails to be sent to multiple recipients
- **Recipient**: An individual contact who will receive campaign emails
- **Contact**: A stored record containing recipient information (name, email, custom fields)
- **Queue**: A persistent storage mechanism for pending email delivery tasks
- **Background_Worker**: A continuous process that processes queued email delivery tasks
- **SMTP_Server**: Simple Mail Transfer Protocol server used for sending emails
- **IMAP_Server**: Internet Message Access Protocol server used for accessing mailboxes
- **Sent_Folder**: The IMAP folder where sent campaign emails are synchronized
- **Personalization_Token**: A placeholder in email content replaced with recipient-specific data
- **Rate_Limit**: The maximum number of emails sent per minute (5-10 emails)
- **Session**: An authenticated state maintained between the Portal and Administrator
- **Database**: The MySQL database accessed via phpMyAdmin
- **Email_Template**: The content structure of a campaign including subject and body
- **Delivery_Status**: The current state of an email (queued, sending, sent, failed)
- **HTML_Email**: Email content formatted with HTML markup
- **Plain_Text_Email**: Email content without formatting
- **Excel_File**: A spreadsheet file with .xlsx or .xls extension containing contact data
- **CSV_File**: A comma-separated values file containing contact data
- **SMTP_Configuration**: Settings for connecting to an SMTP_Server
- **IMAP_Configuration**: Settings for connecting to an IMAP_Server

## Requirements

### Requirement 1: Administrator Authentication

**User Story:** As an administrator, I want to securely log in to the Portal, so that only authorized users can access campaign management features.

#### Acceptance Criteria

1. THE Portal SHALL provide a login page requiring username and password
2. WHEN an Administrator submits valid credentials, THE Portal SHALL create a Session
3. WHEN an Administrator submits invalid credentials, THE Portal SHALL display an error message and deny access
4. WHILE a Session is active, THE Portal SHALL allow access to all campaign management features
5. THE Portal SHALL store authentication credentials securely using password hashing
6. WHEN an Administrator logs out, THE Portal SHALL terminate the Session
7. WHEN a Session expires after 24 hours of inactivity, THE Portal SHALL require re-authentication

### Requirement 2: SMTP Configuration Management

**User Story:** As an administrator, I want to configure SMTP server settings, so that the Portal can send emails through my email provider.

#### Acceptance Criteria

1. THE Portal SHALL provide an interface to input SMTP_Configuration including host, port, username, password, and encryption type
2. THE Portal SHALL store SMTP_Configuration in the Database
3. WHEN an Administrator saves SMTP_Configuration, THE Portal SHALL validate connectivity to the SMTP_Server
4. IF SMTP_Server connectivity fails, THEN THE Portal SHALL display an error message with connection details
5. THE Portal SHALL encrypt SMTP credentials before storing in the Database
6. THE Portal SHALL support TLS and SSL encryption types for SMTP_Server connections

### Requirement 3: IMAP Configuration Management

**User Story:** As an administrator, I want to configure IMAP server settings, so that sent emails can be synchronized to my Sent folder.

#### Acceptance Criteria

1. THE Portal SHALL provide an interface to input IMAP_Configuration including host, port, username, password, encryption type, and Sent_Folder name
2. THE Portal SHALL store IMAP_Configuration in the Database
3. WHEN an Administrator saves IMAP_Configuration, THE Portal SHALL validate connectivity to the IMAP_Server
4. IF IMAP_Server connectivity fails, THEN THE Portal SHALL display an error message with connection details
5. THE Portal SHALL encrypt IMAP credentials before storing in the Database
6. THE Portal SHALL support TLS and SSL encryption types for IMAP_Server connections
7. THE Portal SHALL verify the specified Sent_Folder exists on the IMAP_Server

### Requirement 4: Contact Import from Excel

**User Story:** As an administrator, I want to import contacts from Excel files, so that I can quickly add multiple recipients to the system.

#### Acceptance Criteria

1. THE Portal SHALL provide a file upload interface accepting Excel_File formats (.xlsx, .xls)
2. WHEN an Administrator uploads an Excel_File, THE Portal SHALL parse the file and extract contact data
3. THE Portal SHALL map column headers to contact fields (name, email, custom fields)
4. THE Portal SHALL validate email addresses in the imported data using RFC 5322 format
5. WHEN an imported email address is invalid, THE Portal SHALL mark the row as failed and continue processing
6. WHEN import completes, THE Portal SHALL display a summary showing successful imports, failed rows, and duplicate emails
7. THE Portal SHALL store imported contacts in the Database
8. IF an imported email already exists, THEN THE Portal SHALL update the existing contact record

### Requirement 5: Contact Import from CSV

**User Story:** As an administrator, I want to import contacts from CSV files, so that I can add recipients from various data sources.

#### Acceptance Criteria

1. THE Portal SHALL provide a file upload interface accepting CSV_File format
2. WHEN an Administrator uploads a CSV_File, THE Portal SHALL parse the file and extract contact data
3. THE Portal SHALL detect CSV delimiter (comma, semicolon, tab) automatically
4. THE Portal SHALL map column headers to contact fields (name, email, custom fields)
5. THE Portal SHALL validate email addresses in the imported data using RFC 5322 format
6. WHEN an imported email address is invalid, THE Portal SHALL mark the row as failed and continue processing
7. WHEN import completes, THE Portal SHALL display a summary showing successful imports, failed rows, and duplicate emails
8. THE Portal SHALL store imported contacts in the Database
9. IF an imported email already exists, THEN THE Portal SHALL update the existing contact record

### Requirement 6: Manual Contact Management

**User Story:** As an administrator, I want to manually add, edit, and delete contacts, so that I can maintain accurate recipient lists.

#### Acceptance Criteria

1. THE Portal SHALL provide an interface to create a new Contact with name, email, and custom fields
2. THE Portal SHALL validate email addresses using RFC 5322 format before saving
3. THE Portal SHALL provide an interface to edit existing Contact records
4. THE Portal SHALL provide an interface to delete Contact records
5. WHEN a Contact is deleted, THE Portal SHALL remove the record from the Database
6. THE Portal SHALL display a searchable list of all contacts with pagination
7. THE Portal SHALL allow filtering contacts by custom field values

### Requirement 7: Campaign Creation

**User Story:** As an administrator, I want to create email campaigns with personalized content, so that I can send targeted messages to multiple recipients.

#### Acceptance Criteria

1. THE Portal SHALL provide an interface to create a Campaign with name, subject, HTML_Email body, and Plain_Text_Email body
2. THE Portal SHALL provide a rich text editor for composing HTML_Email content
3. THE Portal SHALL provide a plain text editor for composing Plain_Text_Email content
4. THE Portal SHALL support Personalization_Token syntax using double curly braces (e.g., {{name}}, {{email}})
5. THE Portal SHALL display available Personalization_Token options based on contact fields
6. THE Portal SHALL validate that both HTML_Email and Plain_Text_Email bodies are provided
7. THE Portal SHALL store Campaign details in the Database
8. THE Portal SHALL allow saving campaigns as drafts without sending

### Requirement 8: Campaign Recipient Selection

**User Story:** As an administrator, I want to select which contacts receive a campaign, so that I can target specific audiences.

#### Acceptance Criteria

1. THE Portal SHALL provide an interface to select recipients for a Campaign
2. THE Portal SHALL allow selecting individual contacts from a list
3. THE Portal SHALL allow selecting all contacts with a single action
4. THE Portal SHALL display the total number of selected recipients
5. THE Portal SHALL allow filtering contacts before selection using search criteria
6. THE Portal SHALL prevent sending a Campaign with zero recipients
7. THE Portal SHALL store the association between Campaign and recipients in the Database

### Requirement 9: Campaign Preview

**User Story:** As an administrator, I want to preview how emails will appear to recipients, so that I can verify personalization and formatting before sending.

#### Acceptance Criteria

1. THE Portal SHALL provide a preview function for campaigns before sending
2. WHEN an Administrator previews a Campaign, THE Portal SHALL display both HTML_Email and Plain_Text_Email versions
3. THE Portal SHALL replace Personalization_Token values with sample data from a selected Recipient
4. THE Portal SHALL allow selecting different recipients for preview
5. THE Portal SHALL render HTML_Email content as it would appear in an email client

### Requirement 10: Campaign Queue Processing

**User Story:** As an administrator, I want campaigns to be queued for background processing, so that sending large campaigns does not block the interface.

#### Acceptance Criteria

1. WHEN an Administrator sends a Campaign, THE Portal SHALL create queue entries for each Recipient
2. THE Portal SHALL store each queue entry in the Database with Campaign ID, Recipient ID, and Delivery_Status of "queued"
3. THE Portal SHALL return control to the Administrator immediately after queuing
4. THE Portal SHALL display a confirmation message indicating the Campaign has been queued
5. THE Portal SHALL record the queue timestamp for each entry

### Requirement 11: Background Worker Email Processing

**User Story:** As a system operator, I want a continuous background worker to process queued emails, so that campaigns are delivered reliably without manual intervention.

#### Acceptance Criteria

1. THE Background_Worker SHALL run as a continuous process independent of web requests
2. THE Background_Worker SHALL query the Database for queue entries with Delivery_Status "queued"
3. WHEN the Background_Worker finds queued entries, THE Background_Worker SHALL process them in first-in-first-out order
4. THE Background_Worker SHALL update Delivery_Status to "sending" before processing each entry
5. THE Background_Worker SHALL retrieve the Email_Template from the Campaign
6. THE Background_Worker SHALL replace Personalization_Token values with Recipient-specific data
7. THE Background_Worker SHALL send individual SMTP messages (one per Recipient)
8. THE Background_Worker SHALL respect the Rate_Limit of 5-10 emails per minute
9. WHEN an email is sent successfully, THE Background_Worker SHALL update Delivery_Status to "sent" and record the sent timestamp
10. IF email sending fails, THEN THE Background_Worker SHALL update Delivery_Status to "failed" and record the error message
11. THE Background_Worker SHALL continue processing without stopping when individual emails fail
12. THE Background_Worker SHALL include both HTML_Email and Plain_Text_Email content in each SMTP message as multipart/alternative

### Requirement 12: Rate Limiting

**User Story:** As a system operator, I want email sending to be rate-limited, so that SMTP servers are not overwhelmed and provider limits are respected.

#### Acceptance Criteria

1. THE Background_Worker SHALL enforce a Rate_Limit between 5 and 10 emails per minute
2. THE Portal SHALL provide a configuration setting to adjust the Rate_Limit within the 5-10 emails per minute range
3. WHEN the Rate_Limit is reached within a minute, THE Background_Worker SHALL pause processing until the next minute begins
4. THE Background_Worker SHALL track the number of emails sent within the current minute
5. THE Background_Worker SHALL reset the counter at the start of each new minute

### Requirement 13: Sent Folder Synchronization

**User Story:** As an administrator, I want sent campaign emails to appear in my IMAP Sent folder, so that I have a complete record in my email client.

#### Acceptance Criteria

1. WHEN the Background_Worker successfully sends an email, THE Background_Worker SHALL copy the message to the Sent_Folder on the IMAP_Server
2. THE Background_Worker SHALL use IMAP APPEND command to store the message
3. THE Background_Worker SHALL preserve the sent timestamp when copying to Sent_Folder
4. IF IMAP synchronization fails, THEN THE Background_Worker SHALL log the error but maintain Delivery_Status as "sent"
5. THE Background_Worker SHALL include complete email headers in the synchronized message

### Requirement 14: Campaign Dashboard

**User Story:** As an administrator, I want to view all campaigns in a dashboard, so that I can monitor campaign status and performance.

#### Acceptance Criteria

1. THE Portal SHALL provide a dashboard displaying all campaigns with name, creation date, and status
2. THE Portal SHALL calculate and display total recipients for each Campaign
3. THE Portal SHALL calculate and display the count of emails with Delivery_Status "sent" for each Campaign
4. THE Portal SHALL calculate and display the count of emails with Delivery_Status "failed" for each Campaign
5. THE Portal SHALL calculate and display the count of emails with Delivery_Status "queued" or "sending" for each Campaign
6. THE Portal SHALL allow sorting campaigns by creation date
7. THE Portal SHALL provide pagination for the campaign list

### Requirement 15: Recipient-Level Reporting

**User Story:** As an administrator, I want to see delivery status for each recipient in a campaign, so that I can identify and resolve delivery issues.

#### Acceptance Criteria

1. WHEN an Administrator views a Campaign, THE Portal SHALL display a list of all recipients
2. THE Portal SHALL display Delivery_Status for each Recipient (queued, sending, sent, failed)
3. THE Portal SHALL display the sent timestamp for each Recipient with Delivery_Status "sent"
4. WHERE Delivery_Status is "failed", THE Portal SHALL display the error message
5. THE Portal SHALL allow filtering recipients by Delivery_Status
6. THE Portal SHALL allow searching recipients by name or email
7. THE Portal SHALL provide pagination for the recipient list
8. THE Portal SHALL allow exporting the recipient report as CSV_File

### Requirement 16: Failed Email Retry

**User Story:** As an administrator, I want to retry failed emails, so that temporary issues do not prevent successful delivery.

#### Acceptance Criteria

1. WHERE a Campaign has emails with Delivery_Status "failed", THE Portal SHALL provide a retry action
2. WHEN an Administrator retries failed emails, THE Portal SHALL update Delivery_Status to "queued" for all failed entries
3. THE Background_Worker SHALL process retried emails following normal queue processing rules
4. THE Portal SHALL record retry attempts in the Database
5. THE Portal SHALL display retry count for each Recipient

### Requirement 17: Campaign Deletion

**User Story:** As an administrator, I want to delete campaigns, so that I can remove outdated or test campaigns from the system.

#### Acceptance Criteria

1. THE Portal SHALL provide a delete action for campaigns
2. WHEN an Administrator deletes a Campaign, THE Portal SHALL prompt for confirmation
3. WHEN deletion is confirmed, THE Portal SHALL remove the Campaign and all associated queue entries from the Database
4. THE Portal SHALL prevent deletion of campaigns with emails currently in "sending" status
5. THE Portal SHALL display a success message after deletion

### Requirement 18: Database Schema

**User Story:** As a system operator, I want a complete MySQL database schema, so that all application data is properly structured and accessible via phpMyAdmin.

#### Acceptance Criteria

1. THE Database SHALL include a table "administrators" with columns: id, username, password_hash, created_at, updated_at
2. THE Database SHALL include a table "smtp_configurations" with columns: id, host, port, username, password_encrypted, encryption_type, created_at, updated_at
3. THE Database SHALL include a table "imap_configurations" with columns: id, host, port, username, password_encrypted, encryption_type, sent_folder_name, created_at, updated_at
4. THE Database SHALL include a table "contacts" with columns: id, name, email, custom_fields_json, created_at, updated_at
5. THE Database SHALL include a table "campaigns" with columns: id, name, subject, html_body, plain_text_body, status, created_at, updated_at
6. THE Database SHALL include a table "campaign_recipients" with columns: id, campaign_id, contact_id, created_at
7. THE Database SHALL include a table "email_queue" with columns: id, campaign_id, recipient_id, delivery_status, personalized_subject, personalized_html_body, personalized_plain_text_body, error_message, retry_count, queued_at, sent_at, updated_at
8. THE Database SHALL include a table "sessions" with columns: id, administrator_id, session_token, expires_at, created_at
9. THE Database SHALL enforce unique constraints on administrators.username and contacts.email
10. THE Database SHALL use InnoDB storage engine for transactional integrity
11. THE Database SHALL define foreign key relationships: campaign_recipients.campaign_id → campaigns.id, campaign_recipients.contact_id → contacts.id, email_queue.campaign_id → campaigns.id, email_queue.recipient_id → contacts.id, sessions.administrator_id → administrators.id

### Requirement 19: Technology Stack

**User Story:** As a developer, I want to use modern, well-supported technologies, so that the Portal is maintainable and performant.

#### Acceptance Criteria

1. THE Portal SHALL be built using Next.js framework with TypeScript
2. THE Portal SHALL use Tailwind CSS for styling
3. THE Portal SHALL use shadcn/ui component library for UI components
4. THE Portal SHALL use MySQL as the Database accessed via phpMyAdmin
5. THE Portal SHALL use a MySQL client library compatible with Next.js
6. THE Background_Worker SHALL be implemented as a Node.js process with TypeScript
7. THE Portal SHALL use established SMTP and IMAP client libraries for email operations

### Requirement 20: Security

**User Story:** As a system operator, I want the Portal to implement security best practices, so that sensitive data and operations are protected.

#### Acceptance Criteria

1. THE Portal SHALL hash all passwords using bcrypt with a minimum cost factor of 10
2. THE Portal SHALL encrypt SMTP and IMAP credentials using AES-256 encryption before database storage
3. THE Portal SHALL use HTTPS for all web traffic in production environments
4. THE Portal SHALL validate and sanitize all user inputs to prevent SQL injection
5. THE Portal SHALL validate and sanitize all user inputs to prevent cross-site scripting attacks
6. THE Portal SHALL implement CSRF protection for all state-changing operations
7. THE Portal SHALL set secure, httpOnly, and sameSite flags on Session cookies
8. THE Portal SHALL enforce password complexity requirements: minimum 8 characters, at least one uppercase letter, one lowercase letter, one number
9. THE Portal SHALL require authentication for all routes except the login page

### Requirement 21: Error Handling and Logging

**User Story:** As a system operator, I want comprehensive error handling and logging, so that I can diagnose and resolve issues quickly.

#### Acceptance Criteria

1. THE Portal SHALL log all authentication attempts with timestamp, username, and outcome
2. THE Portal SHALL log all SMTP and IMAP connection attempts with timestamp and outcome
3. THE Background_Worker SHALL log each email processing event with timestamp, Campaign ID, Recipient ID, and outcome
4. IF an unhandled exception occurs, THEN THE Portal SHALL log the full stack trace and display a generic error message to the Administrator
5. THE Portal SHALL store logs in a file system location accessible to system operators
6. THE Portal SHALL rotate log files daily to prevent excessive file sizes
7. THE Background_Worker SHALL log startup and shutdown events

### Requirement 22: Performance

**User Story:** As an administrator, I want the Portal to respond quickly, so that I can work efficiently.

#### Acceptance Criteria

1. THE Portal SHALL load the campaign dashboard within 2 seconds under normal load
2. THE Portal SHALL process contact imports of up to 10,000 rows within 30 seconds
3. THE Portal SHALL display recipient-level reports for campaigns with up to 10,000 recipients within 3 seconds
4. THE Database SHALL use indexes on frequently queried columns: contacts.email, email_queue.delivery_status, email_queue.campaign_id, campaigns.created_at
5. THE Portal SHALL implement database connection pooling to optimize query performance

### Requirement 23: Deployment

**User Story:** As a system operator, I want clear deployment procedures, so that the Portal can be installed and maintained reliably.

#### Acceptance Criteria

1. THE Portal SHALL provide a README file with installation instructions
2. THE Portal SHALL provide database migration scripts to create the complete schema
3. THE Portal SHALL provide environment variable documentation for configuration
4. THE Portal SHALL support running the Background_Worker as a system service (systemd, PM2, or Docker)
5. THE Portal SHALL provide a script to create the initial administrator account
6. THE Portal SHALL include instructions for configuring phpMyAdmin to access the Database

### Requirement 24: Browser Compatibility

**User Story:** As an administrator, I want the Portal to work on modern browsers, so that I can access it from different devices.

#### Acceptance Criteria

1. THE Portal SHALL function correctly on Chrome version 100 or later
2. THE Portal SHALL function correctly on Firefox version 100 or later
3. THE Portal SHALL function correctly on Safari version 15 or later
4. THE Portal SHALL function correctly on Edge version 100 or later
5. THE Portal SHALL render responsively on screen widths from 1024 pixels to 1920 pixels

### Requirement 25: Email Content Validation

**User Story:** As an administrator, I want the Portal to validate email content, so that I avoid common sending mistakes.

#### Acceptance Criteria

1. WHEN an Administrator creates a Campaign, THE Portal SHALL validate that subject is not empty
2. WHEN an Administrator creates a Campaign, THE Portal SHALL validate that HTML_Email body is not empty
3. WHEN an Administrator creates a Campaign, THE Portal SHALL validate that Plain_Text_Email body is not empty
4. THE Portal SHALL identify Personalization_Token values in email content
5. WHEN a Personalization_Token references a non-existent contact field, THE Portal SHALL display a warning
6. THE Portal SHALL display a character count for subject lines
7. WHEN subject line exceeds 78 characters, THE Portal SHALL display a warning about potential truncation

### Requirement 26: Background Worker Resilience

**User Story:** As a system operator, I want the Background Worker to handle failures gracefully, so that temporary issues do not stop campaign processing.

#### Acceptance Criteria

1. IF the Background_Worker loses Database connection, THEN THE Background_Worker SHALL attempt reconnection every 30 seconds
2. IF the Background_Worker loses SMTP_Server connection during sending, THEN THE Background_Worker SHALL mark the current email as failed and continue processing the next entry
3. IF the Background_Worker loses IMAP_Server connection during synchronization, THEN THE Background_Worker SHALL log the error and continue processing the next entry
4. THE Background_Worker SHALL continue running indefinitely until explicitly stopped
5. WHEN the Background_Worker starts, THE Background_Worker SHALL log the startup event and resume processing queued entries
6. IF the Background_Worker process crashes, THEN THE Background_Worker SHALL be automatically restarted by the process manager

### Requirement 27: Campaign Analytics

**User Story:** As an administrator, I want to see aggregate statistics for campaigns, so that I can evaluate campaign performance.

#### Acceptance Criteria

1. THE Portal SHALL calculate and display success rate (sent / total recipients) for each Campaign
2. THE Portal SHALL calculate and display failure rate (failed / total recipients) for each Campaign
3. THE Portal SHALL calculate and display average time from queue to sent for each Campaign
4. THE Portal SHALL calculate and display total processing time for completed campaigns
5. THE Portal SHALL provide a summary view showing totals across all campaigns: total sent, total failed, total queued

### Requirement 28: Contact Custom Fields

**User Story:** As an administrator, I want to store custom fields for contacts, so that I can personalize emails beyond name and email.

#### Acceptance Criteria

1. THE Portal SHALL allow defining custom field names when importing contacts
2. THE Portal SHALL store custom fields as JSON in the Database contacts.custom_fields_json column
3. THE Portal SHALL display custom fields when viewing or editing a Contact
4. THE Portal SHALL allow using custom fields as Personalization_Token values in campaigns
5. WHEN a Personalization_Token references a custom field that does not exist for a Recipient, THE Background_Worker SHALL replace it with an empty string

### Requirement 29: Multipart Email Format

**User Story:** As an administrator, I want emails to include both HTML and plain text versions, so that recipients with different email clients can view content appropriately.

#### Acceptance Criteria

1. THE Background_Worker SHALL construct SMTP messages using multipart/alternative MIME format
2. THE Background_Worker SHALL include Plain_Text_Email as the first alternative
3. THE Background_Worker SHALL include HTML_Email as the second alternative
4. THE Background_Worker SHALL set appropriate Content-Type headers for each alternative
5. THE Background_Worker SHALL ensure character encoding is UTF-8 for both alternatives

### Requirement 30: System Health Monitoring

**User Story:** As a system operator, I want to monitor system health, so that I can ensure continuous operation.

#### Acceptance Criteria

1. THE Portal SHALL provide a health check endpoint returning HTTP 200 when operational
2. THE Portal SHALL include Database connectivity in the health check
3. THE Background_Worker SHALL update a heartbeat timestamp in the Database every 60 seconds
4. THE Portal SHALL display Background_Worker status based on heartbeat freshness (active if updated within 2 minutes)
5. THE Portal SHALL display current queue size (count of entries with Delivery_Status "queued")
