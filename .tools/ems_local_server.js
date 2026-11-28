const http = require('http');
const crypto = require('crypto');
const { URL } = require('url');
const { Pool } = require('C:/Users/yossa/OneDrive/เอกสาร/prototype_cirrus/node_modules/pg');
const bcrypt = require('C:/Users/yossa/.vscode/extensions/ritwickdey.liveserver-5.7.10/node_modules/bcryptjs');

const PORT = Number(process.env.PORT || 3000);
const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:1234@127.0.0.1:5432/cirrus_02';

const pool = new Pool({ connectionString: DATABASE_URL });
const tokenSecret = crypto.randomBytes(32);

// Known scanner code aliases where hr.device_scans.device_user_code differs slightly from core.employees.employee_code
const SCANNER_CODE_ALIASES = {
  '2609021': ['2609021', '26090201'],
  '26081701': ['26081701', '260817'],
  '26060501': ['26060501', '506001'],
  '26060601': ['26060601', '606001'],
  '2610161': ['2610161', '2610171'],
};

function getDeviceCodesForEmployee(empCode) {
  if (!empCode) return [];
  const s = String(empCode).trim();
  return SCANNER_CODE_ALIASES[s] || [s];
}

function getBangkokNow() {
  const now = new Date();
  const bangkokMs = now.getTime() + 7 * 3600 * 1000;
  const b = new Date(bangkokMs);
  const yyyy = b.getUTCFullYear();
  const mm = String(b.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(b.getUTCDate()).padStart(2, '0');
  const hh = String(b.getUTCHours()).padStart(2, '0');
  const mi = String(b.getUTCMinutes()).padStart(2, '0');
  const ss = String(b.getUTCSeconds()).padStart(2, '0');
  return {
    now,
    workDate: `${yyyy}-${mm}-${dd}`,
    timeStr: `${hh}:${mi}:${ss}`,
    minutesOfDay: b.getUTCHours() * 60 + b.getUTCMinutes(),
  };
}

function formatPgDate(val) {
  if (!val) return null;
  if (typeof val === 'string') return val.slice(0, 10);
  if (val instanceof Date) {
    // PostgreSQL date comes back at local midnight in node-pg
    const y = val.getFullYear();
    const m = String(val.getMonth() + 1).padStart(2, '0');
    const d = String(val.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  return String(val).slice(0, 10);
}

function formatScanRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    deviceId: row.device_id,
    machineNo: row.machine_no,
    deviceUserCode: row.device_user_code != null ? String(row.device_user_code) : null,
    userId: row.user_id,
    scannedAt: row.scanned_at instanceof Date ? row.scanned_at.toISOString() : row.scanned_at,
    receivedAt: row.received_at instanceof Date ? row.received_at.toISOString() : row.received_at,
    workDate: formatPgDate(row.work_date),
    windowCode: row.window_code,
    counted: Boolean(row.counted),
    notCountedReason: row.not_counted_reason,
    flag: row.flag,
    lateMinutes: row.late_minutes != null ? Number(row.late_minutes) : null,
    earlyLeaveMinutes: row.early_leave_minutes != null ? Number(row.early_leave_minutes) : null,
    overTime: row.over_time != null ? Number(row.over_time) : null,
    source: row.source,
    clientRequestId: row.client_request_id,
    latitude: row.latitude != null ? Number(row.latitude) : null,
    longitude: row.longitude != null ? Number(row.longitude) : null,
    accuracy: row.accuracy != null ? Number(row.accuracy) : null,
    photoStorageKey: row.photo_storage_key,
  };
}

function isTechnicianRole(session) {
  if (!session) return false;
  const roles = (session.roles || []).map((r) => String(r).toLowerCase().trim());
  return roles.includes('technician') || roles.includes('admin');
}

async function ensureSampleTechnicianJobs() {
  try {
    // Seed 2 sample assigned jobs per active Technician & Admin account if none exist yet,
    // strictly inside existing cirrus_02 tables (operations.work_orders & hr.work_assignments).
    const techRes = await pool.query(`
      SELECT DISTINCT u.id AS user_id, r.name AS role_name, COALESCE(e.employee_code, '000') AS emp_code
      FROM core.user_roles ur
      JOIN core.roles r ON r.id = ur.role_id
      JOIN core.users u ON u.id = ur.user_id
      LEFT JOIN core.employees e ON e.user_id = u.id
      WHERE r.name IN ('Technician', 'Admin') AND u.is_active = true
      ORDER BY r.name, u.id
    `);
    if (techRes.rows.length === 0) return;

    const projRes = await pool.query('SELECT id FROM projects.projects LIMIT 1');
    const projectId = projRes.rows.length > 0 ? projRes.rows[0].id : null;
    const adminRes = await pool.query('SELECT id FROM core.users ORDER BY created_at ASC LIMIT 1');
    const createdBy = adminRes.rows.length > 0 ? adminRes.rows[0].id : techRes.rows[0].user_id;

    let idx = 1;
    for (const row of techRes.rows) {
      const targetUserId = row.user_id;
      const isAdmin = row.role_name === 'Admin';
      const suffix = String(row.emp_code || idx).slice(-3);
      idx++;
      const existingAssign = await pool.query(
        `SELECT count(*)::int AS c FROM hr.work_assignments WHERE user_id = $1`,
        [targetUserId]
      );
      const existingWo = await pool.query(
        `SELECT count(*)::int AS c FROM operations.work_orders WHERE assigned_to = $1`,
        [targetUserId]
      );
      if (existingAssign.rows[0].c > 0 || existingWo.rows[0].c > 0) continue;

      const samples = isAdmin
        ? [
            {
              number: 'JOB-2611-201',
              title: 'Field Site Inspection — Pier C',
              description: 'Verify marine power installation and safety checklist.',
              type: 'inspection',
            },
            {
              number: 'JOB-2611-202',
              title: 'Hydraulic Pump Calibration — MV Cirrus 02',
              description: 'Check pressure gauge & test run auxiliary pump.',
              type: 'service',
            },
          ]
        : [
            {
              number: `JOB-2611-${suffix}A`,
              title: 'Marine Generator Maintenance — MV Cirrus 01',
              description: 'Routine 500-hour generator inspection & oil filter replacement at Pier A.',
              type: 'maintenance',
            },
            {
              number: `JOB-2611-${suffix}B`,
              title: 'Electrical Panel Diagnostics — Dock B',
              description: 'Inspect shore-power breaker panel and test bilge pump sensors.',
              type: 'inspection',
            },
          ];

      for (const s of samples) {
        const woId = crypto.randomUUID();
        await pool.query(
          `INSERT INTO operations.work_orders
             (id, number, title, description, type, priority, status, project_id, assigned_to, schedule_start, schedule_end, notes, created_by, billable)
           VALUES ($1, $2, $3, $4, $5::operations.work_order_type, 'medium'::operations.priority_level, 'open'::operations.work_order_status, $6, $7, CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', 'Seeded sample job for Technician flow', $8, true)`,
          [woId, s.number, s.title, s.description, s.type, projectId, targetUserId, createdBy]
        );
        await pool.query(
          `INSERT INTO hr.work_assignments
             (id, user_id, project_id, work_order_id, is_primary, assignment_role, notes, assigned_by)
           VALUES ($1, $2, NULL, $3, true, 'technician', 'Assigned technician job', $4)`,
          [crypto.randomUUID(), targetUserId, woId, createdBy]
        );
      }
      console.log(`[BOOT] Seeded 2 sample assigned jobs for ${row.role_name} user:`, targetUserId);
    }
  } catch (err) {
    console.warn('[BOOT WARN] Sample technician job seed skipped:', err.message);
  }
}

const PAYROLL_MANAGER_ROLES = new Set([
  'admin',
  'hr officer',
  'hr',
  'accountant',
  'owner',
]);

function canManagePayroll(session) {
  if (!session) return false;
  const roles = (session.roles || []).map((r) => String(r).toLowerCase().trim());
  if (roles.some((r) => PAYROLL_MANAGER_ROLES.has(r))) return true;
  const perms = new Set(
    (session.permissions || []).map((p) => String(p).toLowerCase().trim())
  );
  return (
    perms.has('payroll.create') ||
    perms.has('payroll.update') ||
    perms.has('payroll.delete')
  );
}

function formatPayrollItemRow(row) {
  return {
    id: row.id,
    employeeId: row.employee_id,
    componentId: row.component_id || null,
    code: row.code,
    name: row.name,
    componentType: row.component_type,
    calcMode: row.calc_mode,
    amount: row.amount != null ? Number(row.amount) : 0,
    maxCap: row.max_cap != null ? Number(row.max_cap) : null,
    isActive: Boolean(row.is_active),
    notes: row.notes || '',
  };
}

async function ensurePayrollSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS hr.employee_payroll_items (
      id uuid PRIMARY KEY,
      employee_id uuid NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
      component_id uuid REFERENCES hr.payroll_components(id) ON DELETE SET NULL,
      code text NOT NULL,
      name text NOT NULL,
      component_type text NOT NULL DEFAULT 'deduction',
      calc_mode text NOT NULL DEFAULT 'fixed',
      amount numeric(12,2) NOT NULL DEFAULT 0,
      max_cap numeric(12,2),
      is_active boolean NOT NULL DEFAULT true,
      notes text,
      created_at timestamptz NOT NULL DEFAULT NOW(),
      updated_at timestamptz NOT NULL DEFAULT NOW(),
      created_by uuid
    )
  `);

  const defaultComponents = [
    {
      code: 'ACCOMMODATION',
      name: 'Accommodation (ค่าที่พัก)',
      componentType: 'deduction',
      isStatutory: false,
      description: 'Monthly staff accommodation / dormitory deduction',
    },
    {
      code: 'SOCIAL_SECURITY',
      name: 'Social Security (ค่าประกันสังคม)',
      componentType: 'deduction',
      isStatutory: true,
      description: 'Statutory social security contribution (e.g. 5%, max 750 THB)',
    },
    {
      code: 'WORK_INSURANCE',
      name: 'Work Insurance (ค่าประกันงาน)',
      componentType: 'deduction',
      isStatutory: false,
      description: 'Work / job guarantee insurance deduction',
    },
  ];

  const seedUserRes = await pool.query(
    'SELECT user_id FROM core.user_accounts ORDER BY created_at ASC LIMIT 1'
  );
  const seedUserId = seedUserRes.rows[0] ? seedUserRes.rows[0].user_id : null;

  for (const c of defaultComponents) {
    const exists = await pool.query(
      'SELECT id FROM hr.payroll_components WHERE code = $1 LIMIT 1',
      [c.code]
    );
    if (exists.rows.length === 0 && seedUserId) {
      await pool.query(
        `INSERT INTO hr.payroll_components (id, code, name, component_type, is_statutory, is_active, description, created_by)
         VALUES ($1, $2, $3, $4::hr.payroll_component_type, $5, true, $6, $7)`,
        [crypto.randomUUID(), c.code, c.name, c.componentType, c.isStatutory, c.description, seedUserId]
      );
    }
  }
}

function makeToken(userId) {
  const payload = Buffer.from(JSON.stringify({ sub: userId, iat: Date.now() })).toString('base64url');
  const signature = crypto.createHmac('sha256', tokenSecret).update(payload).digest('base64url');
  return `ems.${payload}.${signature}`;
}

function parseToken(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice('Bearer '.length).trim();
  if (!token) return null;
  const parts = token.split('.');
  if (parts.length === 3 && parts[0] === 'ems') {
    try {
      const expected = crypto.createHmac('sha256', tokenSecret).update(parts[1]).digest();
      const received = Buffer.from(parts[2], 'base64url');
      if (received.length !== expected.length || !crypto.timingSafeEqual(received, expected)) return null;
      const decoded = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
      if (decoded && typeof decoded.sub === 'string') return decoded.sub;
    } catch (_) {}
  }
  return null;
}

async function loadUserSessionById(userId) {
  const userRes = await pool.query(
    `SELECT
       ua.user_id AS id,
       ua.username AS account_username,
       ua.password_hash,
       u.username AS legacy_username,
       u.name AS legacy_name,
       u.email AS legacy_email,
       u.phone AS legacy_phone,
       u.department AS department_name,
       u.is_active,
       up.first_name,
       up.last_name,
       up.email AS profile_email,
       up.phone AS profile_phone,
       up.address,
       up.city,
       up.country,
       e.id AS employee_id,
       e.employee_code,
       e.employment_type,
       e.employment_status,
       e.start_date,
       e.salary
     FROM core.user_accounts ua
     LEFT JOIN core.users u ON u.id = ua.user_id
     LEFT JOIN core.user_profiles up ON up.user_id = ua.user_id
     LEFT JOIN core.employees e ON e.user_id = ua.user_id
     WHERE ua.user_id = $1
     LIMIT 1`,
    [userId]
  );

  if (userRes.rows.length === 0) return null;
  const row = userRes.rows[0];

  const rolesRes = await pool.query(
    `SELECT r.name
     FROM core.user_roles ur
     JOIN core.roles r ON r.id = ur.role_id
     WHERE ur.user_id = $1
     ORDER BY r.name ASC`,
    [userId]
  );
  const roles = rolesRes.rows.map((r) => r.name);

  const permsRes = await pool.query(
    `SELECT DISTINCT p.code
     FROM core.user_roles ur
     JOIN core.role_permissions rp ON rp.role_id = ur.role_id
     JOIN core.permissions p ON p.id = rp.permission_id
     WHERE ur.user_id = $1
     ORDER BY p.code ASC`,
    [userId]
  );
  const permissions = permsRes.rows.map((p) => p.code);

  const fullName = [row.first_name, row.last_name].filter(Boolean).join(' ').trim() || row.legacy_name || row.account_username;
  const email = row.profile_email || row.legacy_email || '';
  const phone = row.profile_phone || row.legacy_phone || '';
  const employeeCode = row.employee_code != null ? String(row.employee_code) : null;

  return {
    row,
    user: {
      id: row.id,
      username: row.account_username,
      name: fullName,
      firstName: row.first_name || null,
      lastName: row.last_name || null,
      email,
      phone,
      employeeId: row.employee_id || null,
      employeeCode,
      department: row.department_name || null,
      employmentType: row.employment_type || null,
      employmentStatus: row.employment_status || 'active',
      startDate: formatPgDate(row.start_date),
      salary: row.salary != null ? Number(row.salary) : null,
      active: row.is_active !== false,
    },
    roles,
    permissions,
  };
}

function sendJson(res, statusCode, data) {
  const body = JSON.stringify(data);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  });
  res.end(body);
}

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function readJsonBody(req) {
  const buf = await readRawBody(req);
  if (!buf || buf.length === 0) return {};
  try {
    return JSON.parse(buf.toString('utf8'));
  } catch (_) {
    return {};
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    });
    return res.end();
  }

  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = parsedUrl.pathname;

  try {
    // Health check
    if (req.method === 'GET' && (pathname === '/health' || pathname === '/api/v1/ems/health')) {
      const dbCheck = await pool.query('SELECT current_database() AS db, COUNT(*)::int AS users FROM core.user_accounts');
      return sendJson(res, 200, { ok: true, database: dbCheck.rows[0].db, userAccounts: dbCheck.rows[0].users });
    }

    // 1. POST /api/v1/ems/auth/login
    if (req.method === 'POST' && pathname === '/api/v1/ems/auth/login') {
      const body = await readJsonBody(req);
      const rawUsername = (body.username || '').toString().trim();
      const rawPassword = (body.password || '').toString();

      if (!rawUsername || !rawPassword) {
        return sendJson(res, 400, { message: 'Please enter both username and password.' });
      }

      const findRes = await pool.query(
        `SELECT ua.user_id, ua.username, ua.password_hash, e.employee_code
         FROM core.user_accounts ua
         LEFT JOIN core.users u ON u.id = ua.user_id
         LEFT JOIN core.user_profiles up ON up.user_id = ua.user_id
         LEFT JOIN core.employees e ON e.user_id = ua.user_id
         WHERE LOWER(ua.username) = LOWER($1)
            OR LOWER(COALESCE(u.username, '')) = LOWER($1)
            OR LOWER(COALESCE(u.name, '')) = LOWER($1)
            OR LOWER(COALESCE(up.email, '')) = LOWER($1)
            OR LOWER(COALESCE(u.email, '')) = LOWER($1)
            OR COALESCE(e.employee_code::text, '') = $1
         LIMIT 1`,
        [rawUsername]
      );

      if (findRes.rows.length === 0) {
        return sendJson(res, 401, { message: 'Invalid username or password.' });
      }

      const acct = findRes.rows[0];
      let validPassword = false;
      if (acct.password_hash) {
        try {
          validPassword = bcrypt.compareSync(rawPassword, acct.password_hash);
        } catch (_) {}
      }
      if (!validPassword) {
        return sendJson(res, 401, { message: 'Invalid username or password.' });
      }

      const session = await loadUserSessionById(acct.user_id);
      if (!session) {
        return sendJson(res, 401, { message: 'Account not found.' });
      }

      const accessToken = makeToken(acct.user_id);
      console.log(`[AUTH] Login success: username="${session.user.username}" (${session.user.name}) code=${session.user.employeeCode}`);
      return sendJson(res, 200, {
        accessToken,
        user: session.user,
        roles: session.roles,
        permissions: session.permissions,
      });
    }

    // 2. GET /api/v1/ems/auth/me
    if (req.method === 'GET' && pathname === '/api/v1/ems/auth/me') {
      const userId = parseToken(req.headers.authorization);
      if (!userId) {
        return sendJson(res, 401, { message: 'Authentication required.', errorCode: 'AUTHENTICATION_REQUIRED' });
      }
      const session = await loadUserSessionById(userId);
      if (!session) {
        return sendJson(res, 401, { message: 'User session not found.', errorCode: 'AUTHENTICATION_REQUIRED' });
      }
      return sendJson(res, 200, {
        user: session.user,
        roles: session.roles,
        permissions: session.permissions,
      });
    }

    // 3. GET /api/v1/ems/auth/sso
    if (req.method === 'GET' && pathname === '/api/v1/ems/auth/sso') {
      return sendJson(res, 401, { message: 'No active SSO session.' });
    }

    // 4. POST /api/v1/ems/auth/logout
    if (req.method === 'POST' && pathname === '/api/v1/ems/auth/logout') {
      return sendJson(res, 200, { ok: true });
    }

    // All endpoints below require authentication
    const userId = parseToken(req.headers.authorization);
    if (!userId) {
      return sendJson(res, 401, { message: 'Authentication required.', errorCode: 'AUTHENTICATION_REQUIRED' });
    }
    const session = await loadUserSessionById(userId);
    if (!session) {
      return sendJson(res, 401, { message: 'Authentication required.', errorCode: 'AUTHENTICATION_REQUIRED' });
    }
    const deviceCodes = getDeviceCodesForEmployee(session.user.employeeCode);

    // 5. GET /api/v1/ems/app-attendance/status
    if (req.method === 'GET' && pathname === '/api/v1/ems/app-attendance/status') {
      const bkk = getBangkokNow();
      const winRes = await pool.query('SELECT code, kind, from_time, until_time, reference_time FROM hr.attendance_windows ORDER BY sort_order ASC');
      let currentWindowCode = null;
      for (const w of winRes.rows) {
        if (w.from_time <= bkk.timeStr && bkk.timeStr <= w.until_time) {
          currentWindowCode = w.code;
          break;
        }
      }

      const latestRes = await pool.query(
        `SELECT *
         FROM hr.device_scans
         WHERE user_id = $1 OR device_user_code::text = ANY($2::text[])
         ORDER BY scanned_at DESC
         LIMIT 1`,
        [userId, deviceCodes]
      );

      const latestCountedRes = await pool.query(
        `SELECT *
         FROM hr.device_scans
         WHERE (user_id = $1 OR device_user_code::text = ANY($2::text[]))
           AND counted = true
         ORDER BY scanned_at DESC
         LIMIT 1`,
        [userId, deviceCodes]
      );

      const latestEvent = formatScanRow(latestRes.rows[0]);
      const latestCountedEvent = formatScanRow(latestCountedRes.rows[0]);

      return sendJson(res, 200, {
        serverTime: bkk.now.toISOString(),
        currentWorkDate: bkk.workDate,
        currentWindowCode,
        latestEvent,
        latestCountedEvent,
        latestEventCounted: latestEvent ? latestEvent.counted : null,
        latestEventNotCountedReason: latestEvent ? latestEvent.notCountedReason : null,
        latestEventFlag: latestEvent ? latestEvent.flag : null,
        pendingCheckoutCheckStatus: 'ok',
        pendingCheckout: null,
      });
    }

    // 6. GET /api/v1/ems/app-attendance/my-scans
    if (req.method === 'GET' && pathname === '/api/v1/ems/app-attendance/my-scans') {
      const from = parsedUrl.searchParams.get('from') || '2000-01-01';
      const to = parsedUrl.searchParams.get('to') || '2099-12-31';

      const scansRes = await pool.query(
        `SELECT *
         FROM hr.device_scans
         WHERE (user_id = $1 OR device_user_code::text = ANY($2::text[]))
           AND counted = true
           AND work_date >= $3::date
           AND work_date <= $4::date
         ORDER BY work_date DESC, scanned_at ASC`,
        [userId, deviceCodes, from, to]
      );

      return sendJson(res, 200, scansRes.rows.map(formatScanRow));
    }

    // 7. GET /api/v1/ems/attendance
    if (req.method === 'GET' && pathname === '/api/v1/ems/attendance') {
      const from = parsedUrl.searchParams.get('from') || '2000-01-01';
      const to = parsedUrl.searchParams.get('to') || '2099-12-31';

      const attRes = await pool.query(
        `SELECT ar.*
         FROM hr.attendance_records ar
         LEFT JOIN core.employees e ON e.id = ar.employee_id
         WHERE (ar.employee_id::text = $1 OR e.user_id::text = $1)
           AND ar.date >= $2::date
           AND ar.date <= $3::date
         ORDER BY ar.date DESC`,
        [userId, from, to]
      );

      const formatted = attRes.rows.map((r) => ({
        id: r.id,
        employeeId: r.employee_id,
        date: formatPgDate(r.date),
        status: r.status,
        checkInAt: r.check_in_at instanceof Date ? r.check_in_at.toISOString() : r.check_in_at,
        checkOutAt: r.check_out_at instanceof Date ? r.check_out_at.toISOString() : r.check_out_at,
        hoursWorked: r.hours_worked != null ? Number(r.hours_worked) : null,
        overtimeHours: r.overtime_hours != null ? Number(r.overtime_hours) : null,
        leaveType: r.leave_type,
        notes: r.notes,
      }));

      return sendJson(res, 200, formatted);
    }

    // 8. POST /api/v1/ems/storage/uploads
    if (req.method === 'POST' && pathname === '/api/v1/ems/storage/uploads') {
      const rawBuf = await readRawBody(req);
      const rawText = rawBuf.toString('latin1');
      const matchReqId = rawText.match(/name="uploadRequestId"\r?\n\r?\n([0-9a-fA-F-]{36})/);
      const uploadRequestId = matchReqId ? matchReqId[1] : crypto.randomUUID();
      const bkk = getBangkokNow();
      const storageKey = `attendance/${userId}/${bkk.workDate}/${uploadRequestId}.jpg`;
      return sendJson(res, 201, { storageKey, uploadRequestId });
    }

    // 9. POST /api/v1/ems/app-attendance/events
    if (req.method === 'POST' && pathname === '/api/v1/ems/app-attendance/events') {
      const body = await readJsonBody(req);
      const clientRequestId = body.clientRequestId || crypto.randomUUID();

      // Check existing by client_request_id
      const existing = await pool.query(
        'SELECT * FROM hr.device_scans WHERE client_request_id = $1 LIMIT 1',
        [clientRequestId]
      );
      if (existing.rows.length > 0) {
        return sendJson(res, 200, formatScanRow(existing.rows[0]));
      }

      const bkk = getBangkokNow();
      const winRes = await pool.query('SELECT code, kind, from_time, until_time, reference_time FROM hr.attendance_windows ORDER BY sort_order ASC');
      let currentWindow = null;
      for (const w of winRes.rows) {
        if (w.from_time <= bkk.timeStr && bkk.timeStr <= w.until_time) {
          currentWindow = w;
          break;
        }
      }

      const windowCode = currentWindow ? currentWindow.code : null;
      let counted = Boolean(windowCode);
      let notCountedReason = windowCode ? null : 'outside_window';

      if (windowCode) {
        const dupRes = await pool.query(
          `SELECT id FROM hr.device_scans
           WHERE (user_id = $1 OR device_user_code::text = ANY($2::text[]))
             AND work_date = $3::date
             AND window_code = $4
             AND counted = true
           LIMIT 1`,
          [userId, deviceCodes, bkk.workDate, windowCode]
        );
        if (dupRes.rows.length > 0) {
          counted = false;
          notCountedReason = 'duplicate_in_window';
        }
      }

      const empCodeNum = session.user.employeeCode ? Number(session.user.employeeCode) : 0;
      const newId = crypto.randomUUID();
      const insertRes = await pool.query(
        `INSERT INTO hr.device_scans (
           id, device_id, machine_no, device_user_code, user_id,
           scanned_at, received_at, work_date, window_code,
           counted, not_counted_reason, flag, source,
           client_request_id, latitude, longitude, accuracy, photo_storage_key
         ) VALUES (
           $1, 'APP', 0, $2, $3,
           NOW(), NOW(), $4::date, $5,
           $6, $7, NULL, 'app',
           $8, $9, $10, $11, $12
         ) RETURNING *`,
        [
          newId,
          empCodeNum,
          userId,
          bkk.workDate,
          windowCode,
          counted,
          notCountedReason,
          clientRequestId,
          body.latitude ?? null,
          body.longitude ?? null,
          body.accuracy ?? null,
          body.selfieStorageKey ?? null,
        ]
      );

      return sendJson(res, 201, formatScanRow(insertRes.rows[0]));
    }

    // 10. POST /api/v1/ems/app-attendance/pending-checkout/resolve
    if (req.method === 'POST' && pathname === '/api/v1/ems/app-attendance/pending-checkout/resolve') {
      return sendJson(res, 409, {
        errorCode: 'APP_ATTENDANCE_PENDING_CHECKOUT_ALREADY_RESOLVED',
        message: 'Pending checkout is already resolved.',
      });
    }

    // =========================================================================
    // PAYROLL & DEDUCTIONS ENDPOINTS (Hourly Rate + Accommodation / SSO / Work Insurance)
    // =========================================================================

    // 11. GET /api/v1/ems/payroll/my-config (any authenticated employee)
    if (req.method === 'GET' && pathname === '/api/v1/ems/payroll/my-config') {
      const empId = session.user.employeeId;
      if (!empId) {
        return sendJson(res, 200, {
          employeeId: null,
          salary: session.user.salary,
          hourlyRate: null,
          items: [],
          canManagePayroll: canManagePayroll(session),
        });
      }
      const compRes = await pool.query(
        `SELECT compensation_type, base_salary
         FROM hr.compensation
         WHERE employee_id = $1 AND compensation_type = 'hourly'
         ORDER BY effective_date DESC, created_at DESC
         LIMIT 1`,
        [empId]
      );
      const hourlyRate = compRes.rows.length > 0 && compRes.rows[0].base_salary != null
        ? Number(compRes.rows[0].base_salary)
        : null;
      const itemsRes = await pool.query(
        `SELECT id, employee_id, component_id, code, name, component_type, calc_mode, amount, max_cap, is_active, notes
         FROM hr.employee_payroll_items
         WHERE employee_id = $1
         ORDER BY created_at ASC`,
        [empId]
      );
      return sendJson(res, 200, {
        employeeId: empId,
        salary: session.user.salary,
        hourlyRate,
        items: itemsRes.rows.map(formatPayrollItemRow),
        canManagePayroll: canManagePayroll(session),
      });
    }

    // 12. GET /api/v1/ems/payroll/components
    if (req.method === 'GET' && pathname === '/api/v1/ems/payroll/components') {
      const comps = await pool.query(
        `SELECT id, code, name, component_type, is_statutory, is_active, description
         FROM hr.payroll_components
         ORDER BY is_statutory DESC, code ASC`
      );
      return sendJson(res, 200, {
        items: comps.rows.map((r) => ({
          id: r.id,
          code: r.code,
          name: r.name,
          componentType: r.component_type,
          isStatutory: Boolean(r.is_statutory),
          isActive: Boolean(r.is_active),
          description: r.description || '',
        })),
      });
    }

    // 13. POST /api/v1/ems/payroll/components (HR / Admin / Accountant / Owner)
    if (req.method === 'POST' && pathname === '/api/v1/ems/payroll/components') {
      if (!canManagePayroll(session)) {
        return sendJson(res, 403, { message: 'Forbidden: requires HR, Admin, or Accountant permission.' });
      }
      const body = await readJsonBody(req);
      const code = String(body.code || '').trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_');
      const name = String(body.name || '').trim();
      const componentType = body.componentType === 'earning' ? 'earning' : 'deduction';
      const isStatutory = Boolean(body.isStatutory);
      const description = body.description ? String(body.description).trim() : null;
      if (!code || !name) {
        return sendJson(res, 400, { message: 'Component code and name are required.' });
      }
      const id = crypto.randomUUID();
      const ins = await pool.query(
        `INSERT INTO hr.payroll_components (id, code, name, component_type, is_statutory, is_active, description, created_by)
         VALUES ($1, $2, $3, $4::hr.payroll_component_type, $5, true, $6, $7)
         RETURNING id, code, name, component_type, is_statutory, is_active, description`,
        [id, code, name, componentType, isStatutory, description, userId]
      );
      const r = ins.rows[0];
      return sendJson(res, 201, {
        id: r.id,
        code: r.code,
        name: r.name,
        componentType: r.component_type,
        isStatutory: Boolean(r.is_statutory),
        isActive: Boolean(r.is_active),
        description: r.description || '',
      });
    }

    // 14. DELETE /api/v1/ems/payroll/components/:id
    const compDeleteMatch = pathname.match(/^\/api\/v1\/ems\/payroll\/components\/([0-9a-fA-F-]+)$/);
    if (req.method === 'DELETE' && compDeleteMatch) {
      if (!canManagePayroll(session)) {
        return sendJson(res, 403, { message: 'Forbidden: requires HR, Admin, or Accountant permission.' });
      }
      await pool.query('DELETE FROM hr.payroll_components WHERE id = $1', [compDeleteMatch[1]]);
      return sendJson(res, 200, { ok: true });
    }

    // 15. GET /api/v1/ems/payroll/employees (HR / Admin / Accountant / Owner)
    if (req.method === 'GET' && pathname === '/api/v1/ems/payroll/employees') {
      if (!canManagePayroll(session)) {
        return sendJson(res, 403, { message: 'Forbidden: requires HR, Admin, or Accountant permission.' });
      }
      const empRes = await pool.query(
        `SELECT
           e.id AS employee_id,
           e.employee_code,
           e.employment_type,
           e.employment_status,
           e.salary,
           u.name AS legacy_name,
           u.department,
           up.first_name,
           up.last_name,
           ua.username,
           (
             SELECT c.base_salary
             FROM hr.compensation c
             WHERE c.employee_id = e.id AND c.compensation_type = 'hourly'
             ORDER BY c.effective_date DESC, c.created_at DESC
             LIMIT 1
           ) AS hourly_rate
         FROM core.employees e
         LEFT JOIN core.users u ON u.id = e.user_id
         LEFT JOIN core.user_profiles up ON up.user_id = e.user_id
         LEFT JOIN core.user_accounts ua ON ua.user_id = e.user_id
         ORDER BY e.employee_code ASC`
      );
      const itemsRes = await pool.query(
        `SELECT id, employee_id, component_id, code, name, component_type, calc_mode, amount, max_cap, is_active, notes
         FROM hr.employee_payroll_items
         ORDER BY created_at ASC`
      );
      const itemsByEmp = new Map();
      for (const row of itemsRes.rows) {
        const list = itemsByEmp.get(row.employee_id) || [];
        list.push(formatPayrollItemRow(row));
        itemsByEmp.set(row.employee_id, list);
      }
      const employees = empRes.rows.map((r) => {
        const fullName = [r.first_name, r.last_name].filter(Boolean).join(' ').trim() || r.legacy_name || r.username || 'Employee';
        return {
          employeeId: r.employee_id,
          employeeCode: r.employee_code != null ? String(r.employee_code) : null,
          name: fullName,
          department: r.department || null,
          employmentType: r.employment_type || null,
          employmentStatus: r.employment_status || 'active',
          salary: r.salary != null ? Number(r.salary) : null,
          hourlyRate: r.hourly_rate != null ? Number(r.hourly_rate) : null,
          items: itemsByEmp.get(r.employee_id) || [],
        };
      });
      return sendJson(res, 200, { employees });
    }

    // 16. PATCH /api/v1/ems/payroll/employees/:employeeId/rate
    const rateMatch = pathname.match(/^\/api\/v1\/ems\/payroll\/employees\/([0-9a-fA-F-]+)\/rate$/);
    if (req.method === 'PATCH' && rateMatch) {
      if (!canManagePayroll(session)) {
        return sendJson(res, 403, { message: 'Forbidden: requires HR, Admin, or Accountant permission.' });
      }
      const employeeId = rateMatch[1];
      const body = await readJsonBody(req);
      if (Object.prototype.hasOwnProperty.call(body, 'salary')) {
        const salaryVal = body.salary === null || body.salary === '' ? null : Number(body.salary);
        if (salaryVal !== null && (!Number.isFinite(salaryVal) || salaryVal < 0)) {
          return sendJson(res, 400, { message: 'Invalid salary amount.' });
        }
        await pool.query('UPDATE core.employees SET salary = $1, updated_at = NOW() WHERE id = $2', [salaryVal, employeeId]);
      }
      if (Object.prototype.hasOwnProperty.call(body, 'hourlyRate')) {
        const hrVal = body.hourlyRate === null || body.hourlyRate === '' ? null : Number(body.hourlyRate);
        if (hrVal !== null && (!Number.isFinite(hrVal) || hrVal <= 0)) {
          return sendJson(res, 400, { message: 'Invalid hourly rate.' });
        }
        await pool.query("DELETE FROM hr.compensation WHERE employee_id = $1 AND compensation_type = 'hourly'", [employeeId]);
        if (hrVal !== null) {
          await pool.query(
            `INSERT INTO hr.compensation (id, employee_id, compensation_type, base_salary, payment_frequency, effective_date, notes, created_by)
             VALUES ($1, $2, 'hourly'::hr.compensation_type, $3, 'hourly'::hr.payment_frequency, CURRENT_DATE, 'Updated via mobile payroll management', $4)`,
            [crypto.randomUUID(), employeeId, hrVal, userId]
          );
        }
      }
      return sendJson(res, 200, { ok: true, employeeId });
    }

    // 17. POST /api/v1/ems/payroll/employees/:employeeId/items
    const addItemMatch = pathname.match(/^\/api\/v1\/ems\/payroll\/employees\/([0-9a-fA-F-]+)\/items$/);
    if (req.method === 'POST' && addItemMatch) {
      if (!canManagePayroll(session)) {
        return sendJson(res, 403, { message: 'Forbidden: requires HR, Admin, or Accountant permission.' });
      }
      const employeeId = addItemMatch[1];
      const body = await readJsonBody(req);
      const name = String(body.name || '').trim();
      const code = String(body.code || name || 'CUSTOM').trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_').slice(0, 40) || 'CUSTOM';
      const componentType = body.componentType === 'earning' ? 'earning' : 'deduction';
      const calcMode = body.calcMode === 'percent' ? 'percent' : 'fixed';
      const amount = Number(body.amount);
      const maxCap = body.maxCap === null || body.maxCap === undefined || body.maxCap === '' ? null : Number(body.maxCap);
      const notes = body.notes ? String(body.notes).trim() : null;
      const componentId = body.componentId || null;

      if (!name || !Number.isFinite(amount) || amount < 0) {
        return sendJson(res, 400, { message: 'Valid item name and non-negative amount are required.' });
      }
      if (maxCap !== null && (!Number.isFinite(maxCap) || maxCap < 0)) {
        return sendJson(res, 400, { message: 'Invalid max cap value.' });
      }

      const id = crypto.randomUUID();
      const ins = await pool.query(
        `INSERT INTO hr.employee_payroll_items
           (id, employee_id, component_id, code, name, component_type, calc_mode, amount, max_cap, is_active, notes, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true, $10, $11)
         RETURNING id, employee_id, component_id, code, name, component_type, calc_mode, amount, max_cap, is_active, notes`,
        [id, employeeId, componentId, code, name, componentType, calcMode, amount, maxCap, notes, userId]
      );
      return sendJson(res, 201, formatPayrollItemRow(ins.rows[0]));
    }

    // 18. PATCH / DELETE /api/v1/ems/payroll/items/:itemId
    const itemMatch = pathname.match(/^\/api\/v1\/ems\/payroll\/items\/([0-9a-fA-F-]+)$/);
    if (itemMatch && (req.method === 'PATCH' || req.method === 'DELETE')) {
      if (!canManagePayroll(session)) {
        return sendJson(res, 403, { message: 'Forbidden: requires HR, Admin, or Accountant permission.' });
      }
      const itemId = itemMatch[1];
      if (req.method === 'DELETE') {
        await pool.query('DELETE FROM hr.employee_payroll_items WHERE id = $1', [itemId]);
        return sendJson(res, 200, { ok: true, id: itemId });
      }
      const body = await readJsonBody(req);
      const existing = await pool.query('SELECT * FROM hr.employee_payroll_items WHERE id = $1', [itemId]);
      if (existing.rows.length === 0) {
        return sendJson(res, 404, { message: 'Payroll item not found.' });
      }
      const cur = existing.rows[0];
      const name = body.name !== undefined ? String(body.name).trim() : cur.name;
      const componentType = body.componentType !== undefined ? (body.componentType === 'earning' ? 'earning' : 'deduction') : cur.component_type;
      const calcMode = body.calcMode !== undefined ? (body.calcMode === 'percent' ? 'percent' : 'fixed') : cur.calc_mode;
      const amount = body.amount !== undefined ? Number(body.amount) : Number(cur.amount);
      const maxCap = body.maxCap !== undefined
        ? (body.maxCap === null || body.maxCap === '' ? null : Number(body.maxCap))
        : (cur.max_cap != null ? Number(cur.max_cap) : null);
      const isActive = body.isActive !== undefined ? Boolean(body.isActive) : Boolean(cur.is_active);
      const notes = body.notes !== undefined ? (body.notes ? String(body.notes).trim() : null) : cur.notes;

      if (!name || !Number.isFinite(amount) || amount < 0) {
        return sendJson(res, 400, { message: 'Valid item name and non-negative amount are required.' });
      }
      const upd = await pool.query(
        `UPDATE hr.employee_payroll_items
         SET name = $1, component_type = $2, calc_mode = $3, amount = $4, max_cap = $5, is_active = $6, notes = $7, updated_at = NOW()
         WHERE id = $8
         RETURNING id, employee_id, component_id, code, name, component_type, calc_mode, amount, max_cap, is_active, notes`,
        [name, componentType, calcMode, amount, maxCap, isActive, notes, itemId]
      );
      return sendJson(res, 200, formatPayrollItemRow(upd.rows[0]));
    }

    // 19. GET /api/v1/ems/technician/my-jobs (Technician role ONLY — strictly own assigned jobs)
    if (req.method === 'GET' && pathname === '/api/v1/ems/technician/my-jobs') {
      if (!isTechnicianRole(session)) {
        return sendJson(res, 403, { message: 'Forbidden: Technician role required.' });
      }
      const { workDate, minutesOfDay } = getBangkokNow();

      const woRes = await pool.query(
        `SELECT wo.id, wo.number AS job_code, wo.title, wo.description,
                wo.status::text AS status, wo.priority::text AS priority,
                wo.project_id, wo.schedule_start, wo.schedule_end,
                u.name AS assigned_to_name,
                (wo.assigned_to = $1 OR EXISTS (
                  SELECT 1 FROM hr.work_assignments wa
                  WHERE wa.work_order_id = wo.id AND wa.user_id = $1
                )) AS is_mine
         FROM operations.work_orders wo
         LEFT JOIN core.users u ON u.id = wo.assigned_to
         WHERE wo.status::text NOT IN ('cancelled', 'completed')
           AND COALESCE(wo.number, '') <> '0'
         ORDER BY is_mine DESC, wo.number ASC`,
        [userId]
      );

      const sjRes = await pool.query(
        `SELECT sj.id, sj.job_number AS job_code, sj.title, sj.description,
                sj.status::text AS status, sj.priority::text AS priority,
                sj.project_id, sj.location, sj.client_name, sj.scheduled_date,
                EXISTS (
                  SELECT 1 FROM hr.work_assignments wa
                  WHERE wa.scheduled_job_id = sj.id AND wa.user_id = $1
                ) AS is_mine
         FROM operations.scheduled_jobs sj
         WHERE sj.status::text NOT IN ('cancelled', 'completed')
         ORDER BY is_mine DESC, sj.job_number ASC`,
        [userId]
      );

      const jobs = [
        ...woRes.rows.map((r) => ({
          id: r.id,
          jobCode: r.job_code || 'JOB',
          title: r.title || '',
          description: r.description || '',
          status: r.status || 'open',
          priority: r.priority || 'medium',
          jobSource: 'work_order',
          projectId: r.project_id || null,
          location: null,
          isMine: Boolean(r.is_mine),
          assignedToName: r.assigned_to_name || null,
          scheduleStart: formatPgDate(r.schedule_start),
          scheduleEnd: formatPgDate(r.schedule_end),
        })),
        ...sjRes.rows.map((r) => ({
          id: r.id,
          jobCode: r.job_code || 'JOB',
          title: r.title || '',
          description: r.description || '',
          status: r.status || 'scheduled',
          priority: r.priority || 'medium',
          jobSource: 'scheduled_job',
          projectId: r.project_id || null,
          location: r.location || r.client_name || null,
          isMine: Boolean(r.is_mine),
          assignedToName: null,
          scheduleStart: formatPgDate(r.scheduled_date),
          scheduleEnd: formatPgDate(r.scheduled_date),
        })),
      ].sort((a, b) => {
        if (a.isMine !== b.isMine) return a.isMine ? -1 : 1;
        return a.jobCode.localeCompare(b.jobCode);
      });

      const sessRes = await pool.query(
        `SELECT ws.id, ws.work_order_id, ws.scheduled_job_id, ws.project_id,
                ws.status::text AS status, ws.check_in_at, ws.check_out_at,
                ws.duration_minutes, ws.notes,
                ws.check_in_latitude, ws.check_in_longitude, ws.check_in_accuracy,
                ws.check_out_latitude, ws.check_out_longitude, ws.check_out_accuracy,
                ws.job_status_at_checkout,
                COALESCE(wo.number, sj.job_number, 'JOB') AS job_code,
                COALESCE(wo.title, sj.title, '') AS job_title,
                EXISTS (
                  SELECT 1 FROM operations.technician_reports tr
                  WHERE tr.work_session_id = ws.id
                ) AS report_submitted
         FROM hr.work_sessions ws
         LEFT JOIN operations.work_orders wo ON wo.id = ws.work_order_id
         LEFT JOIN operations.scheduled_jobs sj ON sj.id = ws.scheduled_job_id
         WHERE ws.user_id = $1
           AND (ws.check_in_at AT TIME ZONE 'Asia/Bangkok')::date = $2::date
         ORDER BY ws.check_in_at ASC`,
        [userId, workDate]
      );

      const formatWorkSession = (r) => ({
        id: r.id,
        jobId: r.work_order_id || r.scheduled_job_id,
        jobSource: r.work_order_id ? 'work_order' : 'scheduled_job',
        jobCode: r.job_code,
        jobTitle: r.job_title,
        status: r.status,
        checkInAt: r.check_in_at instanceof Date ? r.check_in_at.toISOString() : r.check_in_at,
        checkOutAt: r.check_out_at instanceof Date ? r.check_out_at.toISOString() : r.check_out_at,
        durationMinutes: r.duration_minutes != null ? Number(r.duration_minutes) : null,
        checkInLatitude: r.check_in_latitude != null ? Number(r.check_in_latitude) : null,
        checkInLongitude: r.check_in_longitude != null ? Number(r.check_in_longitude) : null,
        checkOutLatitude: r.check_out_latitude != null ? Number(r.check_out_latitude) : null,
        checkOutLongitude: r.check_out_longitude != null ? Number(r.check_out_longitude) : null,
        jobStatusAtCheckout: r.job_status_at_checkout || null,
        notes: r.notes || null,
        reportSubmitted: Boolean(r.report_submitted),
      });

      const todaySessions = sessRes.rows.map(formatWorkSession);

      // Find any completed session that finished the shift (not on_break / resumed) and has NOT submitted a report yet
      const pendingRepRes = await pool.query(
        `SELECT ws.id, ws.work_order_id, ws.scheduled_job_id, ws.project_id,
                ws.status::text AS status, ws.check_in_at, ws.check_out_at,
                ws.duration_minutes, ws.notes,
                ws.check_in_latitude, ws.check_in_longitude, ws.check_in_accuracy,
                ws.check_out_latitude, ws.check_out_longitude, ws.check_out_accuracy,
                ws.job_status_at_checkout,
                COALESCE(wo.number, sj.job_number, 'JOB') AS job_code,
                COALESCE(wo.title, sj.title, '') AS job_title,
                false AS report_submitted
         FROM hr.work_sessions ws
         LEFT JOIN operations.work_orders wo ON wo.id = ws.work_order_id
         LEFT JOIN operations.scheduled_jobs sj ON sj.id = ws.scheduled_job_id
         WHERE ws.user_id = $1
           AND ws.status = 'completed'
           AND COALESCE(ws.job_status_at_checkout, '') NOT IN ('on_break', 'resumed')
           AND NOT EXISTS (
             SELECT 1 FROM operations.technician_reports tr
             WHERE tr.work_session_id = ws.id
           )
         ORDER BY ws.check_out_at DESC NULLS LAST
         LIMIT 1`,
        [userId]
      );
      const pendingReportSession =
        pendingRepRes.rows.length > 0 ? formatWorkSession(pendingRepRes.rows[0]) : null;

      const activeSession = todaySessions.find((s) => s.status === 'active' && !s.checkOutAt) || null;
      const breakSession = !activeSession
        ? (todaySessions.slice().reverse().find((s) => s.status === 'completed' && s.jobStatusAtCheckout === 'on_break') || null)
        : null;

      const empCode = session.user && session.user.employeeCode ? String(session.user.employeeCode) : null;
      const deviceCodes = getDeviceCodesForEmployee(empCode);
      const scanRes = await pool.query(
        `SELECT DISTINCT window_code
         FROM hr.device_scans
         WHERE work_date = $1::date
           AND counted = true
           AND (user_id = $2 OR ($3::text[] IS NOT NULL AND device_user_code::text = ANY($3::text[])))`,
        [workDate, userId, deviceCodes.length > 0 ? deviceCodes : null]
      );
      const completedWindows = scanRes.rows.map((r) => r.window_code).filter(Boolean);

      let nextWindowCode = null;
      if (activeSession) {
        nextWindowCode =
          minutesOfDay >= 14 * 60 ||
          completedWindows.includes('lunch_out') ||
          completedWindows.includes('afternoon_in')
            ? 'leave'
            : 'lunch_out';
      } else {
        if (!completedWindows.includes('morning_in') && minutesOfDay < 13 * 60) {
          nextWindowCode = 'morning_in';
        } else if (!completedWindows.includes('leave')) {
          nextWindowCode = 'afternoon_in';
        }
      }

      return sendJson(res, 200, {
        workDate,
        jobs,
        activeSession,
        breakSession,
        pendingReportSession,
        todaySessions,
        completedWindows,
        nextWindowCode,
      });
    }

    // 20. POST /api/v1/ems/technician/check-in
    if (req.method === 'POST' && pathname === '/api/v1/ems/technician/check-in') {
      if (!isTechnicianRole(session)) {
        return sendJson(res, 403, { message: 'Forbidden: Technician role required.' });
      }
      const body = await readJsonBody(req);
      const jobId = String(body.jobId || '').trim();
      const jobSource = body.jobSource === 'scheduled_job' ? 'scheduled_job' : 'work_order';
      const windowCode = body.windowCode === 'afternoon_in' ? 'afternoon_in' : 'morning_in';
      const latitude = body.latitude != null ? Number(body.latitude) : null;
      const longitude = body.longitude != null ? Number(body.longitude) : null;
      const accuracy = body.accuracy != null ? Number(body.accuracy) : null;
      const photoStorageKey = body.photoStorageKey ? String(body.photoStorageKey) : null;
      const notes = body.notes ? String(body.notes).trim() : null;

      if (!jobId) {
        return sendJson(res, 400, { message: 'Please select a Job Code first.' });
      }

      // Verify ownership: job MUST be assigned to this technician
      let projectId = null;
      let jobCode = 'JOB';
      let jobTitle = '';
      if (jobSource === 'work_order') {
        const own = await pool.query(
          `SELECT wo.id, wo.number, wo.title, wo.project_id
           FROM operations.work_orders wo
           LEFT JOIN hr.work_assignments wa ON wa.work_order_id = wo.id
           WHERE wo.id = $1 AND (wo.assigned_to = $2 OR wa.user_id = $2)
           LIMIT 1`,
          [jobId, userId]
        );
        if (own.rows.length === 0) {
          return sendJson(res, 403, { message: 'This job is not assigned to your account.' });
        }
        projectId = own.rows[0].project_id;
        jobCode = own.rows[0].number || 'JOB';
        jobTitle = own.rows[0].title || '';
      } else {
        const own = await pool.query(
          `SELECT sj.id, sj.job_number, sj.title, sj.project_id
           FROM operations.scheduled_jobs sj
           JOIN hr.work_assignments wa ON wa.scheduled_job_id = sj.id
           WHERE sj.id = $1 AND wa.user_id = $2
           LIMIT 1`,
          [jobId, userId]
        );
        if (own.rows.length === 0) {
          return sendJson(res, 403, { message: 'This job is not assigned to your account.' });
        }
        projectId = own.rows[0].project_id;
        jobCode = own.rows[0].job_number || 'JOB';
        jobTitle = own.rows[0].title || '';
      }

      // Mandatory report gate: block new check-in if a previous completed session has no report
      const unreportedCheck = await pool.query(
        `SELECT ws.id, COALESCE(wo.number, sj.job_number, 'JOB') AS job_code
         FROM hr.work_sessions ws
         LEFT JOIN operations.work_orders wo ON wo.id = ws.work_order_id
         LEFT JOIN operations.scheduled_jobs sj ON sj.id = ws.scheduled_job_id
         WHERE ws.user_id = $1
           AND ws.status = 'completed'
           AND COALESCE(ws.job_status_at_checkout, '') NOT IN ('on_break', 'resumed')
           AND NOT EXISTS (
             SELECT 1 FROM operations.technician_reports tr
             WHERE tr.work_session_id = ws.id
           )
         LIMIT 1`,
        [userId]
      );
      if (unreportedCheck.rows.length > 0) {
        return sendJson(res, 409, {
          errorCode: 'PENDING_TECHNICIAN_REPORT',
          message: `Please submit the work report for ${unreportedCheck.rows[0].job_code} before checking in to another job.`,
        });
      }

      // If resuming from an active break, mark the prior break session as resumed
      await pool.query(
        `UPDATE hr.work_sessions
         SET job_status_at_checkout = 'resumed', updated_at = NOW()
         WHERE user_id = $1 AND status = 'completed' AND job_status_at_checkout = 'on_break'`,
        [userId]
      );

      // Prevent duplicate active session
      const activeCheck = await pool.query(
        `SELECT id FROM hr.work_sessions WHERE user_id = $1 AND status = 'active' AND check_out_at IS NULL LIMIT 1`,
        [userId]
      );
      if (activeCheck.rows.length > 0) {
        return sendJson(res, 409, { message: 'You already have an active job session. Please check out first.' });
      }

      const sessionId = crypto.randomUUID();
      const wsIns = await pool.query(
        `INSERT INTO hr.work_sessions
           (id, user_id, project_id, work_order_id, scheduled_job_id, status,
            check_in_at, started_at, check_in_selfie_storage_key,
            check_in_latitude, check_in_longitude, check_in_accuracy,
            notes, created_by)
         VALUES ($1, $2, $3, $4, $5, 'active'::hr.work_session_status,
                 NOW(), NOW(), $6, $7, $8, $9, $10, $2)
         RETURNING *`,
        [
          sessionId,
          userId,
          null,
          jobSource === 'work_order' ? jobId : null,
          jobSource === 'scheduled_job' ? jobId : null,
          photoStorageKey,
          latitude,
          longitude,
          accuracy,
          notes,
        ]
      );

      // Sync to hr.device_scans so History & Pay Estimate count this technician's hours automatically
      const { workDate, minutesOfDay } = getBangkokNow();
      const empCodeNum = session.user && session.user.employeeCode ? (Number(session.user.employeeCode) || 0) : 0;
      const priorScanRes = await pool.query(
        `SELECT DISTINCT window_code FROM hr.device_scans
         WHERE work_date = $1::date AND counted = true AND user_id = $2`,
        [workDate, userId]
      );
      const priorWindows = priorScanRes.rows.map((r) => r.window_code);
      const autoInWindowCode =
        minutesOfDay >= 13 * 60 || priorWindows.includes('morning_in')
          ? 'afternoon_in'
          : 'morning_in';
      const scanIns = await pool.query(
        `INSERT INTO hr.device_scans
           (id, device_id, machine_no, device_user_code, user_id, scanned_at, received_at, work_date,
            window_code, counted, not_counted_reason, flag, source, client_request_id,
            latitude, longitude, accuracy, photo_storage_key)
         VALUES ($1, 'APP', 0, $2, $3, NOW(), NOW(), $4::date,
                 $5, true, NULL, NULL, 'app', $6, $7, $8, $9, $10)
         RETURNING *`,
        [
          crypto.randomUUID(),
          empCodeNum,
          userId,
          workDate,
          autoInWindowCode,
          crypto.randomUUID(),
          latitude,
          longitude,
          accuracy,
          photoStorageKey,
        ]
      );

      return sendJson(res, 201, {
        session: {
          id: wsIns.rows[0].id,
          jobId,
          jobSource,
          jobCode,
          jobTitle,
          status: wsIns.rows[0].status,
          checkInAt: wsIns.rows[0].check_in_at instanceof Date ? wsIns.rows[0].check_in_at.toISOString() : wsIns.rows[0].check_in_at,
          checkInLatitude: latitude,
          checkInLongitude: longitude,
        },
        scan: formatScanRow(scanIns.rows[0]),
      });
    }

    // 21. POST /api/v1/ems/technician/check-out
    if (req.method === 'POST' && pathname === '/api/v1/ems/technician/check-out') {
      if (!isTechnicianRole(session)) {
        return sendJson(res, 403, { message: 'Forbidden: Technician role required.' });
      }
      const body = await readJsonBody(req);
      const sessionId = String(body.sessionId || '').trim();
      const windowCode = body.windowCode === 'lunch_out' ? 'lunch_out' : 'leave';
      const jobStatus = body.jobStatus ? String(body.jobStatus).trim() : 'in_progress';
      const latitude = body.latitude != null ? Number(body.latitude) : null;
      const longitude = body.longitude != null ? Number(body.longitude) : null;
      const accuracy = body.accuracy != null ? Number(body.accuracy) : null;
      const photoStorageKey = body.photoStorageKey ? String(body.photoStorageKey) : null;
      const notes = body.notes ? String(body.notes).trim() : null;

      if (!sessionId) {
        return sendJson(res, 400, { message: 'Active sessionId is required.' });
      }

      const existing = await pool.query(
        `SELECT * FROM hr.work_sessions WHERE id = $1 AND user_id = $2 AND status = 'active' LIMIT 1`,
        [sessionId, userId]
      );
      if (existing.rows.length === 0) {
        return sendJson(res, 404, { message: 'Active job session not found.' });
      }

      const wsUpd = await pool.query(
        `UPDATE hr.work_sessions
         SET status = 'completed'::hr.work_session_status,
             check_out_at = NOW(),
             check_out_selfie_storage_key = $1,
             check_out_latitude = $2,
             check_out_longitude = $3,
             check_out_accuracy = $4,
             job_status_at_checkout = $5,
             checkout_type = 'manual'::hr.checkout_type,
             notes = COALESCE($6, notes),
             updated_at = NOW()
         WHERE id = $7
         RETURNING *`,
        [photoStorageKey, latitude, longitude, accuracy, jobStatus, notes, sessionId]
      );

      // If technician marked job as Completed, close the underlying work_order / scheduled_job
      // so it leaves the active queue and decrements the pending job badge count.
      if (jobStatus === 'completed') {
        const curWs = existing.rows[0];
        if (curWs.work_order_id) {
          await pool.query(
            `UPDATE operations.work_orders
             SET status = 'completed'::operations.work_order_status,
                 completed_date = CURRENT_DATE,
                 updated_at = NOW()
             WHERE id = $1`,
            [curWs.work_order_id]
          );
        } else if (curWs.scheduled_job_id) {
          await pool.query(
            `UPDATE operations.scheduled_jobs
             SET status = 'completed'::operations.scheduled_job_status,
                 actual_end_time = NOW(),
                 updated_at = NOW()
             WHERE id = $1`,
            [curWs.scheduled_job_id]
          );
        }
      }

      const { workDate, minutesOfDay } = getBangkokNow();
      const empCodeNum = session.user && session.user.employeeCode ? (Number(session.user.employeeCode) || 0) : 0;
      const priorScanRes = await pool.query(
        `SELECT DISTINCT window_code FROM hr.device_scans
         WHERE work_date = $1::date AND counted = true AND user_id = $2`,
        [workDate, userId]
      );
      const priorWindows = priorScanRes.rows.map((r) => r.window_code);
      const autoWindowCode =
        minutesOfDay >= 14 * 60 ||
        priorWindows.includes('lunch_out') ||
        priorWindows.includes('afternoon_in')
          ? 'leave'
          : 'lunch_out';
      const scanIns = await pool.query(
        `INSERT INTO hr.device_scans
           (id, device_id, machine_no, device_user_code, user_id, scanned_at, received_at, work_date,
            window_code, counted, not_counted_reason, flag, source, client_request_id,
            latitude, longitude, accuracy, photo_storage_key)
         VALUES ($1, 'APP', 0, $2, $3, NOW(), NOW(), $4::date,
                 $5, true, NULL, NULL, 'app', $6, $7, $8, $9, $10)
         RETURNING *`,
        [
          crypto.randomUUID(),
          empCodeNum,
          userId,
          workDate,
          autoWindowCode,
          crypto.randomUUID(),
          latitude,
          longitude,
          accuracy,
          photoStorageKey,
        ]
      );

      return sendJson(res, 200, {
        session: {
          id: wsUpd.rows[0].id,
          jobId: wsUpd.rows[0].work_order_id || wsUpd.rows[0].scheduled_job_id,
          jobSource: wsUpd.rows[0].work_order_id ? 'work_order' : 'scheduled_job',
          status: wsUpd.rows[0].status,
          checkInAt: wsUpd.rows[0].check_in_at instanceof Date ? wsUpd.rows[0].check_in_at.toISOString() : wsUpd.rows[0].check_in_at,
          checkOutAt: wsUpd.rows[0].check_out_at instanceof Date ? wsUpd.rows[0].check_out_at.toISOString() : wsUpd.rows[0].check_out_at,
          durationMinutes: wsUpd.rows[0].duration_minutes != null ? Number(wsUpd.rows[0].duration_minutes) : null,
          jobStatusAtCheckout: wsUpd.rows[0].job_status_at_checkout,
          reportSubmitted: false,
        },
        scan: formatScanRow(scanIns.rows[0]),
      });
    }

    // 22. POST /api/v1/ems/technician/reports (Mandatory work report after checkout)
    if (req.method === 'POST' && pathname === '/api/v1/ems/technician/reports') {
      if (!isTechnicianRole(session)) {
        return sendJson(res, 403, { message: 'Forbidden: Technician role required.' });
      }
      const body = await readJsonBody(req);
      const sessionId = String(body.sessionId || '').trim();
      const workDescription = String(body.workDescription || '').trim();
      const allowedTypes = new Set(['repair', 'maintenance', 'installation', 'inspection', 'service', 'other']);
      const rawType = String(body.workType || 'service').toLowerCase().trim();
      const workType = allowedTypes.has(rawType) ? rawType : 'service';
      const findings = body.findings ? String(body.findings).trim() : null;
      const recommendations = body.recommendations ? String(body.recommendations).trim() : null;
      const photos = Array.isArray(body.photos)
        ? body.photos.map((p) => String(p).trim()).filter(Boolean).slice(0, 6)
        : [];

      if (!sessionId) {
        return sendJson(res, 400, { message: 'sessionId is required.' });
      }
      if (workDescription.length < 5) {
        return sendJson(res, 400, { message: 'Please enter a work report description (at least 5 characters).' });
      }

      const sessCheck = await pool.query(
        `SELECT * FROM hr.work_sessions WHERE id = $1 AND user_id = $2 LIMIT 1`,
        [sessionId, userId]
      );
      if (sessCheck.rows.length === 0) {
        return sendJson(res, 404, { message: 'Work session not found.' });
      }
      const ws = sessCheck.rows[0];

      // Idempotent guard: if already submitted for this session, return existing
      const dupRep = await pool.query(
        `SELECT id, report_number, status::text AS status FROM operations.technician_reports WHERE work_session_id = $1 LIMIT 1`,
        [sessionId]
      );
      if (dupRep.rows.length > 0) {
        return sendJson(res, 200, { report: dupRep.rows[0] });
      }

      const { workDate, minutesOfDay } = getBangkokNow();
      const reportNumber = `TR-${workDate.replace(/-/g, '')}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
      const hoursWorked = ws.duration_minutes != null ? Number((Number(ws.duration_minutes) / 60).toFixed(2)) : 0;

      const repIns = await pool.query(
        `INSERT INTO operations.technician_reports
           (id, report_number, date, technician_id, project_id, work_order_id, scheduled_job_id,
            work_description, work_type, start_time, end_time, hours_worked,
            findings, recommendations, photos, status, created_by, work_session_id, auto_generated, report_kind)
         VALUES ($1, $2, NOW(), $3, $4, $5, $6,
                 $7, $8::operations.work_type, $9, COALESCE($10, NOW()), $11,
                 $12, $13, $14::jsonb, 'submitted'::operations.technician_report_status, $3, $15, false, 'field'::operations.report_kind)
         RETURNING id, report_number, status::text AS status, work_session_id, photos`,
        [
          crypto.randomUUID(),
          reportNumber,
          userId,
          ws.project_id,
          ws.work_order_id,
          ws.scheduled_job_id,
          workDescription,
          workType,
          ws.check_in_at,
          ws.check_out_at,
          hoursWorked,
          findings,
          recommendations,
          JSON.stringify(photos),
          sessionId,
        ]
      );

      return sendJson(res, 201, { report: repIns.rows[0] });
    }

    // 23. GET /api/v1/ems/technician/history (Job & Report History — Technician sees own, Admin sees all)
    if (req.method === 'GET' && pathname === '/api/v1/ems/technician/history') {
      if (!isTechnicianRole(session)) {
        return sendJson(res, 403, { message: 'Forbidden: Technician or Admin role required.' });
      }
      const isAdmin = (session.roles || []).some((r) => String(r).toLowerCase().trim() === 'admin');
      const histRes = await pool.query(
        `SELECT ws.id AS session_id,
                ws.user_id,
                u.name AS technician_name,
                COALESCE(wo.number, sj.job_number, 'JOB') AS job_code,
                COALESCE(wo.title, sj.title, '') AS job_title,
                ws.status::text AS session_status,
                ws.check_in_at,
                ws.check_out_at,
                ws.duration_minutes,
                ws.job_status_at_checkout,
                ws.check_in_latitude,
                ws.check_in_longitude,
                tr.id AS report_id,
                tr.report_number,
                tr.work_type::text AS work_type,
                tr.work_description,
                tr.findings,
                tr.recommendations,
                tr.photos,
                tr.status::text AS report_status,
                tr.hours_worked,
                tr.created_at AS report_created_at
         FROM hr.work_sessions ws
         LEFT JOIN core.users u ON u.id = ws.user_id
         LEFT JOIN operations.work_orders wo ON wo.id = ws.work_order_id
         LEFT JOIN operations.scheduled_jobs sj ON sj.id = ws.scheduled_job_id
         LEFT JOIN operations.technician_reports tr ON tr.work_session_id = ws.id
         WHERE ($1::boolean = true OR ws.user_id = $2)
         ORDER BY ws.check_in_at DESC
         LIMIT 100`,
        [isAdmin, userId]
      );

      const items = histRes.rows.map((r) => ({
        sessionId: r.session_id,
        technicianName: r.technician_name || 'Technician',
        isMine: r.user_id === userId,
        jobCode: r.job_code,
        jobTitle: r.job_title,
        sessionStatus: r.session_status,
        checkInAt: r.check_in_at instanceof Date ? r.check_in_at.toISOString() : r.check_in_at,
        checkOutAt: r.check_out_at instanceof Date ? r.check_out_at.toISOString() : r.check_out_at,
        durationMinutes: r.duration_minutes != null ? Number(r.duration_minutes) : null,
        jobStatusAtCheckout: r.job_status_at_checkout || null,
        hasGps: r.check_in_latitude != null && r.check_in_longitude != null,
        reportId: r.report_id || null,
        reportNumber: r.report_number || null,
        workType: r.work_type || null,
        workDescription: r.work_description || null,
        findings: r.findings || null,
        recommendations: r.recommendations || null,
        photoCount: Array.isArray(r.photos) ? r.photos.length : 0,
        reportStatus: r.report_status || null,
        hoursWorked: r.hours_worked != null ? Number(r.hours_worked) : null,
      }));

      return sendJson(res, 200, { isAdmin, items });
    }

    // 24. POST /api/v1/ems/technician/break (Pause active session for lunch / mid-shift break)
    if (req.method === 'POST' && pathname === '/api/v1/ems/technician/break') {
      if (!isTechnicianRole(session)) {
        return sendJson(res, 403, { message: 'Forbidden: Technician role required.' });
      }
      const body = await readJsonBody(req);
      const sessionId = String(body.sessionId || '').trim();
      const latitude = body.latitude != null ? Number(body.latitude) : null;
      const longitude = body.longitude != null ? Number(body.longitude) : null;
      const accuracy = body.accuracy != null ? Number(body.accuracy) : null;
      const photoStorageKey = body.photoStorageKey ? String(body.photoStorageKey) : null;

      if (!sessionId) {
        return sendJson(res, 400, { message: 'Active sessionId is required.' });
      }
      const existing = await pool.query(
        `SELECT * FROM hr.work_sessions WHERE id = $1 AND user_id = $2 AND status = 'active' LIMIT 1`,
        [sessionId, userId]
      );
      if (existing.rows.length === 0) {
        return sendJson(res, 404, { message: 'Active job session not found.' });
      }

      const wsUpd = await pool.query(
        `UPDATE hr.work_sessions
         SET status = 'completed'::hr.work_session_status,
             check_out_at = NOW(),
             check_out_selfie_storage_key = $1,
             check_out_latitude = $2,
             check_out_longitude = $3,
             check_out_accuracy = $4,
             job_status_at_checkout = 'on_break',
             checkout_type = 'manual'::hr.checkout_type,
             updated_at = NOW()
         WHERE id = $5
         RETURNING *`,
        [photoStorageKey, latitude, longitude, accuracy, sessionId]
      );

      const { workDate } = getBangkokNow();
      const empCodeNum = session.user && session.user.employeeCode ? (Number(session.user.employeeCode) || 0) : 0;
      const scanIns = await pool.query(
        `INSERT INTO hr.device_scans
           (id, device_id, machine_no, device_user_code, user_id, scanned_at, received_at, work_date,
            window_code, counted, not_counted_reason, flag, source, client_request_id,
            latitude, longitude, accuracy, photo_storage_key)
         VALUES ($1, 'APP', 0, $2, $3, NOW(), NOW(), $4::date,
                 'lunch_out', true, NULL, NULL, 'app', $5, $6, $7, $8, $9)
         RETURNING *`,
        [
          crypto.randomUUID(),
          empCodeNum,
          userId,
          workDate,
          crypto.randomUUID(),
          latitude,
          longitude,
          accuracy,
          photoStorageKey,
        ]
      );

      return sendJson(res, 200, {
        session: {
          id: wsUpd.rows[0].id,
          status: wsUpd.rows[0].status,
          jobStatusAtCheckout: 'on_break',
          checkOutAt: wsUpd.rows[0].check_out_at instanceof Date ? wsUpd.rows[0].check_out_at.toISOString() : wsUpd.rows[0].check_out_at,
          durationMinutes: wsUpd.rows[0].duration_minutes != null ? Number(wsUpd.rows[0].duration_minutes) : null,
        },
        scan: formatScanRow(scanIns.rows[0]),
      });
    }

    // 25. POST /api/v1/ems/technician/end-from-break (End shift directly while on break -> triggers mandatory report)
    if (req.method === 'POST' && pathname === '/api/v1/ems/technician/end-from-break') {
      if (!isTechnicianRole(session)) {
        return sendJson(res, 403, { message: 'Forbidden: Technician role required.' });
      }
      const body = await readJsonBody(req);
      const sessionId = String(body.sessionId || '').trim();
      const jobStatus = body.jobStatus === 'completed' ? 'completed' : 'in_progress';
      if (!sessionId) {
        return sendJson(res, 400, { message: 'sessionId is required.' });
      }
      const existing = await pool.query(
        `SELECT * FROM hr.work_sessions WHERE id = $1 AND user_id = $2 AND job_status_at_checkout = 'on_break' LIMIT 1`,
        [sessionId, userId]
      );
      if (existing.rows.length === 0) {
        return sendJson(res, 404, { message: 'Break session not found.' });
      }

      const wsUpd = await pool.query(
        `UPDATE hr.work_sessions
         SET job_status_at_checkout = $1, updated_at = NOW()
         WHERE id = $2
         RETURNING *`,
        [jobStatus, sessionId]
      );

      if (jobStatus === 'completed') {
        const curWs = existing.rows[0];
        if (curWs.work_order_id) {
          await pool.query(
            `UPDATE operations.work_orders
             SET status = 'completed'::operations.work_order_status,
                 completed_date = CURRENT_DATE,
                 updated_at = NOW()
             WHERE id = $1`,
            [curWs.work_order_id]
          );
        } else if (curWs.scheduled_job_id) {
          await pool.query(
            `UPDATE operations.scheduled_jobs
             SET status = 'completed'::operations.scheduled_job_status,
                 actual_end_time = NOW(),
                 updated_at = NOW()
             WHERE id = $1`,
            [curWs.scheduled_job_id]
          );
        }
      }

      return sendJson(res, 200, {
        session: {
          id: wsUpd.rows[0].id,
          status: wsUpd.rows[0].status,
          jobStatusAtCheckout: jobStatus,
          checkInAt: wsUpd.rows[0].check_in_at instanceof Date ? wsUpd.rows[0].check_in_at.toISOString() : wsUpd.rows[0].check_in_at,
          checkOutAt: wsUpd.rows[0].check_out_at instanceof Date ? wsUpd.rows[0].check_out_at.toISOString() : wsUpd.rows[0].check_out_at,
          durationMinutes: wsUpd.rows[0].duration_minutes != null ? Number(wsUpd.rows[0].duration_minutes) : null,
        },
      });
    }

    return sendJson(res, 404, { message: `Endpoint not found: ${req.method} ${pathname}` });
  } catch (err) {
    console.error('[SERVER ERROR]', err);
    return sendJson(res, 500, {
      errorCode: 'INTERNAL_SERVER_ERROR',
      message: err.message || 'Internal server error',
    });
  }
});

ensurePayrollSchema()
  .then(() => ensureSampleTechnicianJobs())
  .then(() => {
    server.listen(PORT, '127.0.0.1', () => {
      console.log(`Cirrus EMS Local Database Bridge listening on http://127.0.0.1:${PORT}/api/v1/ems`);
    });
  })
  .catch((err) => {
    console.error('[BOOT ERROR] Failed to initialize payroll schema:', err);
    process.exit(1);
  });
