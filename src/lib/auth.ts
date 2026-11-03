import argon2 from 'argon2';
import { query } from './db';

export type RoleCode = 'SUPER_ADMIN' | 'ADMIN' | 'SALES_MANAGER' | 'SALES_EXEC' | 'DATA_ENTRY' | 'READ_ONLY';

export async function hashPassword(plainPassword: string): Promise<string> {
  if (plainPassword.length < 10) {
    throw new Error('Password policy violation: minimum 10 characters required.');
  }
  return argon2.hash(plainPassword, {
    type: argon2.argon2id,
    memoryCost: 65536,
    timeCost: 3,
    parallelism: 4,
  });
}

export async function verifyPassword(hash: string, plainPassword: string): Promise<boolean> {
  return argon2.verify(hash, plainPassword);
}

export async function verifyUserPermission(userId: number, permissionKey: string): Promise<boolean> {
  const rows = await query<{ count: string }>(
    `SELECT COUNT(*) AS count
     FROM users u
     JOIN role_permissions rp ON rp.role_id = u.role_id
     JOIN permissions p ON p.permission_id = rp.permission_id
     WHERE u.user_id = $1 AND u.is_active = TRUE AND u.is_locked = FALSE AND p.permission_key = $2`,
    [userId, permissionKey]
  );
  return Number(rows[0]?.count || 0) > 0;
}
