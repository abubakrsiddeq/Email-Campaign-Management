# Database Connection Pool

This module provides MySQL connection pooling functionality for the Email Campaign Management Portal, implementing **Requirement 22.5** for optimized database query performance.

## Features

- **Singleton Connection Pool**: Reuses connections efficiently across the application
- **Environment-based Configuration**: Loads settings from environment variables
- **Connection Health Checks**: Validates database connectivity
- **Typed Query Helpers**: TypeScript-safe query execution
- **Transaction Support**: Automatic commit/rollback handling
- **Pool Monitoring**: Get real-time pool status information

## Configuration

Set the following environment variables in your `.env` file:

```env
DATABASE_HOST=localhost
DATABASE_PORT=3306
DATABASE_NAME=email_campaign_portal
DATABASE_USER=root
DATABASE_PASSWORD=your_password
```

## Usage Examples

### Basic Query Execution

```typescript
import { query, type RowDataPacket } from '@/lib/db/connection';

interface User extends RowDataPacket {
  id: number;
  username: string;
  email: string;
}

// Execute a query
const users = await query<User[]>(
  'SELECT id, username, email FROM administrators WHERE id = ?',
  [userId]
);
```

### Single Row Query

```typescript
import { queryOne, type RowDataPacket } from '@/lib/db/connection';

interface User extends RowDataPacket {
  id: number;
  username: string;
}

// Get a single row (returns null if not found)
const user = await queryOne<User>(
  'SELECT id, username FROM administrators WHERE username = ?',
  ['admin']
);

if (user) {
  console.log(`Found user: ${user.username}`);
}
```

### Insert/Update/Delete Operations

```typescript
import { query, type ResultSetHeader } from '@/lib/db/connection';

// Insert
const result = await query<ResultSetHeader>(
  'INSERT INTO contacts (name, email) VALUES (?, ?)',
  ['John Doe', 'john@example.com']
);
console.log(`Inserted ID: ${result.insertId}`);

// Update
const updateResult = await query<ResultSetHeader>(
  'UPDATE contacts SET name = ? WHERE email = ?',
  ['Jane Doe', 'john@example.com']
);
console.log(`Rows affected: ${updateResult.affectedRows}`);

// Delete
const deleteResult = await query<ResultSetHeader>(
  'DELETE FROM contacts WHERE id = ?',
  [123]
);
console.log(`Rows deleted: ${deleteResult.affectedRows}`);
```

### Transaction Handling

```typescript
import { transaction, type RowDataPacket, type ResultSetHeader } from '@/lib/db/connection';

// Execute multiple queries in a transaction
const result = await transaction(async (connection) => {
  // Insert campaign
  const [campaignResult] = await connection.execute<ResultSetHeader>(
    'INSERT INTO campaigns (name, subject, html_body, plain_text_body, status) VALUES (?, ?, ?, ?, ?)',
    ['My Campaign', 'Hello', '<p>Hello</p>', 'Hello', 'draft']
  );
  
  const campaignId = campaignResult.insertId;
  
  // Insert recipients
  await connection.execute(
    'INSERT INTO campaign_recipients (campaign_id, contact_id) VALUES (?, ?)',
    [campaignId, 1]
  );
  
  await connection.execute(
    'INSERT INTO campaign_recipients (campaign_id, contact_id) VALUES (?, ?)',
    [campaignId, 2]
  );
  
  return campaignId;
});

console.log(`Campaign created with ID: ${result}`);
```

### Health Check

```typescript
import { checkConnectionHealth } from '@/lib/db/connection';

// Check if database is accessible
const isHealthy = await checkConnectionHealth();

if (isHealthy) {
  console.log('Database connection is healthy');
} else {
  console.error('Database connection failed');
}
```

### Pool Status Monitoring

```typescript
import { getPoolStatus } from '@/lib/db/connection';

// Get current pool status
const status = getPoolStatus();
console.log(`Active: ${status.active}`);
console.log(`Total connections: ${status.totalConnections}`);
console.log(`Active connections: ${status.activeConnections}`);
console.log(`Idle connections: ${status.idleConnections}`);
```

### Manual Connection Management

```typescript
import { getConnection, type RowDataPacket } from '@/lib/db/connection';

// Get a connection from the pool
const connection = await getConnection();

try {
  const [rows] = await connection.execute<RowDataPacket[]>(
    'SELECT * FROM campaigns WHERE status = ?',
    ['draft']
  );
  
  // Process rows...
} finally {
  // Always release the connection back to the pool
  connection.release();
}
```

### Graceful Shutdown

```typescript
import { closePool } from '@/lib/db/connection';

// Close all connections when shutting down
process.on('SIGTERM', async () => {
  await closePool();
  process.exit(0);
});
```

## API Reference

### Functions

#### `createPool(): Pool`
Creates and returns a singleton connection pool instance.

#### `getPool(): Pool`
Returns the existing pool or creates a new one if it doesn't exist.

#### `checkConnectionHealth(): Promise<boolean>`
Tests database connectivity and returns true if healthy.

#### `getPoolStatus()`
Returns pool status information including connection counts.

#### `query<T>(sql: string, params?: any[]): Promise<T>`
Executes a query with optional parameters and returns typed results.

#### `queryOne<T>(sql: string, params?: any[]): Promise<T | null>`
Executes a query and returns the first row or null.

#### `getConnection(): Promise<PoolConnection>`
Gets a connection from the pool for manual management.

#### `transaction<T>(callback: (connection: PoolConnection) => Promise<T>): Promise<T>`
Executes queries within a transaction with automatic commit/rollback.

#### `closePool(): Promise<void>`
Closes all connections in the pool.

## Pool Configuration

The connection pool is configured with the following defaults:

- **Connection Limit**: 10 connections
- **Wait for Connections**: true (queues requests when pool is full)
- **Queue Limit**: 0 (unlimited queue)
- **Keep Alive**: enabled for connection health

These settings provide optimal performance for typical web application workloads.

## Error Handling

All query functions throw errors that should be caught and handled:

```typescript
import { query } from '@/lib/db/connection';

try {
  const result = await query('SELECT * FROM campaigns');
  // Process result...
} catch (error) {
  console.error('Database query failed:', error);
  // Handle error appropriately
}
```

## Best Practices

1. **Always use parameterized queries** to prevent SQL injection
2. **Release connections** when using `getConnection()` manually
3. **Use transactions** for multiple related operations
4. **Handle errors** appropriately in production code
5. **Monitor pool status** to identify connection leaks
6. **Close the pool** gracefully during application shutdown

## Related Requirements

- **Requirement 19.5**: Uses mysql2 library compatible with Next.js
- **Requirement 22.5**: Implements connection pooling for optimized performance
