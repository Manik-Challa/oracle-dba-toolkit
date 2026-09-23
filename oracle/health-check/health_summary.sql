-- ============================================================
-- Oracle DBA Toolkit
-- Script  : health_summary.sql
-- Purpose : Quick Oracle database health summary
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON
SET FEEDBACK OFF

COLUMN DATABASE_NAME FORMAT A20
COLUMN DB_ROLE FORMAT A18
COLUMN OPEN_MODE FORMAT A20
COLUMN INSTANCE_NAME FORMAT A20
COLUMN HOST_NAME FORMAT A35
COLUMN STATUS FORMAT A12

COLUMN TABLESPACE_NAME FORMAT A30
COLUMN PCT_USED FORMAT 999.99

COLUMN TEMP_TABLESPACE FORMAT A25
COLUMN TEMP_PCT_USED FORMAT 999.99

COLUMN FRA_PCT_USED FORMAT 999.99

COLUMN ACTIVE_SESSIONS FORMAT 999,999
COLUMN BLOCKED_SESSIONS FORMAT 999,999
COLUMN INVALID_OBJECTS FORMAT 999,999
COLUMN LOCKED_USERS FORMAT 999,999

PROMPT
PROMPT ============================================================
PROMPT              ORACLE DATABASE HEALTH SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    d.name AS database_name,
    d.database_role AS db_role,
    d.open_mode,
    i.instance_name,
    i.host_name,
    i.status
FROM
    v$database d
CROSS JOIN
    v$instance i;

PROMPT
PROMPT ============================================================
PROMPT                 ACTIVE SESSION SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS active_sessions
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE';

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKED SESSION SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS blocked_sessions
FROM
    v$session
WHERE
    blocking_session IS NOT NULL;

PROMPT
PROMPT ============================================================
PROMPT                 TABLESPACE USAGE
PROMPT ============================================================
PROMPT

SELECT
    df.tablespace_name,
    ROUND(
        (df.total_mb - NVL(fs.free_mb, 0))
        / df.total_mb * 100,
        2
    ) AS pct_used
FROM
    (
        SELECT
            tablespace_name,
            SUM(bytes) / 1024 / 1024 AS total_mb
        FROM
            dba_data_files
        GROUP BY
            tablespace_name
    ) df
LEFT JOIN
    (
        SELECT
            tablespace_name,
            SUM(bytes) / 1024 / 1024 AS free_mb
        FROM
            dba_free_space
        GROUP BY
            tablespace_name
    ) fs
ON
    df.tablespace_name = fs.tablespace_name
ORDER BY
    pct_used DESC;

PROMPT
PROMPT ============================================================
PROMPT                 TEMP TABLESPACE USAGE
PROMPT ============================================================
PROMPT

SELECT
    tablespace_name AS temp_tablespace,
    ROUND(
        ((tablespace_size - free_blocks)
        / tablespace_size) * 100,
        2
    ) AS temp_pct_used
FROM
    dba_temp_free_space
ORDER BY
    temp_pct_used DESC;

PROMPT
PROMPT ============================================================
PROMPT                 FRA USAGE
PROMPT ============================================================
PROMPT

SELECT
    ROUND(
        CASE
            WHEN space_limit > 0
            THEN (space_used / space_limit) * 100
            ELSE 0
        END,
        2
    ) AS fra_pct_used
FROM
    v$recovery_file_dest;

PROMPT
PROMPT ============================================================
PROMPT                 INVALID OBJECTS
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS invalid_objects
FROM
    dba_objects
WHERE
    status = 'INVALID';

PROMPT
PROMPT ============================================================
PROMPT                 LOCKED USERS
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS locked_users
FROM
    dba_users
WHERE
    account_status LIKE '%LOCKED%';

PROMPT
PROMPT ============================================================
PROMPT                 ASM DISKGROUP USAGE
PROMPT ============================================================
PROMPT

SELECT
    name,
    type,
    total_mb,
    free_mb,
    ROUND(
        (total_mb - free_mb) / total_mb * 100,
        2
    ) AS pct_used
FROM
    v$asm_diskgroup
ORDER BY
    pct_used DESC;

PROMPT
PROMPT ============================================================
PROMPT                 NON-IDLE WAIT EVENTS
PROMPT ============================================================
PROMPT

SELECT
    event,
    wait_class,
    COUNT(*) AS sessions_waiting
FROM
    v$session
WHERE
    wait_class <> 'Idle'
GROUP BY
    event,
    wait_class
ORDER BY
    sessions_waiting DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 HEALTH CHECK COMPLETE
PROMPT ============================================================
PROMPT

SET FEEDBACK ON

