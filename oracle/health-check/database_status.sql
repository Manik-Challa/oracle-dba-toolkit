
-- ============================================================
-- Oracle DBA Toolkit
-- Script  : database_status.sql
-- Purpose : Quick database and instance health check
-- ============================================================

SET LINESIZE 200
SET PAGESIZE 100

COLUMN INSTANCE_NAME FORMAT A15
COLUMN HOST_NAME FORMAT A30
COLUMN STATUS FORMAT A10
COLUMN DATABASE_ROLE FORMAT A20
COLUMN OPEN_MODE FORMAT A20

SELECT
    i.instance_name,
    i.host_name,
    i.status,
    d.database_role,
    d.open_mode
FROM v$instance i
CROSS JOIN v$database d;

