-- =====================================================================
-- LAB 4 - SECTION A: Role-Based Asset Transaction and Approval Management
-- 01_schema.sql
-- Run this FIRST in the Supabase SQL Editor.
-- =====================================================================

-- ---------- ENUM TYPES ----------
create type user_role as enum ('administrator', 'staff', 'requester');

create type equipment_status as enum ('Available', 'Borrowed', 'Maintenance', 'Damaged');

create type request_status as enum (
  'Pending', 'Approved', 'Rejected', 'Released', 'Returned', 'Overdue', 'Closed'
);

create type maintenance_status as enum ('Open', 'In Progress', 'Resolved');

-- ---------- PROFILES (extends auth.users) ----------
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role user_role not null default 'requester',
  created_at timestamptz not null default now()
);

-- Automatically create a profile row whenever a new auth user signs up.
-- New users default to 'requester'. An Administrator must promote staff/admins
-- afterward (see docs/README.md "Bootstrapping the first Administrator").
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    'requester'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ---------- EQUIPMENT ----------
create table equipment (
  id bigint generated always as identity primary key,
  code text not null unique,
  name text not null,
  category text,
  status equipment_status not null default 'Available',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- BORROWING REQUESTS ----------
create table borrowing_requests (
  id bigint generated always as identity primary key,
  requester_id uuid not null references profiles(id),
  equipment_id bigint not null references equipment(id),
  purpose text not null,
  status request_status not null default 'Pending',
  requested_at timestamptz not null default now(),
  due_date date,
  approved_by uuid references profiles(id),
  approved_at timestamptz,
  released_at timestamptz,
  returned_at timestamptz,
  closed_at timestamptz,
  notes text
);

-- ---------- MAINTENANCE REQUESTS ----------
create table maintenance_requests (
  id bigint generated always as identity primary key,
  equipment_id bigint not null references equipment(id),
  requested_by uuid not null references profiles(id),
  description text not null,
  status maintenance_status not null default 'Open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

-- ---------- AUDIT LOGS (BR-A4-10: sensitive operations must be logged) ----------
create table audit_logs (
  id bigint generated always as identity primary key,
  user_id uuid references profiles(id),
  action text not null,
  module text not null,
  record_id text,
  description text,
  created_at timestamptz not null default now()
);

-- Helpful indexes
create index idx_requests_status on borrowing_requests(status);
create index idx_requests_requester on borrowing_requests(requester_id);
create index idx_audit_created on audit_logs(created_at desc);
