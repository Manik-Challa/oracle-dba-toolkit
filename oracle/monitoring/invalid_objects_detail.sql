-- ============================================================
-- Oracle Invalid Objects - Detailed Monitoring
-- File   : invalid_objects_detail.sql
-- Purpose: Detailed analysis of invalid database objects
-- Author : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN owner              FORMAT A25
COLUMN object_name        FORMAT A45
COLUMN object_type        FORMAT A25
COLUMN status             FORMAT A12
COLUMN created            FORMAT A20
COLUMN last_ddl_time      FORMAT A20
COLUMN referenced_owner   FORMAT A25
COLUMN referenced_name    FORMAT A45
COLUMN referenced_type    FORMAT A25
COLUMN object_count       FORMAT 999,999
COLUMN invalid_count      FORMAT 999,999

PROMPT
PROMPT ============================================================
PROMPT ORACLE INVALID OBJECTS - DETAILED MONITORING
PROMPT ============================================================
PROMPT

-- ============================================================
-- 1. DATABASE INFORMATION
-- ============================================================

PROMPT ============================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================

SELECT
    name,
    db_unique_name,
    open_mode,
    database_role
FROM v$database;

SELECT
    instance_name,
    host_name,
    status,
    version,
    startup_time
FROM v$instance;

-- ============================================================
-- 2. ALL INVALID OBJECTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. ALL INVALID OBJECTS
PROMPT ============================================================

SELECT
    owner,
    object_name,
    object_type,
    status,
    created,
    last_ddl_time
FROM dba_objects
WHERE status = 'INVALID'
ORDER BY owner, object_type, object_name;

-- ============================================================
-- 3. INVALID OBJECT COUNT BY OWNER
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. INVALID OBJECT COUNT BY OWNER
PROMPT ============================================================

SELECT
    owner,
    COUNT(*) AS invalid_count
FROM dba_objects
WHERE status = 'INVALID'
GROUP BY owner
ORDER BY invalid_count DESC, owner;

-- ============================================================
-- 4. INVALID OBJECT COUNT BY OBJECT TYPE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. INVALID OBJECT COUNT BY OBJECT TYPE
PROMPT ============================================================

SELECT
    object_type,
    COUNT(*) AS invalid_count
FROM dba_objects
WHERE status = 'INVALID'
GROUP BY object_type
ORDER BY invalid_count DESC, object_type;

-- ============================================================
-- 5. OWNER + OBJECT TYPE SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. INVALID OBJECTS BY OWNER AND TYPE
PROMPT ============================================================

SELECT
    owner,
    object_type,
    COUNT(*) AS invalid_count
FROM dba_objects
WHERE status = 'INVALID'
GROUP BY owner, object_type
ORDER BY invalid_count DESC, owner, object_type;

-- ============================================================
-- 6. INVALID PL/SQL OBJECTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. INVALID PL/SQL OBJECTS
PROMPT ============================================================

SELECT
    owner,
    object_name,
    object_type,
    status,
    created,
    last_ddl_time
FROM dba_objects
WHERE status = 'INVALID'
  AND object_type IN
      (
        'PROCEDURE',
        'FUNCTION',
        'PACKAGE',
        'PACKAGE BODY',
        'TRIGGER',
        'TYPE',
        'TYPE BODY'
      )
ORDER BY owner, object_type, object_name;

-- ============================================================
-- 7. INVALID VIEWS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. INVALID VIEWS
PROMPT ============================================================

SELECT
    owner,
    object_name,
    status,
    created,
    last_ddl_time
FROM dba_objects
WHERE status = 'INVALID'
  AND object_type = 'VIEW'
ORDER BY owner, object_name;

-- ============================================================
-- 8. INVALID MATERIALIZED VIEWS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. INVALID MATERIALIZED VIEWS
PROMPT ============================================================

SELECT
    owner,
    object_name,
    status,
    created,
    last_ddl_time
FROM dba_objects
WHERE status = 'INVALID'
  AND object_type = 'MATERIALIZED VIEW'
ORDER BY owner, object_name;

-- ============================================================
-- 9. INVALID OBJECTS RECENTLY MODIFIED
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. INVALID OBJECTS WITH RECENT DDL
PROMPT ============================================================

SELECT
    owner,
    object_name,
    object_type,
    status,
    last_ddl_time
FROM dba_objects
WHERE status = 'INVALID'
  AND last_ddl_time >= SYSDATE - 7
ORDER BY last_ddl_time DESC;

-- ============================================================
-- 10. INVALID OBJECTS CREATED RECENTLY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. INVALID OBJECTS CREATED IN LAST 7 DAYS
PROMPT ============================================================

SELECT
    owner,
    object_name,
    object_type,
    status,
    created,
    last_ddl_time
FROM dba_objects
WHERE status = 'INVALID'
  AND created >= SYSDATE - 7
ORDER BY created DESC;

-- ============================================================
-- 11. INVALID OBJECTS WITH DEPENDENCIES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. INVALID OBJECTS WITH DEPENDENCIES
PROMPT ============================================================

SELECT
    d.owner,
    d.name AS object_name,
    d.type AS object_type,
    d.referenced_owner,
    d.referenced_name,
    d.referenced_type
FROM dba_dependencies d
JOIN dba_objects o
  ON o.owner = d.owner
 AND o.object_name = d.name
 AND o.object_type = d.type
WHERE o.status = 'INVALID'
ORDER BY
    d.owner,
    d.name,
    d.referenced_owner,
    d.referenced_name;

-- ============================================================
-- 12. INVALID OBJECTS WITH BROKEN DEPENDENCIES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. INVALID OBJECTS - REFERENCED OBJECT STATUS
PROMPT ============================================================

SELECT
    d.owner,
    d.name AS object_name,
    d.type AS object_type,
    d.referenced_owner,
    d.referenced_name,
    d.referenced_type,
    ro.status AS referenced_status
FROM dba_dependencies d
JOIN dba_objects o
  ON o.owner = d.owner
 AND o.object_name = d.name
 AND o.object_type = d.type
LEFT JOIN dba_objects ro
  ON ro.owner = d.referenced_owner
 AND ro.object_name = d.referenced_name
 AND ro.object_type = d.referenced_type
WHERE o.status = 'INVALID'
ORDER BY
    d.owner,
    d.name,
    ro.status;

-- ============================================================
-- 13. INVALID OBJECTS DEPENDING ON INVALID OBJECTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. INVALID OBJECTS DEPENDING ON INVALID OBJECTS
PROMPT ============================================================

SELECT
    d.owner,
    d.name AS invalid_object,
    d.type AS invalid_object_type,
    d.referenced_owner,
    d.referenced_name,
    d.referenced_type
FROM dba_dependencies d
JOIN dba_objects o
  ON o.owner = d.owner
 AND o.object_name = d.name
 AND o.object_type = d.type
JOIN dba_objects ro
  ON ro.owner = d.referenced_owner
 AND ro.object_name = d.referenced_name
 AND ro.object_type = d.referenced_type
WHERE o.status = 'INVALID'
  AND ro.status = 'INVALID'
ORDER BY
    d.owner,
    d.name;

-- ============================================================
-- 14. INVALID OBJECTS BY SCHEMA
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. SCHEMAS WITH INVALID OBJECTS
PROMPT ============================================================

SELECT
    owner,
    COUNT(*) AS invalid_count,
    MIN(last_ddl_time) AS oldest_ddl_time,
    MAX(last_ddl_time) AS latest_ddl_time
FROM dba_objects
WHERE status = 'INVALID'
GROUP BY owner
ORDER BY invalid_count DESC;

-- ============================================================
-- 15. OLDEST INVALID OBJECTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. OLDEST INVALID OBJECTS
PROMPT ============================================================

SELECT
    owner,
    object_name,
    object_type,
    status,
    created,
    last_ddl_time
FROM dba_objects
WHERE status = 'INVALID'
ORDER BY last_ddl_time ASC
FETCH FIRST 50 ROWS ONLY;

-- ============================================================
-- 16. MOST RECENTLY INVALID OBJECTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. MOST RECENTLY INVALID OBJECTS
PROMPT ============================================================

SELECT
    owner,
    object_name,
    object_type,
    status,
    created,
    last_ddl_time
FROM dba_objects
WHERE status = 'INVALID'
ORDER BY last_ddl_time DESC
FETCH FIRST 50 ROWS ONLY;

-- ============================================================
-- 17. INVALID OBJECTS WITH COMPILATION ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. COMPILATION ERRORS
PROMPT ============================================================

SELECT
    owner,
    name AS object_name,
    type AS object_type,
    line,
    position,
    attribute,
    text
FROM dba_errors
WHERE type IN
      (
        'PROCEDURE',
        'FUNCTION',
        'PACKAGE',
        'PACKAGE BODY',
        'TRIGGER',
        'TYPE',
        'TYPE BODY',
        'VIEW'
      )
ORDER BY
    owner,
    name,
    sequence;

-- ============================================================
-- 18. COMPILATION ERROR SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. COMPILATION ERROR SUMMARY
PROMPT ============================================================

SELECT
    owner,
    name AS object_name,
    type AS object_type,
    COUNT(*) AS error_count
FROM dba_errors
GROUP BY
    owner,
    name,
    type
ORDER BY error_count DESC, owner, name;

-- ============================================================
-- 19. INVALID OBJECT HEALTH SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. INVALID OBJECT HEALTH SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS invalid_objects,
    COUNT(DISTINCT owner) AS affected_schemas
FROM dba_objects
WHERE status = 'INVALID';

-- ============================================================
-- 20. QUICK HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. QUICK INVALID OBJECT HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'HEALTHY - No invalid objects found'
        WHEN COUNT(*) <= 10
            THEN 'WARNING - Invalid objects detected'
        ELSE
            'ATTENTION - Multiple invalid objects detected'
    END AS invalid_object_status,
    COUNT(*) AS invalid_object_count
FROM dba_objects
WHERE status = 'INVALID';

PROMPT
PROMPT ============================================================
PROMPT INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. Invalid objects are not automatically an incident.
PROMPT 2. Check DBA_ERRORS for compilation errors.
PROMPT 3. Check DBA_DEPENDENCIES for dependency-related invalidation.
PROMPT 4. Check LAST_DDL_TIME for recent changes.
PROMPT 5. After patching/upgrades, expect some objects to become invalid.
PROMPT 6. Recompile only after identifying the underlying cause.
PROMPT 7. Avoid blanket recompilation during peak production workload.
PROMPT
PROMPT ============================================================
PROMPT END OF INVALID OBJECT MONITORING
PROMPT ============================================================

