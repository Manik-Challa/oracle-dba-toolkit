-- ============================================================
-- Oracle DBA Toolkit
-- Database Role Monitoring
--
-- Purpose:
--   Monitor Oracle database role and Data Guard-related status.
--
-- Key checks:
--   - Database role
--   - Open mode
--   - Protection mode
--   - Protection level
--   - Switchover status
--   - Database unique name
--   - Force logging
--   - Flashback status
--   - RAC instance status
--   - Data Guard destinations
--
-- Notes:
--   V$DATABASE provides database-level role information.
--   V$ARCHIVE_DEST_STATUS provides destination-level status.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name                  FORMAT A20
COLUMN db_unique_name        FORMAT A25
COLUMN database_role         FORMAT A20
COLUMN open_mode             FORMAT A25
COLUMN protection_mode       FORMAT A25
COLUMN protection_level      FORMAT A25
COLUMN switchover_status     FORMAT A22
COLUMN force_logging         FORMAT A15
COLUMN flashback_on          FORMAT A15
COLUMN guard_status          FORMAT A15
COLUMN instance_name         FORMAT A18
COLUMN host_name             FORMAT A35
COLUMN status                FORMAT A15
COLUMN destination           FORMAT A35
COLUMN target                FORMAT A12
COLUMN dest_status           FORMAT A15
COLUMN error                 FORMAT A60 WORD_WRAPPED

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE ROLE
PROMPT ============================================================

SELECT
    name,
    db_unique_name,
    database_role,
    open_mode,
    protection_mode,
    protection_level,
    switchover_status,
    force_logging,
    flashback_on,
    guard_status
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 2. DATABASE ROLE SUMMARY
PROMPT ============================================================

SELECT
    database_role,
    open_mode,
    protection_mode,
    protection_level,
    switchover_status
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 3. PRIMARY / STANDBY CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN database_role = 'PRIMARY'
            THEN 'PRIMARY DATABASE'
        WHEN database_role = 'PHYSICAL STANDBY'
            THEN 'PHYSICAL STANDBY'
        WHEN database_role = 'LOGICAL STANDBY'
            THEN 'LOGICAL STANDBY'
        WHEN database_role = 'SNAPSHOT STANDBY'
            THEN 'SNAPSHOT STANDBY'
        ELSE database_role
    END AS database_role,
    open_mode,
    switchover_status
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 4. PROTECTION CONFIGURATION
PROMPT ============================================================

SELECT
    name,
    protection_mode,
    protection_level,
    force_logging,
    flashback_on
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 5. SWITCHOVER STATUS
PROMPT ============================================================

SELECT
    name AS database_name,
    database_role,
    open_mode,
    switchover_status,
    protection_mode,
    protection_level
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 6. DATABASE GUARD STATUS
PROMPT ============================================================

SELECT
    name,
    database_role,
    guard_status,
    open_mode
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 7. RAC INSTANCE ROLE / STATUS
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    instance_number,
    host_name,
    status,
    startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 8. DATABASE SERVICES / INSTANCE STATUS
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    logins,
    parallel,
    thread#
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 9. DATA GUARD DESTINATION STATUS
PROMPT ============================================================

SELECT
    dest_id,
    target,
    status,
    destination,
    error
FROM v$archive_dest
WHERE target = 'STANDBY'
ORDER BY dest_id;


PROMPT
PROMPT ============================================================
PROMPT 10. ACTIVE DATA GUARD DESTINATIONS
PROMPT ============================================================

SELECT
    dest_id,
    status,
    type,
    database_mode,
    recovery_mode,
    protection_mode,
    synchronized,
    synchronization_status,
    gap_status,
    error
FROM v$archive_dest_status
WHERE status <> 'INACTIVE'
ORDER BY dest_id;


PROMPT
PROMPT ============================================================
PROMPT 11. STANDBY DESTINATION ERRORS
PROMPT ============================================================

SELECT
    dest_id,
    status,
    destination,
    error
FROM v$archive_dest
WHERE target = 'STANDBY'
  AND (
        status <> 'VALID'
        OR error IS NOT NULL
      )
ORDER BY dest_id;


PROMPT
PROMPT ============================================================
PROMPT 12. DATA GUARD DATABASE IDENTIFIERS
PROMPT ============================================================

SELECT
    dbid,
    name,
    db_unique_name,
    database_role,
    open_mode
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 13. DATABASE ROLE / OPEN MODE MATRIX
PROMPT ============================================================

SELECT
    database_role,
    open_mode,
    COUNT(*) AS database_count
FROM v$database
GROUP BY database_role, open_mode;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. Check DATABASE_ROLE to determine PRIMARY or STANDBY role.
PROMPT 2. Check OPEN_MODE to confirm whether the database is open.
PROMPT 3. Check PROTECTION_MODE and PROTECTION_LEVEL for Data Guard
PROMPT    protection configuration.
PROMPT 4. Check SWITCHOVER_STATUS before planned role transitions.
PROMPT 5. Review V$ARCHIVE_DEST for standby destination configuration.
PROMPT 6. Review V$ARCHIVE_DEST_STATUS for transport/apply-related status.
PROMPT 7. Investigate non-VALID standby destinations and destination errors.
PROMPT 8. In RAC, review GV$INSTANCE for every instance.
PROMPT 9. Unexpected role changes should be correlated with Data Guard
PROMPT    broker output, alert logs, and database events.
PROMPT 10. Database role alone does not confirm Data Guard health.
PROMPT     Check transport, apply, lag, and destination status separately.
PROMPT
PROMPT ============================================================
PROMPT END OF DATABASE ROLE MONITORING
PROMPT ============================================================

