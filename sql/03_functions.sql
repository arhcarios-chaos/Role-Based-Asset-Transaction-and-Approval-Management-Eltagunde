-- =====================================================================
-- 03_functions.sql
-- Core workflow logic. Each function enforces one or more BR-A4 rules
-- and writes an audit_logs entry in the SAME transaction, so a status
-- change can never happen without being logged (BR-A4-10).
-- Run AFTER 01_schema.sql and 02_policies.sql.
-- =====================================================================

-- Small internal helper to insert an audit row.
create or replace function log_action(
  p_action text, p_module text, p_record_id text, p_description text
) returns void
language plpgsql
security definer
as $$
begin
  insert into audit_logs (user_id, action, module, record_id, description)
  values (auth.uid(), p_action, p_module, p_record_id, p_description);
end;
$$;

-- ---------------------------------------------------------------------
-- submit_borrowing_request
-- Any authenticated user requests equipment.
-- BR-A4-01: only Available equipment may be requested.
-- BR-A4-09: equipment under Maintenance cannot be borrowed.
-- ---------------------------------------------------------------------
create or replace function submit_borrowing_request(
  p_equipment_id bigint, p_purpose text, p_due_date date default null
) returns bigint
language plpgsql
security definer
as $$
declare
  v_status equipment_status;
  v_new_id bigint;
begin
  select status into v_status from equipment where id = p_equipment_id for update;

  if v_status is null then
    raise exception 'Equipment not found';
  end if;

  if v_status = 'Maintenance' then
    raise exception 'BR-A4-09: Equipment is under maintenance and cannot be borrowed';
  end if;

  if v_status <> 'Available' then
    raise exception 'BR-A4-01: Only available equipment may be requested';
  end if;

  insert into borrowing_requests (requester_id, equipment_id, purpose, due_date, status)
  values (auth.uid(), p_equipment_id, p_purpose, p_due_date, 'Pending')
  returning id into v_new_id;

  perform log_action('SUBMITTED', 'Borrowing', v_new_id::text,
    'Submitted borrowing request for equipment ID ' || p_equipment_id);

  return v_new_id;
end;
$$;

-- ---------------------------------------------------------------------
-- approve_request
-- BR-A4-03: only Administrator may approve.
-- BR-A4-02: staff/admin cannot approve their own request.
-- ---------------------------------------------------------------------
create or replace function approve_request(p_request_id bigint)
returns void
language plpgsql
security definer
as $$
declare
  v_requester uuid;
  v_status request_status;
begin
  if current_role_name() <> 'administrator' then
    raise exception 'BR-A4-03: Only Administrator may approve requests';
  end if;

  select requester_id, status into v_requester, v_status
  from borrowing_requests where id = p_request_id for update;

  if v_status is null then
    raise exception 'Request not found';
  end if;

  if v_requester = auth.uid() then
    raise exception 'BR-A4-02: You cannot approve your own request';
  end if;

  if v_status <> 'Pending' then
    raise exception 'Only Pending requests can be approved';
  end if;

  update borrowing_requests
  set status = 'Approved', approved_by = auth.uid(), approved_at = now()
  where id = p_request_id;

  perform log_action('APPROVED', 'Borrowing', p_request_id::text,
    'Approved borrowing request #' || p_request_id);
end;
$$;

-- ---------------------------------------------------------------------
-- reject_request
-- BR-A4-03: only Administrator may reject.
-- ---------------------------------------------------------------------
create or replace function reject_request(p_request_id bigint, p_reason text default null)
returns void
language plpgsql
security definer
as $$
declare
  v_status request_status;
begin
  if current_role_name() <> 'administrator' then
    raise exception 'BR-A4-03: Only Administrator may reject requests';
  end if;

  select status into v_status from borrowing_requests where id = p_request_id for update;

  if v_status is null then
    raise exception 'Request not found';
  end if;

  if v_status <> 'Pending' then
    raise exception 'Only Pending requests can be rejected';
  end if;

  update borrowing_requests
  set status = 'Rejected', approved_by = auth.uid(), approved_at = now(), notes = p_reason
  where id = p_request_id;

  perform log_action('REJECTED', 'Borrowing', p_request_id::text,
    'Rejected borrowing request #' || p_request_id ||
    case when p_reason is not null then ' — Reason: ' || p_reason else '' end);
end;
$$;

-- ---------------------------------------------------------------------
-- release_equipment
-- Staff or Administrator releases approved equipment to the borrower.
-- BR-A4-04: only Approved requests may be released.
-- BR-A4-05: Released equipment becomes Borrowed.
-- BR-A4-07: Rejected requests cannot be released (covered by BR-A4-04 check).
-- ---------------------------------------------------------------------
create or replace function release_equipment(p_request_id bigint)
returns void
language plpgsql
security definer
as $$
declare
  v_status request_status;
  v_equipment_id bigint;
begin
  if current_role_name() not in ('staff', 'administrator') then
    raise exception 'Only Staff or Administrator may release equipment';
  end if;

  select status, equipment_id into v_status, v_equipment_id
  from borrowing_requests where id = p_request_id for update;

  if v_status is null then
    raise exception 'Request not found';
  end if;

  if v_status <> 'Approved' then
    raise exception 'BR-A4-04 / BR-A4-07: Only an Approved request may be released';
  end if;

  update borrowing_requests
  set status = 'Released', released_at = now()
  where id = p_request_id;

  update equipment set status = 'Borrowed', updated_at = now() where id = v_equipment_id;

  perform log_action('RELEASED', 'Borrowing', p_request_id::text,
    'Released equipment for request #' || p_request_id);
end;
$$;

-- ---------------------------------------------------------------------
-- return_equipment
-- Staff or Administrator processes a return.
-- BR-A4-06: Returned equipment becomes Available unless damaged.
-- BR-A4-08: Returned transactions cannot be processed twice.
-- ---------------------------------------------------------------------
create or replace function return_equipment(p_request_id bigint, p_is_damaged boolean default false)
returns void
language plpgsql
security definer
as $$
declare
  v_status request_status;
  v_equipment_id bigint;
begin
  if current_role_name() not in ('staff', 'administrator') then
    raise exception 'Only Staff or Administrator may process returns';
  end if;

  select status, equipment_id into v_status, v_equipment_id
  from borrowing_requests where id = p_request_id for update;

  if v_status is null then
    raise exception 'Request not found';
  end if;

  if v_status = 'Returned' or v_status = 'Closed' then
    raise exception 'BR-A4-08: This transaction has already been returned/closed';
  end if;

  if v_status <> 'Released' then
    raise exception 'Only Released equipment can be returned';
  end if;

  update borrowing_requests
  set status = 'Returned', returned_at = now()
  where id = p_request_id;

  update equipment
  set status = case when p_is_damaged then 'Damaged' else 'Available' end,
      updated_at = now()
  where id = v_equipment_id;

  perform log_action('RETURNED', 'Borrowing', p_request_id::text,
    'Processed return for request #' || p_request_id ||
    case when p_is_damaged then ' (equipment marked Damaged)' else '' end);
end;
$$;

-- ---------------------------------------------------------------------
-- close_request
-- Staff/Admin closes a returned transaction, ending its lifecycle.
-- ---------------------------------------------------------------------
create or replace function close_request(p_request_id bigint)
returns void
language plpgsql
security definer
as $$
declare
  v_status request_status;
begin
  if current_role_name() not in ('staff', 'administrator') then
    raise exception 'Only Staff or Administrator may close requests';
  end if;

  select status into v_status from borrowing_requests where id = p_request_id for update;

  if v_status <> 'Returned' then
    raise exception 'Only a Returned request can be closed';
  end if;

  update borrowing_requests set status = 'Closed', closed_at = now() where id = p_request_id;

  perform log_action('CLOSED', 'Borrowing', p_request_id::text,
    'Closed request #' || p_request_id);
end;
$$;

-- ---------------------------------------------------------------------
-- mark_overdue
-- Utility function: flips any Released request whose due_date has passed
-- into Overdue. Can be called from the client on page load, or scheduled
-- via Supabase's pg_cron if the instructor wants full automation.
-- ---------------------------------------------------------------------
create or replace function mark_overdue()
returns void
language plpgsql
security definer
as $$
begin
  update borrowing_requests
  set status = 'Overdue'
  where status = 'Released'
    and due_date is not null
    and due_date < current_date;
end;
$$;

-- ---------------------------------------------------------------------
-- submit_maintenance_request — Staff/Admin only.
-- BR-A4-09 support: sets equipment to Maintenance so it can't be borrowed.
-- ---------------------------------------------------------------------
create or replace function submit_maintenance_request(p_equipment_id bigint, p_description text)
returns bigint
language plpgsql
security definer
as $$
declare
  v_new_id bigint;
begin
  if current_role_name() not in ('staff', 'administrator') then
    raise exception 'Only Staff or Administrator may submit maintenance requests';
  end if;

  insert into maintenance_requests (equipment_id, requested_by, description)
  values (p_equipment_id, auth.uid(), p_description)
  returning id into v_new_id;

  update equipment set status = 'Maintenance', updated_at = now() where id = p_equipment_id;

  perform log_action('MAINTENANCE_REQUESTED', 'Maintenance', v_new_id::text,
    'Requested maintenance for equipment ID ' || p_equipment_id);

  return v_new_id;
end;
$$;

-- ---------------------------------------------------------------------
-- resolve_maintenance — Staff/Admin closes a maintenance ticket and
-- returns equipment to Available.
-- ---------------------------------------------------------------------
create or replace function resolve_maintenance(p_maintenance_id bigint)
returns void
language plpgsql
security definer
as $$
declare
  v_equipment_id bigint;
begin
  if current_role_name() not in ('staff', 'administrator') then
    raise exception 'Only Staff or Administrator may resolve maintenance tickets';
  end if;

  select equipment_id into v_equipment_id from maintenance_requests where id = p_maintenance_id for update;

  update maintenance_requests
  set status = 'Resolved', resolved_at = now()
  where id = p_maintenance_id;

  update equipment set status = 'Available', updated_at = now() where id = v_equipment_id;

  perform log_action('MAINTENANCE_RESOLVED', 'Maintenance', p_maintenance_id::text,
    'Resolved maintenance ticket #' || p_maintenance_id);
end;
$$;

-- ---------------------------------------------------------------------
-- promote_user — Administrator only. Used for user management (role changes).
-- ---------------------------------------------------------------------
create or replace function promote_user(p_user_id uuid, p_new_role user_role)
returns void
language plpgsql
security definer
as $$
begin
  if current_role_name() <> 'administrator' then
    raise exception 'Only Administrator may manage user roles';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'An Administrator cannot change their own role';
  end if;

  update profiles set role = p_new_role where id = p_user_id;

  perform log_action('ROLE_CHANGED', 'UserManagement', p_user_id::text,
    'Changed role of user ' || p_user_id || ' to ' || p_new_role);
end;
$$;
