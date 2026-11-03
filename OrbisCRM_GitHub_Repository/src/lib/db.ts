import { Pool, PoolClient } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 25,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: true } : false,
});

export async function query<T = any>(text: string, params: any[] = []): Promise<T[]> {
  const res = await pool.query(text, params);
  return res.rows;
}

export async function withTransaction<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function writeImmutableAuditLog(
  client: PoolClient,
  params: {
    entityType: string;
    entityId: string;
    leadId?: number | null;
    actionType: string;
    fieldChanged: string;
    previousValue?: string | null;
    newValue?: string | null;
    performedByUserId: number;
    performedByName: string;
    ipAddress?: string;
  }
) {
  await client.query(
    `INSERT INTO activity_logs (
      entity_type, entity_id, lead_id, action_type, field_changed,
      previous_value, new_value, performed_by, performed_by_name, ip_address
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
    [
      params.entityType,
      params.entityId,
      params.leadId ?? null,
      params.actionType,
      params.fieldChanged,
      params.previousValue ?? null,
      params.newValue ?? null,
      params.performedByUserId,
      params.performedByName,
      params.ipAddress ?? '127.0.0.1',
    ]
  );
}
