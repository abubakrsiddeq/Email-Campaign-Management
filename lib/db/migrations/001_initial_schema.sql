-- =====================================================================
-- Email Campaign Management Portal - Initial Database Schema
-- =====================================================================
-- Database: email_campaign_portal
-- Engine: InnoDB for transactional integrity
-- Charset: utf8mb4 for full Unicode support
-- 
-- This migration creates all 9 tables required for the system:
-- 1. administrators - System user authentication
-- 2. smtp_configurations - SMTP server settings for sending emails
-- 3. imap_configurations - IMAP server settings for sent folder sync
-- 4. contacts - Recipient contact information
-- 5. campaigns - Email campaign definitions
-- 6. campaign_recipients - Many-to-many relationship between campaigns and contacts
-- 7. email_queue - Queue for email processing with delivery status
-- 8. sessions - Administrator session management
-- 9. worker_heartbeat - Background worker health monitoring
-- =====================================================================

-- =====================================================================
-- Table 1: administrators
-- Purpose: Stores administrator accounts with secure password hashing
-- Requirements: 18.1, 1.1, 1.2, 1.3, 1.5
-- =====================================================================
CREATE TABLE IF NOT EXISTS administrators (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique administrator identifier',
    username VARCHAR(255) NOT NULL UNIQUE COMMENT 'Login username, must be unique',
    password_hash VARCHAR(255) NOT NULL COMMENT 'Bcrypt hashed password (cost factor 10+)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Account creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    INDEX idx_username (username) COMMENT 'Fast lookup during authentication'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Administrator accounts for portal authentication';

-- =====================================================================
-- Table 2: smtp_configurations
-- Purpose: Stores SMTP server settings with encrypted credentials
-- Requirements: 18.2, 2.1, 2.2, 2.5, 2.6
-- =====================================================================
CREATE TABLE IF NOT EXISTS smtp_configurations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique configuration identifier',
    host VARCHAR(255) NOT NULL COMMENT 'SMTP server hostname or IP address',
    port INT UNSIGNED NOT NULL COMMENT 'SMTP server port (typically 587 for TLS, 465 for SSL)',
    username VARCHAR(255) NOT NULL COMMENT 'SMTP authentication username',
    password_encrypted TEXT NOT NULL COMMENT 'AES-256 encrypted password',
    encryption_type ENUM('TLS', 'SSL') NOT NULL COMMENT 'Encryption protocol for SMTP connection',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Configuration creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='SMTP server configuration for sending campaign emails';

-- =====================================================================
-- Table 3: imap_configurations
-- Purpose: Stores IMAP server settings for sent folder synchronization
-- Requirements: 18.3, 3.1, 3.2, 3.5, 3.6, 3.7
-- =====================================================================
CREATE TABLE IF NOT EXISTS imap_configurations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique configuration identifier',
    host VARCHAR(255) NOT NULL COMMENT 'IMAP server hostname or IP address',
    port INT UNSIGNED NOT NULL COMMENT 'IMAP server port (typically 993 for TLS)',
    username VARCHAR(255) NOT NULL COMMENT 'IMAP authentication username',
    password_encrypted TEXT NOT NULL COMMENT 'AES-256 encrypted password',
    encryption_type ENUM('TLS', 'SSL') NOT NULL COMMENT 'Encryption protocol for IMAP connection',
    sent_folder_name VARCHAR(255) NOT NULL DEFAULT 'Sent' COMMENT 'Name of the Sent folder on IMAP server',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Configuration creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='IMAP server configuration for sent email synchronization';

-- =====================================================================
-- Table 4: contacts
-- Purpose: Stores recipient contact information with custom fields
-- Requirements: 18.4, 4.7, 5.8, 6.1, 6.2, 28.1, 28.2
-- =====================================================================
CREATE TABLE IF NOT EXISTS contacts (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique contact identifier',
    name VARCHAR(255) NOT NULL COMMENT 'Contact full name',
    email VARCHAR(255) NOT NULL UNIQUE COMMENT 'Contact email address (RFC 5322 validated, unique)',
    custom_fields_json JSON COMMENT 'Additional contact fields stored as JSON (e.g., company, phone, etc.)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Contact creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    INDEX idx_email (email) COMMENT 'Fast lookup by email address',
    INDEX idx_created_at (created_at) COMMENT 'Efficient sorting by creation date'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Contact records for campaign recipients with custom field support';

-- =====================================================================
-- Table 5: campaigns
-- Purpose: Stores email campaign definitions with templates
-- Requirements: 18.5, 7.1, 7.2, 7.3, 7.7, 7.8
-- =====================================================================
CREATE TABLE IF NOT EXISTS campaigns (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique campaign identifier',
    name VARCHAR(255) NOT NULL COMMENT 'Campaign name for identification',
    subject VARCHAR(255) NOT NULL COMMENT 'Email subject line (supports {{tokens}})',
    html_body MEDIUMTEXT NOT NULL COMMENT 'HTML version of email body (supports {{tokens}})',
    plain_text_body MEDIUMTEXT NOT NULL COMMENT 'Plain text version of email body (supports {{tokens}})',
    status ENUM('draft', 'queued', 'processing', 'completed', 'cancelled') NOT NULL DEFAULT 'draft' COMMENT 'Campaign lifecycle status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Campaign creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    INDEX idx_status (status) COMMENT 'Filter campaigns by status',
    INDEX idx_created_at (created_at) COMMENT 'Sort campaigns by creation date'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Email campaign definitions with HTML and plain text templates';

-- =====================================================================
-- Table 6: campaign_recipients
-- Purpose: Many-to-many relationship between campaigns and contacts
-- Requirements: 18.6, 8.1, 8.2, 8.7
-- =====================================================================
CREATE TABLE IF NOT EXISTS campaign_recipients (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique recipient association identifier',
    campaign_id INT UNSIGNED NOT NULL COMMENT 'Reference to campaign',
    contact_id INT UNSIGNED NOT NULL COMMENT 'Reference to contact (recipient)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Association creation timestamp',
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE COMMENT 'Delete recipients when campaign is deleted',
    FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE COMMENT 'Delete associations when contact is deleted',
    UNIQUE KEY unique_campaign_contact (campaign_id, contact_id) COMMENT 'Prevent duplicate recipients in same campaign',
    INDEX idx_campaign_id (campaign_id) COMMENT 'Fast lookup of recipients for a campaign',
    INDEX idx_contact_id (contact_id) COMMENT 'Fast lookup of campaigns for a contact'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Associates contacts with campaigns as recipients';

-- =====================================================================
-- Table 7: email_queue
-- Purpose: Queue for background email processing with delivery tracking
-- Requirements: 18.7, 10.2, 11.2, 11.4, 11.9, 11.10, 15.2, 15.3, 15.4, 16.2, 16.4
-- =====================================================================
CREATE TABLE IF NOT EXISTS email_queue (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique queue entry identifier',
    campaign_id INT UNSIGNED NOT NULL COMMENT 'Reference to campaign',
    recipient_id INT UNSIGNED NOT NULL COMMENT 'Reference to recipient contact',
    delivery_status ENUM('queued', 'sending', 'sent', 'failed') NOT NULL DEFAULT 'queued' COMMENT 'Current delivery status',
    personalized_subject VARCHAR(255) COMMENT 'Subject with tokens replaced for this recipient',
    personalized_html_body MEDIUMTEXT COMMENT 'HTML body with tokens replaced for this recipient',
    personalized_plain_text_body MEDIUMTEXT COMMENT 'Plain text body with tokens replaced for this recipient',
    error_message TEXT COMMENT 'Error details if delivery_status is failed',
    retry_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Number of retry attempts',
    queued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When email was queued',
    sent_at TIMESTAMP NULL COMMENT 'When email was successfully sent',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last status update timestamp',
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE COMMENT 'Delete queue entries when campaign is deleted',
    FOREIGN KEY (recipient_id) REFERENCES contacts(id) ON DELETE CASCADE COMMENT 'Delete queue entries when contact is deleted',
    INDEX idx_delivery_status (delivery_status) COMMENT 'Critical for worker queries to find queued emails',
    INDEX idx_campaign_id (campaign_id) COMMENT 'Fast retrieval for campaign reports',
    INDEX idx_queued_at (queued_at) COMMENT 'FIFO processing order',
    INDEX idx_sent_at (sent_at) COMMENT 'Analytics and reporting queries'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Email processing queue with personalized content and delivery tracking';

-- =====================================================================
-- Table 8: sessions
-- Purpose: Administrator session management for authentication
-- Requirements: 18.8, 1.2, 1.6, 1.7
-- =====================================================================
CREATE TABLE IF NOT EXISTS sessions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique session identifier',
    administrator_id INT UNSIGNED NOT NULL COMMENT 'Reference to administrator',
    session_token VARCHAR(255) NOT NULL UNIQUE COMMENT 'Cryptographically secure session token',
    expires_at TIMESTAMP NOT NULL COMMENT 'Session expiration timestamp (24 hours from creation)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Session creation timestamp',
    FOREIGN KEY (administrator_id) REFERENCES administrators(id) ON DELETE CASCADE COMMENT 'Delete sessions when administrator is deleted',
    INDEX idx_session_token (session_token) COMMENT 'Fast session validation lookups',
    INDEX idx_expires_at (expires_at) COMMENT 'Efficient cleanup of expired sessions'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Administrator session tokens for authentication';

-- =====================================================================
-- Table 9: worker_heartbeat
-- Purpose: Background worker health monitoring
-- Requirements: 18.9, 30.3, 30.4, 30.5
-- =====================================================================
CREATE TABLE IF NOT EXISTS worker_heartbeat (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique heartbeat record identifier',
    worker_name VARCHAR(255) NOT NULL UNIQUE COMMENT 'Worker process identifier',
    last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last heartbeat update timestamp',
    status ENUM('active', 'stopped') NOT NULL DEFAULT 'active' COMMENT 'Worker operational status'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Background worker health monitoring with heartbeat tracking';

-- =====================================================================
-- End of Initial Schema Migration
-- =====================================================================
-- 
-- NOTES:
-- 1. All tables use InnoDB engine for transaction support and foreign key constraints
-- 2. utf8mb4 charset ensures full Unicode support including emojis
-- 3. Timestamps use DEFAULT CURRENT_TIMESTAMP and ON UPDATE CURRENT_TIMESTAMP where appropriate
-- 4. Indexes are strategically placed on frequently queried columns for performance
-- 5. Foreign keys use ON DELETE CASCADE to maintain referential integrity
-- 6. ENUM types constrain status values to valid options
-- 7. All sensitive data (passwords, SMTP/IMAP credentials) are encrypted before storage
-- 8. Comments document each table, column, and index purpose for maintainability
-- 9. JSON column in contacts table allows flexible custom field storage
-- 10. MEDIUMTEXT columns support large email bodies (up to 16MB)
-- 
-- REQUIREMENTS COVERAGE:
-- This migration satisfies requirements 18.1 through 18.11, providing the complete
-- database schema necessary for administrator authentication, SMTP/IMAP configuration,
-- contact management, campaign creation, queue processing, session management, and
-- worker health monitoring.
-- =====================================================================
