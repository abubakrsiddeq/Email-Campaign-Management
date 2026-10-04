# Email Campaign Management Portal

A production-ready web application built with Next.js 14, TypeScript, and MySQL that enables administrators to create, send, and track email campaigns with comprehensive recipient-level reporting.

## Features

- **Campaign Management**: Create, edit, and send personalized email campaigns
- **Contact Management**: Import contacts from Excel/CSV, manage custom fields
- **Queue-Based Processing**: Asynchronous email delivery with background worker
- **Rate Limiting**: Configurable rate limits (5-10 emails/minute)
- **SMTP/IMAP Integration**: Send emails and sync to Sent folder
- **Recipient-Level Reporting**: Track delivery status for each recipient
- **Retry Functionality**: Automatically retry failed emails
- **Security**: Password hashing, credential encryption, session management
- **Analytics**: Campaign statistics and performance metrics

## Tech Stack

- **Frontend**: Next.js 14 (App Router), React, TypeScript
- **Styling**: Tailwind CSS, shadcn/ui components
- **Database**: MySQL with mysql2 driver
- **Email**: nodemailer (SMTP), imap-simple (IMAP)
- **Security**: bcrypt for password hashing, AES-256 for credential encryption
- **Validation**: Zod for schema validation

## Project Structure

```
├── app/                    # Next.js App Router pages and API routes
├── components/             # React components
│   ├── ui/                # shadcn/ui components
│   ├── campaigns/         # Campaign-specific components
│   ├── contacts/          # Contact management components
│   ├── layout/            # Layout components (Sidebar, Header)
│   └── shared/            # Shared/common components
├── lib/                   # Core business logic
│   ├── db/               # Database connection and repositories
│   │   ├── repositories/ # Data access layer
│   │   └── migrations/   # Database schema migrations
│   ├── services/         # Business logic services
│   ├── utils/            # Utility functions
│   ├── types/            # TypeScript type definitions
│   └── middleware/       # Express middleware
├── worker/               # Background email processing worker
└── public/              # Static assets
```

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- MySQL 8.0+ or MariaDB 10.5+
- SMTP server credentials
- IMAP server credentials (for sent folder sync)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Email-Campaign-Management
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment variables**
   
   Copy `.env.example` to `.env` and update the values:
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` and configure:
   - Database credentials
   - Session secret (generate a random string)
   - Encryption key (32-byte random string)
   - Worker rate limit and poll interval

4. **Set up the database**
   
   Run the migration scripts (to be created in Task 2):
   ```bash
   # Import the schema using MySQL client or phpMyAdmin
   mysql -u root -p email_campaign_portal < lib/db/migrations/001_initial_schema.sql
   ```

5. **Start the development server**
   ```bash
   npm run dev
   ```
   
   Open [http://localhost:3000](http://localhost:3000) in your browser.

6. **Start the background worker** (in a separate terminal)
   ```bash
   node worker/index.js
   ```

## Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm run lint` - Run ESLint

## Environment Variables

See `.env.example` for all required environment variables:

- **Database**: Connection settings for MySQL
- **Application**: URL, session secret, encryption key
- **Worker**: Rate limit and polling interval
- **Logging**: Log level and directory

## Security

- Passwords are hashed using bcrypt (cost factor 10)
- SMTP/IMAP credentials are encrypted with AES-256
- Session tokens are securely generated and stored
- All inputs are validated and sanitized
- SQL injection prevention via parameterized queries
- HTTPS recommended for production

## Development Status

This project is under active development. Current tasks:

- [x] Task 1: Project setup and core infrastructure
- [ ] Task 2: Database schema and connection setup
- [ ] Task 3: Security utilities implementation
- [ ] ... (see tasks.md for full list)

## License

[Your License Here]

## Contributing

[Your Contributing Guidelines Here]
