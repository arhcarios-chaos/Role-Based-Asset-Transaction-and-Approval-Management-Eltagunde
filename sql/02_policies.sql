-- =====================================================================
-- 02_policies.sql
-- Row Level Security (RLS): database-level enforcement of role access.
-- Run AFTER 01_schema.sql.
-- =====================================================================

alter table profiles enable row level security;
alter table equipment enable row level security;
alter table borrowing_requests enable row level security;
alter table maintenance_requests enable row level security;
alter table audit_logs enable row level security;

-- Helper: current user's role, read from profiles.
create or replace function current_role_name()
returns user_role
language sql
security definer
stable
as $$
  select role from profiles where id = auth.uid();
$$;

-- ---------- PROFILES ----------
-- Everyone can read their own profile; Admin can read all (for user management).
create policy profiles_select_own on profiles
  for select using (id = auth.uid() or current_role_name() = 'administrator');

-- Only Administrator can update roles / manage users.
create policy profiles_update_admin on profiles
  for update using (current_role_name() = 'administrator');

-- ---------- EQUIPMENT ----------
-- All authenticated roles can view equipment (needed to browse & request).
create policy equipment_select_all on equipment
  for select using (auth.role() = 'authenticated');

-- Staff and Administrator can add/update equipment records.
create policy equipment_write_staff_admin on equipment
  for insert with check (current_role_name() in ('staff', 'administrator'));

create policy equipment_update_staff_admin on equipment
  for update using (current_role_name() in ('staff', 'administrator'));

-- Only Administrator can delete equipment.
create policy equipment_delete_admin on equipment
  for delete using (current_role_name() = 'administrator');

-- ---------- BORROWING REQUESTS ----------
-- Requesters see only their own requests; Staff/Admin see all.
create policy requests_select on borrowing_requests
  for select using (
    requester_id = auth.uid()
    or current_role_name() in ('staff', 'administrator')
  );

-- Any authenticated user (Requester, Staff, Admin) may submit a request for themself.
-- BR-A4-01 (equipment must be Available) is enforced in submit_borrowing_request().
create policy requests_insert_own on borrowing_requests
  for insert with check (requester_id = auth.uid());

-- Direct table UPDATEs are blocked for everyone; all status transitions
-- (approve/reject/release/return/close) must go through the SECURITY DEFINER
-- functions in 03_functions.sql, which enforce BR-A4-02 .. BR-A4-09 and write
-- the audit trail atomically. No UPDATE policy is created here on purpose.

-- ---------- MAINTENANCE REQUESTS ----------
create policy maintenance_select on maintenance_requests
  for select using (current_role_name() in ('staff', 'administrator'));

create policy maintenance_insert_staff on maintenance_requests
  for insert with check (current_role_name() in ('staff', 'administrator'));

create policy maintenance_update_staff_admin on maintenance_requests
  for update using (current_role_name() in ('staff', 'administrator'));

-- ---------- AUDIT LOGS ----------
-- Only Administrator may view the audit trail.
create policy audit_select_admin on audit_logs
  for select using (current_role_name() = 'administrator');

-- No direct INSERT policy for regular clients: audit rows are written only
-- by the SECURITY DEFINER functions below (which run with elevated rights),
-- so the audit trail cannot be forged or bypassed from the client.
