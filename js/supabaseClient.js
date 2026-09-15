// =====================================================================
// supabaseClient.js
// Fill in YOUR Supabase project credentials below (Project Settings > API).
// The "anon" public key is safe to expose in client-side code — access
// control is enforced by Row Level Security + the SECURITY DEFINER
// functions on the database side, not by hiding this key.
// =====================================================================

const SUPABASE_URL = "https://oeogorjmjxpscgpdjhdr.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lb2dvcmptanhwc2NncGRqaGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0MjYxNTcsImV4cCI6MjEwNTAwMjE1N30.G-B26LrWuctlOrC0YqvQ_-8L4QyPNYB4MRzVR9TA0O8";

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
