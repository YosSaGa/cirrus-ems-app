-- ============================================================================
-- Migration: 001_employee_payroll_items.sql
-- Purpose  : Add hr.employee_payroll_items table and seed default deduction
--            components in hr.payroll_components for the Cirrus EMS mobile app
--            (Payroll & Deductions management + Pay Estimate deductions).
-- Safe     : Idempotent (safe to re-run). Does NOT modify existing tables.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS hr.employee_payroll_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
  component_id uuid REFERENCES hr.payroll_components(id) ON DELETE SET NULL,
  code text NOT NULL,
  name text NOT NULL,
  component_type text NOT NULL DEFAULT 'deduction'
    CHECK (component_type IN ('deduction', 'earning')),
  calc_mode text NOT NULL DEFAULT 'fixed'
    CHECK (calc_mode IN ('fixed', 'percent')),
  amount numeric(12,2) NOT NULL DEFAULT 0,
  max_cap numeric(12,2),
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  created_by uuid
);

CREATE INDEX IF NOT EXISTS idx_employee_payroll_items_employee_id
  ON hr.employee_payroll_items (employee_id);

CREATE INDEX IF NOT EXISTS idx_employee_payroll_items_component_id
  ON hr.employee_payroll_items (component_id);

CREATE INDEX IF NOT EXISTS idx_employee_payroll_items_active
  ON hr.employee_payroll_items (employee_id, is_active);

-- Seed default deduction components in hr.payroll_components if missing.
DO $$
DECLARE
  v_seed_user_id uuid;
BEGIN
  SELECT user_id
  INTO v_seed_user_id
  FROM core.user_accounts
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_seed_user_id IS NULL THEN
    RAISE NOTICE 'No user in core.user_accounts; skipping hr.payroll_components seed.';
    RETURN;
  END IF;

  INSERT INTO hr.payroll_components (
    id, code, name, component_type, is_statutory, is_active, description, created_by
  )
  SELECT
    gen_random_uuid(),
    v.code,
    v.name,
    v.component_type::hr.payroll_component_type,
    v.is_statutory,
    true,
    v.description,
    v_seed_user_id
  FROM (
    VALUES
      (
        'ACCOMMODATION',
        'Accommodation (ค่าที่พัก)',
        'deduction',
        false,
        'Monthly staff accommodation / dormitory deduction'
      ),
      (
        'SOCIAL_SECURITY',
        'Social Security (ค่าประกันสังคม)',
        'deduction',
        true,
        'Statutory social security contribution (e.g. 5%, max 750 THB)'
      ),
      (
        'WORK_INSURANCE',
        'Work Insurance (ค่าประกันงาน)',
        'deduction',
        false,
        'Work / job guarantee insurance deduction'
      )
  ) AS v(code, name, component_type, is_statutory, description)
  WHERE NOT EXISTS (
    SELECT 1
    FROM hr.payroll_components pc
    WHERE pc.code = v.code
  );
END $$;

COMMIT;

-- ============================================================================
-- Rollback (uncomment if needed)
-- ============================================================================
-- DROP TABLE IF EXISTS hr.employee_payroll_items;
