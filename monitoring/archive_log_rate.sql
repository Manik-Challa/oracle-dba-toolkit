-- ============================================================
-- Oracle DBA Toolkit
-- Script  : archive_log_rate.sql
-- Purpose : Monitor archive log generation and log switches
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN HOUR FORMAT A16
COLUMN DAY FORMAT A12
COLUMN THREAD FORMAT 999
COLUMN LOG_SWITCHES FORMAT 999,999
COLUMN ARCHIVE_LOGS FORMAT 999,999
COLUMN ARCHIVE_GB FORMAT 999,999.99
COLUMN ARCHIVE_MB FORMAT 999,999,999.99
COLUMN SEQUENCE# FORMAT 999,999,999

PROMPT
PROMPT ============================================================
PROMPT              ARCHIVE LOG GENERATION - LAST 24 HOURS
PROMPT ============================================================
PROMPT

SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:00') AS hour,
    COUNT(*) AS archive_logs,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS archive_mb
FROM
    v$archived_log
WHERE
    first_time >= SYSDATE - 1
    AND name IS NOT NULL
    AND archived = 'YES'
GROUP BY
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:00')
ORDER BY
    hour DESC;

PROMPT
PROMPT ============================================================
PROMPT              ARCHIVE LOG GENERATION - LAST 7 DAYS
PROMPT ============================================================
PROMPT

SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD') AS day,
    COUNT(*) AS archive_logs,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archive_gb
FROM
    v$archived_log
WHERE
    first_time >= SYSDATE - 7
    AND name IS NOT NULL
    AND archived = 'YES'
GROUP BY
    TO_CHAR(first_time, 'YYYY-MM-DD')
ORDER BY
    day DESC;

PROMPT
PROMPT ============================================================
PROMPT                 LOG SWITCHES - LAST 24 HOURS
PROMPT ============================================================
PROMPT

SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:00') AS hour,
    thread# AS thread,
    COUNT(*) AS log_switches
FROM
    v$log_history
WHERE
    first_time >= SYSDATE - 1
GROUP BY
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:00'),
    thread#
ORDER BY
    hour DESC,
    thread;

PROMPT
PROMPT ============================================================
PROMPT                 CURRENT REDO LOG STATUS
PROMPT ============================================================
PROMPT

COLUMN GROUP# FORMAT 999
COLUMN MEMBER FORMAT A70
COLUMN STATUS FORMAT A12
COLUMN SEQUENCE# FORMAT 999,999,999

SELECT
    l.group#,
    l.thread#,
    l.sequence#,
    l.bytes / 1024 / 1024 AS size_mb,
    l.members,
    l.status
FROM
    v$log l
ORDER BY
    l.thread#,
    l.group#;

PROMPT
PROMPT ============================================================
PROMPT                 RECENT ARCHIVE LOGS
PROMPT ============================================================
PROMPT

COLUMN NAME FORMAT A80
COLUMN FIRST_TIME FORMAT A20
COLUMN NEXT_TIME FORMAT A20
COLUMN DEST_ID FORMAT 999

SELECT
    thread#,
    sequence#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI:SS') AS first_time,
    TO_CHAR(next_time, 'YYYY-MM-DD HH24:MI:SS') AS next_time,
    ROUND(blocks * block_size / 1024 / 1024, 2) AS size_mb,
    dest_id,
    name
FROM
    v$archived_log
WHERE
    first_time >= SYSDATE - 1
    AND name IS NOT NULL
    AND archived = 'YES'
ORDER BY
    first_time DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 ARCHIVE DESTINATION STATUS
PROMPT ============================================================
PROMPT

COLUMN DEST_NAME FORMAT A30
COLUMN STATUS FORMAT A12
COLUMN DESTINATION FORMAT A60
COLUMN ERROR FORMAT A50

SELECT
    dest_id,
    dest_name,
    status,
    destination,
    error
FROM
    v$archive_dest
WHERE
    status <> 'INACTIVE'
ORDER BY
    dest_id;

PROMPT
PROMPT ============================================================
PROMPT              ARCHIVE LOG MONITORING COMPLETE
PROMPT ============================================================

