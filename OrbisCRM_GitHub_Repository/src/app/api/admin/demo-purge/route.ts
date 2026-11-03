import { NextRequest, NextResponse } from 'next/server';
import { withTransaction, writeImmutableAuditLog } from '@/lib/db';
import { verifyUserPermission } from '@/lib/auth';

export async function POST(req: NextRequest) {
  const { userId, userName, confirmed, verifiedBackupCode } = await req.json();
  if (!confirmed || !verifiedBackupCode) {
    return NextResponse.json({ error: 'Confirmation and verified backup code are mandatory before purging Demo Data.' }, { status: 400 });
  }
  if (!(await verifyUserPermission(Number(userId), 'demo.purge'))) {
    return NextResponse.json({ error: 'Forbidden: Super Admin role required for Remove All Demo Data.' }, { status: 403 });
  }

  return withTransaction(async (client) => {
    const bkpCheck = await client.query(
      "SELECT * FROM backup_history WHERE backup_code = $1 AND verification_status = 'Verified OK'",
      [verifiedBackupCode]
    );
    if (bkpCheck.rowCount === 0) {
      throw new Error('Verified backup not found. Aborting Demo Data deletion.');
    }

    const delLeads = await client.query("DELETE FROM leads WHERE data_classification = 'DEMO DATA'");
    const delComps = await client.query("DELETE FROM companies WHERE data_classification = 'DEMO DATA'");
    const realRemaining = await client.query("SELECT COUNT(*) AS cnt FROM leads WHERE data_classification = 'REAL BUSINESS DATA'");

    await writeImmutableAuditLog(client, {
      entityType: 'Database',
      entityId: 'DEMO_DATA_PURGE',
      actionType: 'Remove All Demo Data',
      fieldChanged: 'leads,companies',
      previousValue: `${delLeads.rowCount} DEMO leads, ${delComps.rowCount} DEMO companies`,
      newValue: `0 DEMO records (${realRemaining.rows[0].cnt} REAL BUSINESS DATA preserved)`,
      performedByUserId: Number(userId),
      performedByName: userName || 'Super Admin',
    });

    return NextResponse.json({
      status: 'purged',
      deletedDemoLeads: delLeads.rowCount,
      deletedDemoCompanies: delComps.rowCount,
      preservedRealLeads: Number(realRemaining.rows[0].cnt),
    });
  });
}
