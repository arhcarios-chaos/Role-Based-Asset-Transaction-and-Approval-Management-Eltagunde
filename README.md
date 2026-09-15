# 🧪 Lab Asset & Service Management System
### Role-Based Asset Transaction and Approval Management

A web-based system for managing laboratory equipment borrowing — from request, to approval, to release, return, and audit. Built with a static front end and a Supabase (Postgres) backend, with every business rule enforced **twice**: once in the UI, and again inside the database, so it can't be bypassed.

![Stack](https://img.shields.io/badge/frontend-HTML%2FCSS%2FJS-orange)
![Backend](https://img.shields.io/badge/backend-Supabase%20(Postgres)-3ECF8E)
![Deploy](https://img.shields.io/badge/deploy-GitHub%20Pages-blue)
![No build step](https://img.shields.io/badge/build%20step-none-lightgrey)

---

## Overview

This system extends a Laboratory Asset and Service Management System with **three enforced user roles** and a full **borrowing approval workflow**:

```
Pending → Approved / Rejected → Released → Returned → Closed
                                                 ↳ Overdue
```

Every sensitive action (approve, reject, release, return, role change, etc.) is written to a permanent **audit log** in the same database transaction as the change itself, so a status update can never happen without a matching log entry.

## ✨ Features

- **Three roles, fully separated:** Administrator, Laboratory Staff, and Requester/Viewer, each with a distinct set of permitted actions.
- **Full borrowing lifecycle:** request → approval/rejection → release → return (with damage flag) → close, with an `Overdue` state built in.
- **Defense in depth:** business rules are enforced at three layers — the UI, Postgres Row Level Security policies, and `SECURITY DEFINER` RPC functions — so the rules hold even if someone calls the API directly instead of clicking through the app.
- **Complete audit trail:** every state-changing action is logged with the acting user, action, module, record ID, and timestamp.
- **Equipment & maintenance tracking:** equipment status (`Available`, `Borrowed`, `Maintenance`, `Damaged`) and a maintenance ticket workflow.
- **Admin reporting:** equipment/request breakdowns and an overdue-items view.
- **Zero build step:** plain HTML/CSS/JS — deploys straight to GitHub Pages.

## 🔐 Role Permissions

| Function | Administrator | Laboratory Staff | Requester / Viewer |
|---|:---:|:---:|:---:|
| View available equipment | ✅ | ✅ | ✅ |
| Add / update equipment records | ✅ | ✅ | ❌ |
| Delete equipment records | ✅ | ❌ | ❌ |
| Submit a borrowing request | ✅ | ✅ | ✅ |
| View all borrowing transactions | ✅ | ✅ | ❌ |
| Approve / reject a request | ✅ (not own) | ❌ | ❌ |
| Release / return equipment | ✅ | ✅ | ❌ |
| Submit / resolve maintenance | ✅ | ✅ | ❌ |
| Manage users / assign roles | ✅ | ❌ | ❌ |
| View reports & audit logs | ✅ | ❌ | ❌ |

Full detail in [`docs/RolePermissionMatrix.md`](docs/RolePermissionMatrix.md).

## 🛠️ Tech Stack

- **Frontend:** Static HTML/CSS/JavaScript (no framework, no build step)
- **Backend:** [Supabase](https://supabase.com) — Postgres database, Auth, and Row Level Security
- **Hosting:** GitHub Pages

## 📁 Project Structure

```
├── index.html            # redirects to login or dashboard
├── login.html            # login + requester sign-up
├── dashboard.html        # role-adaptive landing page
├── equipment.html        # view/manage equipment, submit requests/maintenance
├── requests.html         # borrowing transactions (requester: own; staff/admin: all)
├── approvals.html        # Administrator-only approval queue
├── maintenance.html      # Staff/Admin maintenance tickets
├── audit-logs.html       # Administrator-only audit trail
├── users.html            # Administrator-only: view users, change roles
├── reports.html          # Administrator-only: equipment/request breakdowns, overdue list
├── css/style.css
├── js/
│   ├── supabaseClient.js # your Supabase URL + anon key go here
│   └── auth.js           # session check, role guard, nav rendering
├── sql/
│   ├── 01_schema.sql
│   ├── 02_policies.sql
│   ├── 03_functions.sql
│   └── 04_seed.sql
└── docs/
    ├── ERD.mermaid
    ├── UseCaseDiagram.mermaid
    ├── WorkflowDiagram.mermaid
    ├── RolePermissionMatrix.md
    ├── BusinessRules.md
    └── TestPlan.md
```

## 🚀 Getting Started

### 1. Set up Supabase (backend)

1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run, **in order**:
   `sql/01_schema.sql` → `sql/02_policies.sql` → `sql/03_functions.sql` → `sql/04_seed.sql` (optional demo data).
3. Go to **Authentication → Providers** and make sure **Email** sign-in is enabled. For a classroom/demo deployment you can disable "Confirm email" under **Authentication → Settings** so accounts work immediately after sign-up.
4. Go to **Project Settings → API** and copy your **Project URL** and **anon public key**.

<details>
<summary><strong>Bootstrapping the first Administrator</strong></summary>

New sign-ups always default to `requester` (see the `handle_new_user()` trigger). To create your first Administrator/Staff accounts:

1. Sign up normally through `login.html` (creates a `requester` profile).
2. In the Supabase **SQL Editor**, run:
   ```sql
   update profiles set role = 'administrator' where id =
     (select id from auth.users where email = 'your-admin-email@example.com');
   ```
3. Repeat with `role = 'staff'` for staff accounts.
4. From then on, an Administrator can promote/demote any other user (not themselves — blocked at both the UI and database level) from **Manage Users** in the app. That page calls the `promote_user()` RPC, which re-checks the caller's role and writes an audit log entry (`ROLE_CHANGED`) on every change.

</details>

### 2. Configure the front end

Edit `js/supabaseClient.js`:

```js
const SUPABASE_URL = "https://YOUR-PROJECT-REF.supabase.co";
const SUPABASE_ANON_KEY = "YOUR-ANON-PUBLIC-KEY";
```

> The anon key is meant to be public — real access control comes from Row Level Security and the `SECURITY DEFINER` functions in `sql/`, not from hiding this key.

### 3. Run locally (optional)

```bash
npx serve .
# or
python3 -m http.server 8080
```

Then open `http://localhost:8080/login.html`.

### 4. Deploy to GitHub Pages

```bash
git init
git add .
git commit -m "Lab 4: role-based asset transaction and approval management"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

Then in the repo: **Settings → Pages → Source: `main` branch, `/ (root)`**.
Live site: `https://<your-username>.github.io/<your-repo>/login.html`.

## 🏗️ Architecture — Defense in Depth

Business rules are never enforced in only one place:

1. **Interface level** — `js/auth.js`'s `requireRole()` checks the caller's role before rendering a page's protected content; the sidebar only prints links the role is allowed to use.
2. **Database level** — Postgres Row Level Security policies (`sql/02_policies.sql`) restrict which rows each role can read/write directly.
3. **Business-logic level** — all state-changing actions go through `SECURITY DEFINER` RPC functions (`sql/03_functions.sql`) that re-check the caller's role and the record's current status before making any change, and log the action in the same transaction.

This means even a user who bypasses the front end and calls the Supabase API directly cannot violate a business rule. Full rule-by-rule mapping in [`docs/BusinessRules.md`](docs/BusinessRules.md).

## 🧭 Diagrams

Entity-relationship, use-case, and workflow diagrams are in `docs/*.mermaid`. View them with the [Mermaid Live Editor](https://mermaid.live), GitHub's built-in Markdown rendering, or VS Code's Markdown preview (with the Mermaid extension).

## ✅ Testing

Follow [`docs/TestPlan.md`](docs/TestPlan.md) (test cases TC-A4-01 through TC-A4-10). Log in as each role in a separate browser profile/incognito window to test role boundaries side-by-side, and check `audit-logs.html` after each approve/reject/release/return to confirm the audit trail.

## 📄 License

This project was built as a school lab exercise. Add a license here if you plan to reuse or distribute it.
