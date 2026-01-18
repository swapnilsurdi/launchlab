-- PostgreSQL Admin User Seeding Script
-- Pre-creates admin users with default password: "changeme"
-- Users should change these passwords after first login

-- ==============================================
-- IMMICH DATABASE
-- ==============================================

\c immich;

-- Create admin user for Immich
-- Password: "changeme" (bcrypt hash)
-- Note: Immich will create schema on first run, so we'll insert after tables exist
-- This is a template - actual seeding happens via init container or first login

-- ==============================================
-- PAPERLESS DATABASE
-- ==============================================

\c paperless;

-- Paperless uses Django ORM, admin created via environment variables
-- PAPERLESS_ADMIN_USER, PAPERLESS_ADMIN_PASSWORD, PAPERLESS_ADMIN_EMAIL
-- No manual SQL seeding required

-- ==============================================
-- MATRIX DATABASE
-- ==============================================

\c matrix;

-- Matrix Synapse uses complex schema created on first run
-- Admin user created via register_new_matrix_user CLI command
-- No manual SQL seeding required

-- ==============================================
-- NOTES
-- ==============================================

-- This file is executed AFTER init-multi-db.sh
-- Databases are created but schemas are not yet initialized
--
-- Admin user creation strategies:
-- - Immich: Via API call in init container (POST /api/auth/admin-sign-up)
-- - Paperless: Via environment variables (PAPERLESS_ADMIN_*)
-- - Matrix: Via CLI command (register_new_matrix_user)
--
-- All use default password "changeme" - users warned to change after setup
