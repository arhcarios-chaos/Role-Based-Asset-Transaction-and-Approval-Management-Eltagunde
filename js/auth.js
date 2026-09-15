// =====================================================================
// auth.js
// Session + role helpers used by every protected page.
// Interface-level guard: requireRole() redirects/denies BEFORE any
// protected UI is rendered. Database-level enforcement (RLS + RPC
// functions) still applies even if this check were bypassed.
// =====================================================================

async function getSessionAndProfile() {
  const { data: { session } } = await supabaseClient.auth.getSession();
  if (!session) return { session: null, profile: null };

  const { data: profile, error } = await supabaseClient
    .from("profiles")
    .select("id, full_name, role")
    .eq("id", session.user.id)
    .single();

  if (error) {
    console.error("Failed to load profile", error);
    return { session, profile: null };
  }
  return { session, profile };
}

/**
 * Call at the top of every protected page.
 * allowedRoles: array like ["administrator"] or ["staff","administrator"].
 * Redirects to login.html if not authenticated.
 * Renders an access-denied message (TC-A4-01) if role isn't permitted.
 */
async function requireRole(allowedRoles) {
  const { session, profile } = await getSessionAndProfile();

  if (!session) {
    window.location.href = "login.html";
    return null;
  }

  if (!profile || !allowedRoles.includes(profile.role)) {
    document.body.innerHTML = `
      <div class="alert-denied">
        <h2>Access Denied</h2>
        <p>Your role (${profile ? profile.role : "unknown"}) does not have permission to view this page.</p>
        <a href="dashboard.html">Return to Dashboard</a>
      </div>`;
    return null;
  }

  renderNav(profile);
  return profile;
}

/** Builds the sidebar + topbar according to the logged-in role. */
function renderNav(profile) {
  const nameEl = document.getElementById("nav-user-name");
  const roleEl = document.getElementById("nav-user-role");
  if (nameEl) nameEl.textContent = profile.full_name;
  if (roleEl) roleEl.textContent = profile.role;

  const sidebar = document.getElementById("sidebar-links");
  if (!sidebar) return;

  const links = [];
  links.push(`<a href="dashboard.html">Dashboard</a>`);
  links.push(`<a href="equipment.html">Equipment</a>`);

  if (profile.role === "requester") {
    links.push(`<a href="requests.html">My Requests</a>`);
  }

  if (profile.role === "staff" || profile.role === "administrator") {
    links.push(`<a href="requests.html">Borrowing Transactions</a>`);
    links.push(`<a href="maintenance.html">Maintenance</a>`);
  }

  if (profile.role === "administrator") {
    links.push(`<a href="approvals.html">Approvals</a>`);
    links.push(`<a href="users.html">Manage Users</a>`);
    links.push(`<a href="reports.html">Reports</a>`);
    links.push(`<a href="audit-logs.html">Audit Logs</a>`);
  }

  sidebar.innerHTML = links.join("");

  // Highlight current page.
  const current = window.location.pathname.split("/").pop();
  sidebar.querySelectorAll("a").forEach(a => {
    if (a.getAttribute("href") === current) a.classList.add("active");
  });
}

async function logout() {
  await supabaseClient.auth.signOut();
  window.location.href = "login.html";
}
