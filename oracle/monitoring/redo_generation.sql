-- ============================================================
-- Oracle DBA Toolkit
-- Script  : redo_generation.sql
-- Purpose : Monitor Oracle redo generation and log switches
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN NAME FORMAT A40
COLUMN VALUE FORMAT 999,999,999,999,999
COLUMN REDO_MB FORMAT 999,999,999.99
COLUMN REDO_GB FORMAT 999,999.99
COLUMN LOG_SWITCHES FORMAT 999,999
COLUMN AVG_REDO_MB FORMAT 999,999,999.99

PROMPT
PROMPT ============================================================
PROMPT                  REDO GENERATION SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    name,
    value
FROM
    v$sysstat
WHERE
    name IN
    (
        'redo size',
        'redo entries',
        'redo writes',
        'redo blocks written'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                  TOTAL REDO GENERATED
PROMPT ============================================================
PROMPT

SELECT
    ROUND(
        MAX(
            CASE
                WHEN name = 'redo size'
                THEN value
            END
        ) / 1024 / 1024,
        2
    ) AS redo_mb,

    ROUND(
        MAX(
            CASE
                WHEN name = 'redo size'
                THEN value
            END
        ) / 1024 / 1024 / 1024,
        2
    ) AS redo_gb
FROM
    v$sysstat;

PROMPT
PROMPT ============================================================
PROMPT              REDO GENERATION - LAST 24 HOURS
PROMPT ============================================================
PROMPT

SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:00') AS hour,
    COUNT(*) AS log_switches,
    ROUND(
        SUM(bytes) / 1024 / 1024,
        2
    ) AS redo_mb
FROM
    v$log_history l
JOIN
    v$archived_log a
ON
    a.thread# = l.thread#
    AND a.sequence# = l.sequence#
WHERE
    l.first_time >= SYSDATE - 1
    AND a.name IS NOT NULL
GROUP BY
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:00')
ORDER BY
    hour DESC;

PROMPT
PROMPT ============================================================
PROMPT              REDO GENERATION - LAST 7 DAYS
PROMPT ============================================================
PROMPT

SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD') AS day,
    COUNT(*) AS log_switches,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS redo_gb
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
PROMPT                 REDO BY THREAD
PROMPT ============================================================
PROMPT

SELECT
    thread#,
    COUNT(*) AS log_switches,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS redo_gb
FROM
    v$archived_log
WHERE
    first_time >= SYSDATE - 1
    AND name IS NOT NULL
    AND archived = 'YES'
GROUP BY
    thread#
ORDER BY
    thread#;

PROMPT
PROMPT ============================================================
PROMPT                 CURRENT REDO LOG STATUS
PROMPT ============================================================
PROMPT

COLUMN GROUP# FORMAT 999
COLUMN THREAD# FORMAT 999
COLUMN SEQUENCE# FORMAT 999,999,999
COLUMN SIZE_MB FORMAT 999,999
COLUMN STATUS FORMAT A12
COLUMN ARCHIVED FORMAT A10

SELECT
    group#,
    thread#,
    sequence#,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    members,
    archived,
    status
FROM
    v$log
ORDER BY
    thread#,
    group#;

PROMPT
PROMPT ============================================================
PROMPT                 LOG SWITCH FREQUENCY
PROMPT ============================================================
PROMPT

SELECT
    thread#,
    COUNT(*) AS log_switches,
    ROUND(
        COUNT(*) / 24,
        2
    ) AS avg_switches_per_hour
FROM
    v$log_history
WHERE
    first_time >= SYSDATE - 1
GROUP BY
    thread#
ORDER BY
    thread#;

PROMPT
PROMPT ============================================================
PROMPT                 REDO LOG MEMBERS
PROMPT ============================================================
PROMPT

COLUMN MEMBER FORMAT A90

SELECT
    group#,
    type,
    member,
    status
FROM
    v$logfile
ORDER BY
    group#,
    member;

PROMPT
PROMPT ============================================================
PROMPT              REDO GENERATION MONITORING COMPLETE
PROMPT ============================================================

