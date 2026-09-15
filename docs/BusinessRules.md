# Business Rules — Implementation Mapping

| ID | Rule | Where Enforced |
|---|---|---|
| BR-A4-01 | Only available equipment may be requested. | `submit_borrowing_request()` checks `equipment.status = 'Available'` before inserting the request; raises an exception otherwise. |
| BR-A4-02 | Staff/Admin cannot approve their own request. | `approve_request()` compares `borrowing_requests.requester_id` to `auth.uid()` and blocks the action; the Approvals UI also visually disables the button for the admin's own requests. |
| BR-A4-03 | Only Administrator may approve or reject requests. | `approve_request()` and `reject_request()` check `current_role_name() = 'administrator'`. The Approvals page itself is also role-gated via `requireRole(["administrator"])`. |
| BR-A4-04 | Only Approved requests may be released. | `release_equipment()` checks `status = 'Approved'` before transitioning to `Released`. |
| BR-A4-05 | Released equipment becomes Borrowed. | `release_equipment()` updates `equipment.status = 'Borrowed'` in the same transaction as the status change. |
| BR-A4-06 | Returned equipment becomes Available unless damaged. | `return_equipment(p_is_damaged)` sets `equipment.status` to `'Damaged'` when flagged, otherwise `'Available'`. |
| BR-A4-07 | Rejected requests cannot be released. | `release_equipment()` only accepts requests currently in `Approved` status, so a `Rejected` request is structurally excluded. |
| BR-A4-08 | Returned transactions cannot be processed twice. | `return_equipment()` explicitly raises an exception if the request's status is already `Returned` or `Closed`. |
| BR-A4-09 | Equipment under Maintenance cannot be borrowed. | `submit_borrowing_request()` raises an exception if `equipment.status = 'Maintenance'`; the Equipment page also hides the "Request" button for such items. |
| BR-A4-10 | Sensitive operations must be logged. | Every state-changing RPC function (`submit_borrowing_request`, `approve_request`, `reject_request`, `release_equipment`, `return_equipment`, `close_request`, maintenance functions, `promote_user`) calls `log_action()` to insert into `audit_logs` in the **same transaction**, so a status change can never occur without a corresponding log entry. |

## Design note: why business rules live in SQL functions, not just the UI

Client-side JavaScript checks (disabling a button, hiding a link) only stop an
*honest* user clicking through the interface. They do **not** stop someone
from calling the Supabase REST/RPC API directly with valid credentials. To
satisfy "Verify that authorization is enforced at both interface and database
levels" (Objective 5), every rule above is duplicated:

- **UI layer**: buttons/pages are hidden or disabled for disallowed actions.
- **Database layer**: `SECURITY DEFINER` functions and RLS policies reject
  the operation regardless of how the request was made.
