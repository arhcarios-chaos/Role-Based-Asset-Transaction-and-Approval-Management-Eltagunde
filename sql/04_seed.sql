-- =====================================================================
-- 04_seed.sql (optional)
-- Sample equipment so the app has data to demo/test against.
-- Run AFTER 01-03. Users/profiles are NOT seeded here because Supabase
-- Auth users must be created through the Auth API/UI (see README).
-- =====================================================================

insert into equipment (code, name, category, status) values
  ('LAP-001', 'Dell Latitude Laptop', 'Computers', 'Available'),
  ('LAP-002', 'MacBook Pro 14"',      'Computers', 'Available'),
  ('PROJ-001','Epson Projector',      'AV Equipment', 'Available'),
  ('OSC-001', 'Digital Oscilloscope','Electronics Lab', 'Available'),
  ('MULT-001','Digital Multimeter',  'Electronics Lab', 'Maintenance'),
  ('CAM-001', 'DSLR Camera',         'AV Equipment', 'Available');
