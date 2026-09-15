# Functional Test Plan &amp; Results

Fill in **Actual Result**, **Status**, and add a screenshot filename for each
test case as you run it against your deployed system, then include this file
(with results) in your submission.

| Test ID | Scenario | Steps | Expected Result | Actual Result | Status (Pass/Fail) |
|---|---|---|---|---|---|
| TC-A4-01 | Viewer attempts to open Admin page | Log in as a `requester`; navigate directly to `approvals.html` or `audit-logs.html` | Access denied message shown; no data exposed | | |
| TC-A4-02 | Staff submits request | Log in as `staff`; go to Equipment, click "Request" on an Available item, submit | Request saved with status `Pending`, visible under Borrowing Transactions | | |
| TC-A4-03 | Administrator approves request | Log in as `administrator`; go to Approvals; approve a request submitted by another user | Status becomes `Approved`; new row appears in Audit Logs with action `APPROVED` | | |
| TC-A4-04 | Administrator rejects request | Log in as `administrator`; go to Approvals; reject a pending request | Status becomes `Rejected`; audit log entry `REJECTED` created | | |
| TC-A4-05 | Attempt to release rejected request | As staff/admin, try to call release on a `Rejected` request (e.g. via API/RPC directly) | Operation blocked with error referencing BR-A4-04/07 | | |
| TC-A4-06 | Release approved equipment | As staff/admin, go to Borrowing Transactions, click "Release" on an `Approved` request | Request becomes `Released`; equipment status becomes `Borrowed` | | |
| TC-A4-07 | Return released equipment | As staff/admin, click "Return (OK)" on a `Released` request | Request becomes `Returned`; equipment becomes `Available` (or `Damaged` if flagged) | | |
| TC-A4-08 | Check audit log after approval | Log in as `administrator`; open Audit Logs after performing TC-A4-03 | Approval entry visible with correct user, action, module, record ID, timestamp | | |
| TC-A4-09 | Staff attempts restricted delete | Log in as `staff`; attempt to delete an equipment record (e.g. via API/RPC directly, since UI has no delete button for staff) | Operation blocked by RLS (`equipment_delete_admin` policy) | | |
| TC-A4-10 | Logout and open protected page | Log out; attempt to navigate directly to `dashboard.html` | Redirected to `login.html` | | |

## How to attempt "direct API" tests (TC-A4-05, TC-A4-09)

These verify **database-level** enforcement, not just UI hiding. From the
browser console while logged in as the relevant role:

```js
// TC-A4-05: try releasing a Rejected request as staff (replace 99 with a real Rejected request id)
await supabaseClient.rpc("release_equipment", { p_request_id: 99 });
// Expect: error object with a message referencing BR-A4-04/07

// TC-A4-09: try deleting equipment as staff (replace 1 with a real equipment id)
await supabaseClient.from("equipment").delete().eq("id", 1);
// Expect: no rows deleted / RLS policy violation
```

## Suggested screenshot list for submission

1. `TC-A4-01_access_denied.png`
2. `TC-A4-02_pending_request.png`
3. `TC-A4-03_approved_and_audit.png`
4. `TC-A4-06_released_borrowed.png`
5. `TC-A4-07_returned_available.png`
6. `TC-A4-08_audit_log_list.png`
7. `TC-A4-10_redirect_login.png`
