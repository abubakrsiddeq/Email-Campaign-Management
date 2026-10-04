/**
 * Example usage of database connection pool
 * This file demonstrates how to use the connection pool in repository patterns
 */

import {
  query,
  queryOne,
  transaction,
  checkConnectionHealth,
  getPoolStatus,
  type RowDataPacket,
  type ResultSetHeader,
} from './connection';

// ============================================================================
// Example 1: Simple Query Execution
// ============================================================================

interface Administrator extends RowDataPacket {
  id: number;
  username: string;
  created_at: Date;
}

export async function getAllAdministrators(): Promise<Administrator[]> {
  return query<Administrator[]>(
    'SELECT id, username, created_at FROM administrators ORDER BY created_at DESC'
  );
}

export async function getAdministratorByUsername(username: string): Promise<Administrator | null> {
  return queryOne<Administrator>(
    'SELECT id, username, created_at FROM administrators WHERE username = ?',
    [username]
  );
}

// ============================================================================
// Example 2: Insert Operations with ResultSetHeader
// ============================================================================

interface Contact extends RowDataPacket {
  id: number;
  name: string;
  email: string;
  custom_fields_json: string | null;
}

export async function createContact(
  name: string,
  email: string,
  customFields?: Record<string, any>
): Promise<number> {
  const result = await query<ResultSetHeader>(
    'INSERT INTO contacts (name, email, custom_fields_json) VALUES (?, ?, ?)',
    [name, email, customFields ? JSON.stringify(customFields) : null]
  );
  
  return result.insertId;
}

// ============================================================================
// Example 3: Update Operations
// ============================================================================

export async function updateContact(
  id: number,
  name: string,
  email: string
): Promise<boolean> {
  const result = await query<ResultSetHeader>(
    'UPDATE contacts SET name = ?, email = ? WHERE id = ?',
    [name, email, id]
  );
  
  return result.affectedRows > 0;
}

// ============================================================================
// Example 4: Delete Operations
// ============================================================================

export async function deleteContact(id: number): Promise<boolean> {
  const result = await query<ResultSetHeader>(
    'DELETE FROM contacts WHERE id = ?',
    [id]
  );
  
  return result.affectedRows > 0;
}

// ============================================================================
// Example 5: Complex Queries with Joins
// ============================================================================

interface CampaignWithStats extends RowDataPacket {
  id: number;
  name: string;
  subject: string;
  status: string;
  total_recipients: number;
  sent_count: number;
  failed_count: number;
  queued_count: number;
  created_at: Date;
}

export async function getCampaignWithStats(campaignId: number): Promise<CampaignWithStats | null> {
  return queryOne<CampaignWithStats>(
    `SELECT 
      c.id,
      c.name,
      c.subject,
      c.status,
      COUNT(DISTINCT cr.id) as total_recipients,
      COUNT(CASE WHEN eq.delivery_status = 'sent' THEN 1 END) as sent_count,
      COUNT(CASE WHEN eq.delivery_status = 'failed' THEN 1 END) as failed_count,
      COUNT(CASE WHEN eq.delivery_status IN ('queued', 'sending') THEN 1 END) as queued_count,
      c.created_at
    FROM campaigns c
    LEFT JOIN campaign_recipients cr ON c.id = cr.campaign_id
    LEFT JOIN email_queue eq ON cr.id = eq.recipient_id AND c.id = eq.campaign_id
    WHERE c.id = ?
    GROUP BY c.id`,
    [campaignId]
  );
}

// ============================================================================
// Example 6: Transaction - Creating Campaign with Recipients
// ============================================================================

interface CreateCampaignInput {
  name: string;
  subject: string;
  htmlBody: string;
  plainTextBody: string;
  recipientIds: number[];
}

export async function createCampaignWithRecipients(
  input: CreateCampaignInput
): Promise<number> {
  return transaction(async (connection) => {
    // Insert campaign
    const [campaignResult] = await connection.execute<ResultSetHeader>(
      `INSERT INTO campaigns (name, subject, html_body, plain_text_body, status) 
       VALUES (?, ?, ?, ?, 'draft')`,
      [input.name, input.subject, input.htmlBody, input.plainTextBody]
    );
    
    const campaignId = campaignResult.insertId;
    
    // Insert recipients
    if (input.recipientIds.length > 0) {
      const values = input.recipientIds.map(id => [campaignId, id]);
      const placeholders = input.recipientIds.map(() => '(?, ?)').join(', ');
      
      await connection.execute(
        `INSERT INTO campaign_recipients (campaign_id, contact_id) VALUES ${placeholders}`,
        values.flat()
      );
    }
    
    return campaignId;
  });
}

// ============================================================================
// Example 7: Transaction - Queue Campaign for Sending
// ============================================================================

export async function queueCampaignForSending(campaignId: number): Promise<number> {
  return transaction(async (connection) => {
    // Update campaign status
    await connection.execute(
      'UPDATE campaigns SET status = ? WHERE id = ?',
      ['queued', campaignId]
    );
    
    // Get all recipients for this campaign
    interface Recipient extends RowDataPacket {
      recipient_id: number;
    }
    
    const [recipients] = await connection.execute<Recipient[]>(
      'SELECT id as recipient_id FROM campaign_recipients WHERE campaign_id = ?',
      [campaignId]
    );
    
    // Insert into email queue
    if (recipients.length > 0) {
      const values = recipients.map(r => [campaignId, r.recipient_id]);
      const placeholders = recipients.map(() => '(?, ?, ?)').join(', ');
      
      await connection.execute(
        `INSERT INTO email_queue (campaign_id, recipient_id, delivery_status) 
         VALUES ${placeholders}`.replace(/\?/g, (match, offset) => {
          const groupIndex = Math.floor(offset / 8);
          const itemIndex = offset % 3;
          if (itemIndex === 2) return "'queued'";
          return match;
        }),
        values.flat()
      );
    }
    
    return recipients.length;
  });
}

// ============================================================================
// Example 8: Pagination
// ============================================================================

interface PaginatedResult<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export async function getContactsPaginated(
  page: number = 1,
  limit: number = 20,
  searchTerm?: string
): Promise<PaginatedResult<Contact>> {
  const offset = (page - 1) * limit;
  
  // Build query
  let sql = 'SELECT id, name, email, custom_fields_json FROM contacts';
  let countSql = 'SELECT COUNT(*) as total FROM contacts';
  const params: any[] = [];
  
  if (searchTerm) {
    const whereClause = ' WHERE name LIKE ? OR email LIKE ?';
    sql += whereClause;
    countSql += whereClause;
    params.push(`%${searchTerm}%`, `%${searchTerm}%`);
  }
  
  sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
  
  // Get data and count
  const [data, countResult] = await Promise.all([
    query<Contact[]>(sql, [...params, limit, offset]),
    queryOne<{ total: number } & RowDataPacket>(countSql, params),
  ]);
  
  const total = countResult?.total || 0;
  
  return {
    data,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };
}

// ============================================================================
// Example 9: Health Check in API Route
// ============================================================================

export async function getDatabaseHealthStatus() {
  const isHealthy = await checkConnectionHealth();
  const status = getPoolStatus();
  
  return {
    healthy: isHealthy,
    pool: {
      active: status.active,
      totalConnections: status.totalConnections,
      activeConnections: status.activeConnections,
      idleConnections: status.idleConnections,
    },
  };
}

// ============================================================================
// Example 10: Batch Operations
// ============================================================================

export async function bulkInsertContacts(
  contacts: Array<{ name: string; email: string; customFields?: Record<string, any> }>
): Promise<number> {
  if (contacts.length === 0) return 0;
  
  const values = contacts.map(c => [
    c.name,
    c.email,
    c.customFields ? JSON.stringify(c.customFields) : null,
  ]);
  
  const placeholders = contacts.map(() => '(?, ?, ?)').join(', ');
  
  const result = await query<ResultSetHeader>(
    `INSERT INTO contacts (name, email, custom_fields_json) VALUES ${placeholders}
     ON DUPLICATE KEY UPDATE name = VALUES(name), custom_fields_json = VALUES(custom_fields_json)`,
    values.flat()
  );
  
  return result.affectedRows;
}
