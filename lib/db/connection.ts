import * as mysql from 'mysql2/promise';
import type { Pool, PoolConnection, RowDataPacket, ResultSetHeader } from 'mysql2/promise';

/**
 * MySQL Connection Pool Configuration
 * Implements connection pooling for optimal database performance
 * as per Requirement 22.5
 */

// Singleton pool instance
let pool: Pool | null = null;

/**
 * Database configuration interface
 */
interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  connectionLimit: number;
  waitForConnections: boolean;
  queueLimit: number;
  enableKeepAlive: boolean;
  keepAliveInitialDelay: number;
}

/**
 * Get database configuration from environment variables
 */
function getDatabaseConfig(): DatabaseConfig {
  const host = process.env.DATABASE_HOST || 'localhost';
  const port = parseInt(process.env.DATABASE_PORT || '3306', 10);
  const database = process.env.DATABASE_NAME || 'email_campaign_portal';
  const user = process.env.DATABASE_USER || 'root';
  const password = process.env.DATABASE_PASSWORD || '';

  if (!password && process.env.NODE_ENV === 'production') {
    throw new Error('DATABASE_PASSWORD must be set in production environment');
  }

  return {
    host,
    port,
    database,
    user,
    password,
    connectionLimit: 10, // Maximum number of connections in pool
    waitForConnections: true, // Queue requests when no connections available
    queueLimit: 0, // Unlimited queue size
    enableKeepAlive: true, // Keep connections alive
    keepAliveInitialDelay: 0, // Start keep-alive immediately
  };
}

/**
 * Initialize the connection pool
 * Creates a singleton pool instance that can be reused across the application
 */
export function createPool(): Pool {
  if (pool) {
    return pool;
  }

  const config = getDatabaseConfig();
  
  pool = mysql.createPool(config);

  return pool;
}

/**
 * Get the database connection pool
 * Returns the existing pool or creates a new one
 */
export function getPool(): Pool {
  if (!pool) {
    return createPool();
  }
  return pool;
}

/**
 * Connection health check
 * Tests database connectivity and returns connection status
 * 
 * @returns Promise resolving to true if connection is healthy, false otherwise
 */
export async function checkConnectionHealth(): Promise<boolean> {
  try {
    const pool = getPool();
    const connection = await pool.getConnection();
    
    // Execute a simple query to verify connectivity
    await connection.query('SELECT 1');
    
    connection.release();
    return true;
  } catch (error) {
    console.error('Database health check failed:', error);
    return false;
  }
}

/**
 * Get detailed pool status information
 * Useful for monitoring and debugging
 */
export function getPoolStatus() {
  if (!pool) {
    return {
      active: false,
      totalConnections: 0,
      activeConnections: 0,
      idleConnections: 0,
    };
  }

  // Access internal pool state (mysql2 specific properties)
  const poolState = pool as any;
  
  return {
    active: true,
    totalConnections: poolState._allConnections?.length || 0,
    activeConnections: poolState._allConnections?.length - poolState._freeConnections?.length || 0,
    idleConnections: poolState._freeConnections?.length || 0,
  };
}

/**
 * Typed query execution helper
 * Provides a convenient way to execute queries with TypeScript type safety
 * 
 * @param sql SQL query string
 * @param params Query parameters
 * @returns Promise resolving to query results
 */
export async function query<T extends RowDataPacket[] | RowDataPacket[][] | ResultSetHeader>(
  sql: string,
  params?: any[]
): Promise<T> {
  const pool = getPool();
  const [rows] = await pool.execute<T>(sql, params);
  return rows;
}

/**
 * Execute a query and return the first row
 * Convenience method for queries expected to return a single row
 * 
 * @param sql SQL query string
 * @param params Query parameters
 * @returns Promise resolving to first row or null
 */
export async function queryOne<T extends RowDataPacket>(
  sql: string,
  params?: any[]
): Promise<T | null> {
  const rows = await query<T[]>(sql, params);
  return rows.length > 0 ? rows[0] : null;
}

/**
 * Get a connection from the pool for transaction handling
 * Caller is responsible for releasing the connection
 * 
 * @returns Promise resolving to a connection
 */
export async function getConnection(): Promise<PoolConnection> {
  const pool = getPool();
  return pool.getConnection();
}

/**
 * Execute queries within a transaction
 * Automatically commits on success or rolls back on error
 * 
 * @param callback Function that receives a connection and performs queries
 * @returns Promise resolving to callback result
 */
export async function transaction<T>(
  callback: (connection: PoolConnection) => Promise<T>
): Promise<T> {
  const connection = await getConnection();
  
  try {
    await connection.beginTransaction();
    const result = await callback(connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

/**
 * Close all connections in the pool
 * Should be called when shutting down the application
 */
export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}

/**
 * Re-export mysql2 types for use in other modules
 */
export type { RowDataPacket, ResultSetHeader, PoolConnection } from 'mysql2/promise';
