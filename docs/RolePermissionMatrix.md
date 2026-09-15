# Role-Permission Matrix

| Function | Administrator | Laboratory Staff | Requester / Viewer |
|---|:---:|:---:|:---:|
| Log in / Log out | ✅ | ✅ | ✅ |
| View available equipment | ✅ | ✅ | ✅ |
| Add / update equipment records | ✅ | ✅ | ❌ |
| Delete equipment records | ✅ | ❌ | ❌ |
| Submit a borrowing request | ✅ | ✅ | ✅ |
| View **own** request status/history | ✅ | ✅ | ✅ |
| View **all** borrowing transactions | ✅ | ✅ | ❌ |
| Approve a borrowing request | ✅ (not own) | ❌ | ❌ |
| Reject a borrowing request | ✅ | ❌ | ❌ |
| Release approved equipment | ✅ | ✅ | ❌ |
| Process equipment return | ✅ | ✅ | ❌ |
| Submit a maintenance request | ✅ | ✅ | ❌ |
| Resolve a maintenance request | ✅ | ✅ | ❌ |
| Manage users / assign roles | ✅ | ❌ | ❌ |
| View system reports | ✅ | ❌ | ❌ |
| View audit logs | ✅ | ❌ | ❌ |

**Page mapping (confirms every permitted function in the lab brief has a UI)**

| Role | Permitted Function (from lab brief) | Page |
|---|---|---|
| Administrator | Manage users | `users.html` |
| Administrator | Manage equipment | `equipment.html` (add / edit / delete) |
| Administrator | Approve/reject requests | `approvals.html` |
| Administrator | Manage maintenance | `maintenance.html` |
| Administrator | View reports | `reports.html` |
| Administrator | View audit logs | `audit-logs.html` |
| Laboratory Staff | View equipment | `equipment.html` |
| Laboratory Staff | Create borrowing transactions | `equipment.html` ("Request" button) |
| Laboratory Staff | Process returns | `requests.html` (Release / Return buttons) |
| Laboratory Staff | Submit maintenance requests | `equipment.html` ("Send to Maintenance") |
| Laboratory Staff | Update permitted records | `equipment.html` (inline "Edit" — code/name/category/status) |
| Requester/Viewer | View available equipment | `equipment.html` |
| Requester/Viewer | Submit borrowing requests | `equipment.html` ("Request" button) |
| Requester/Viewer | View own request status/history | `requests.html` |

**Enforcement layers**

1. **Interface level** — `js/auth.js` → `requireRole()` checks the caller's role
   before rendering a page's protected content, and the sidebar (`renderNav()`)
   only prints links the role is allowed to use.
2. **Database level** — Postgres **Row Level Security** policies
   (`sql/02_policies.sql`) restrict which rows each role can `SELECT`/`INSERT`/
   `UPDATE`/`DELETE` directly.
3. **Business-logic level** — all state-changing actions (approve, reject,
   release, return, close, promote user) go through **SECURITY DEFINER RPC
   functions** (`sql/03_functions.sql`) that re-check the caller's role and the
   record's current status before making any change, and write an audit log
   entry in the same transaction. This means even a user who bypasses the
   front end (e.g. calling the API directly) cannot violate a business rule.
