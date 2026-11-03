import { NextRequest, NextResponse } from 'next/server';
import { query, withTransaction, writeImmutableAuditLog } from '@/lib/db';
import { verifyUserPermission } from '@/lib/auth';

export async function GET(req: NextRequest) {
  const sp = req.nextUrl.searchParams;
  const page = Math.max(1, Number(sp.get('page') || 1));
  const pageSize = Math.min(200, Math.max(1, Number(sp.get('pageSize') || 25)));
  const offset = (page - 1) * pageSize;

  const conditions: string[] = ['1=1'];
  const values: any[] = [];

  const addFilter = (col: string, val: string | null) => {
    if (val && val.trim() !== '') {
      values.push(val.trim());
      conditions.push(`${col} = $${values.length}`);
    }
  };

  addFilter('country_name', sp.get('country'));
  addFilter('state_name', sp.get('state'));
  addFilter('city_name', sp.get('city'));
  addFilter('industry_name', sp.get('industry'));
  addFilter('sector_name', sp.get('sector'));
  addFilter('lead_status', sp.get('status'));
  addFilter('lead_priority', sp.get('priority'));
  addFilter('data_classification', sp.get('dataClassification'));

  if (sp.get('incomplete') === 'true') conditions.push('is_incomplete = TRUE');
  if (sp.get('incomplete') === 'false') conditions.push('is_incomplete = FALSE');

  values.push(pageSize, offset);
  const sql = `
    SELECT * FROM leads
    WHERE ${conditions.join(' AND ')}
    ORDER BY lead_id ASC
    LIMIT $${values.length - 1} OFFSET $${values.length}
  `;
  const rows = await query(sql, values);
  return NextResponse.json({ page, pageSize, count: rows.length, data: rows });
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const userId = Number(body.userId || 1);
  if (!(await verifyUserPermission(userId, 'leads.create'))) {
    return NextResponse.json({ error: 'RBAC Permission Denied' }, { status: 403 });
  }

  return withTransaction(async (client) => {
    const capRes = await client.query("SELECT setting_value FROM system_settings WHERE setting_key = 'database_max_capacity'");
    const maxCap = Number(capRes.rows[0]?.setting_value || 100);
    const countRes = await client.query('SELECT COUNT(*) AS cnt FROM leads');
    if (Number(countRes.rows[0].cnt) >= maxCap) {
      throw new Error(`Database capacity limit (${maxCap}) reached. Upgrade capacity tier first.`);
    }

    const requiredFields = ['company_name', 'contact_person', 'email', 'telephone', 'country_name', 'industry_name', 'followup_date'];
    const missing = requiredFields.filter((k) => !body[k] || String(body[k]).trim() === '');
    const isIncomplete = Boolean(body.saveAsIncomplete) || missing.length > 0;
    const completionPct = Math.round(((16 - missing.length) / 16) * 100);

    const ins = await client.query(
      `INSERT INTO leads (
        lead_code, company_name, contact_person, designation, email, telephone, website,
        country_name, state_name, city_name, industry_name, sector_name, product_category,
        lead_source, lead_status, lead_priority, lead_owner_id, assigned_salesperson_id,
        created_by, last_modified_by, followup_date, remarks, is_incomplete,
        completion_percentage, missing_fields_json, data_classification
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26)
      RETURNING *`,
      [
        body.lead_code, body.company_name, body.contact_person, body.designation,
        body.email, body.telephone, body.website, body.country_name, body.state_name,
        body.city_name, body.industry_name, body.sector_name, body.product_category,
        body.lead_source, isIncomplete ? 'Incomplete' : (body.lead_status || 'New Lead'),
        body.lead_priority || 'Medium Priority', userId, body.assigned_salesperson_id || userId,
        userId, userId, body.followup_date || null, body.remarks || '',
        isIncomplete, completionPct, JSON.stringify(missing),
        body.data_classification || 'REAL BUSINESS DATA',
      ]
    );

    const created = ins.rows[0];
    await writeImmutableAuditLog(client, {
      entityType: 'Lead',
      entityId: created.lead_code,
      leadId: created.lead_id,
      actionType: 'Lead Created',
      fieldChanged: 'record_state',
      previousValue: null,
      newValue: `${isIncomplete ? 'Incomplete' : 'Complete'} (${created.data_classification})`,
      performedByUserId: userId,
      performedByName: body.userName || 'Authorized User',
    });

    return NextResponse.json({ status: 'created', lead: created });
  });
}
