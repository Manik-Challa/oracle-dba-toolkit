-- ================================================================
-- Oracle DBA Toolkit
-- Script : standby_redo_status.sql
-- Purpose: Monitor Oracle Data Guard Standby Redo Log Status
-- Usage  : Run as SYS or a user with access to required V$ views
-- Scope  : Read-only monitoring
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name                 FORMAT A20
COLUMN db_unique_name       FORMAT A25
COLUMN database_role        FORMAT A22
COLUMN open_mode            FORMAT A25
COLUMN instance_name       FORMAT A20
COLUMN host_name            FORMAT A35
COLUMN status               FORMAT A20
COLUMN archived             FORMAT A10
COLUMN member               FORMAT A80
COLUMN type                 FORMAT A15
COLUMN thread#              FORMAT 999
COLUMN group#               FORMAT 999
COLUMN sequence#            FORMAT 999999999
COLUMN bytes_gb             FORMAT 9999990.99
COLUMN online_groups        FORMAT 999999
COLUMN standby_groups       FORMAT 999999
COLUMN online_gb            FORMAT 9999990.99
COLUMN standby_gb           FORMAT 9999990.99
COLUMN size_difference_gb   FORMAT 9999990.99
COLUMN health_status        FORMAT A50

PROMPT
PROMPT ================================================================
PROMPT ORACLE DATA GUARD STANDBY REDO LOG STATUS MONITOR
PROMPT ================================================================

PROMPT
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ----------------------------------------------------------------

SELECT
    d.name,
    d.db_unique_name,
    d.database_role,
    d.open_mode,
    d.protection_mode,
    d.protection_level,
    i.instance_name,
    i.host_name,
    i.status AS instance_status
FROM v$database d
CROSS JOIN v$instance i;

PROMPT
PROMPT 2. STANDBY REDO LOG GROUP STATUS
PROMPT ----------------------------------------------------------------

SELECT
    group#,
    thread#,
    sequence#,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS bytes_gb,
    status,
    archived
FROM v$standby_log
ORDER BY thread#, group#;

PROMPT
PROMPT 3. STANDBY REDO LOG STATUS SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    status,
    COUNT(*) AS standby_groups,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM v$standby_log
GROUP BY status
ORDER BY status;

PROMPT
PROMPT 4. STANDBY REDO LOGS BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS standby_groups,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS standby_gb,
    SUM(
        CASE
            WHEN status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_groups,
    SUM(
        CASE
            WHEN status = 'UNASSIGNED' THEN 1
            ELSE 0
        END
    ) AS unassigned_groups
FROM v$standby_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 5. ACTIVE STANDBY REDO LOGS
PROMPT ----------------------------------------------------------------

SELECT
    group#,
    thread#,
    sequence#,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS bytes_gb,
    status,
    archived
FROM v$standby_log
WHERE status IN (
    'ACTIVE',
    'CLEARING_CURRENT'
)
ORDER BY thread#, group#;

PROMPT
PROMPT 6. UNASSIGNED STANDBY REDO LOGS
PROMPT ----------------------------------------------------------------

SELECT
    group#,
    thread#,
    sequence#,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS bytes_gb,
    status,
    archived
FROM v$standby_log
WHERE status = 'UNASSIGNED'
ORDER BY thread#, group#;

PROMPT
PROMPT 7. STANDBY REDO LOG MEMBERS
PROMPT ----------------------------------------------------------------

SELECT
    l.group#,
    l.thread#,
    l.sequence#,
    l.status,
    lf.type,
    lf.member
FROM v$standby_log l
JOIN v$logfile lf
    ON l.group# = lf.group#
ORDER BY l.thread#, l.group#, lf.member;

PROMPT
PROMPT 8. STANDBY REDO GROUP MEMBER COUNT
PROMPT ----------------------------------------------------------------

SELECT
    l.group#,
    l.thread#,
    COUNT(lf.member) AS member_count,
    ROUND(
        l.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    l.status
FROM v$standby_log l
LEFT JOIN v$logfile lf
    ON l.group# = lf.group#
GROUP BY
    l.group#,
    l.thread#,
    l.bytes,
    l.status
ORDER BY l.thread#, l.group#;

PROMPT
PROMPT 9. STANDBY REDO GROUPS WITH SINGLE MEMBER
PROMPT ----------------------------------------------------------------

SELECT
    l.group#,
    l.thread#,
    l.status,
    ROUND(
        l.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    COUNT(lf.member) AS member_count
FROM v$standby_log l
LEFT JOIN v$logfile lf
    ON l.group# = lf.group#
GROUP BY
    l.group#,
    l.thread#,
    l.status,
    l.bytes
HAVING COUNT(lf.member) = 1
ORDER BY l.thread#, l.group#;

PROMPT
PROMPT 10. STANDBY REDO GROUPS WITH NO MEMBER
PROMPT ----------------------------------------------------------------

SELECT
    l.group#,
    l.thread#,
    l.status,
    ROUND(
        l.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    COUNT(lf.member) AS member_count
FROM v$standby_log l
LEFT JOIN v$logfile lf
    ON l.group# = lf.group#
GROUP BY
    l.group#,
    l.thread#,
    l.status,
    l.bytes
HAVING COUNT(lf.member) = 0
ORDER BY l.thread#, l.group#;

PROMPT
PROMPT 11. ONLINE REDO LOG CONFIGURATION
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS online_groups,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS online_gb
FROM v$log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 12. STANDBY REDO LOG CONFIGURATION
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS standby_groups,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS standby_gb
FROM v$standby_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 13. ONLINE VS STANDBY REDO GROUP COUNTS
PROMPT ----------------------------------------------------------------

SELECT
    o.thread#,
    o.online_groups,
    NVL(s.standby_groups, 0) AS standby_groups,
    NVL(s.standby_groups, 0) - o.online_groups
        AS standby_minus_online
FROM
(
    SELECT
        thread#,
        COUNT(*) AS online_groups
    FROM v$log
    GROUP BY thread#
) o
LEFT JOIN
(
    SELECT
        thread#,
        COUNT(*) AS standby_groups
    FROM v$standby_log
    GROUP BY thread#
) s
    ON o.thread# = s.thread#
ORDER BY o.thread#;

PROMPT
PROMPT 14. ONLINE VS STANDBY REDO SIZE
PROMPT ----------------------------------------------------------------

SELECT
    o.thread#,
    ROUND(o.online_gb, 2) AS online_gb,
    ROUND(NVL(s.standby_gb, 0), 2) AS standby_gb,
    ROUND(
        NVL(s.standby_gb, 0) - o.online_gb,
        2
    ) AS size_difference_gb
FROM
(
    SELECT
        thread#,
        SUM(bytes) / 1024 / 1024 / 1024 AS online_gb
    FROM v$log
    GROUP BY thread#
) o
LEFT JOIN
(
    SELECT
        thread#,
        SUM(bytes) / 1024 / 1024 / 1024 AS standby_gb
    FROM v$standby_log
    GROUP BY thread#
) s
    ON o.thread# = s.thread#
ORDER BY o.thread#;

PROMPT
PROMPT 15. STANDBY REDO LOGS SMALLER THAN ONLINE REDO
PROMPT ----------------------------------------------------------------

SELECT
    s.group#,
    s.thread#,
    ROUND(s.bytes / 1024 / 1024 / 1024, 2) AS standby_gb,
    ROUND(o.bytes / 1024 / 1024 / 1024, 2) AS online_gb,
    ROUND(
        (o.bytes - s.bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_difference_gb
FROM v$standby_log s
JOIN v$log o
    ON s.thread# = o.thread#
WHERE s.bytes < o.bytes
ORDER BY s.thread#, s.group#;

PROMPT
PROMPT 16. STANDBY REDO LOG SIZE CONSISTENCY
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(DISTINCT bytes) AS distinct_sizes,
    ROUND(
        MIN(bytes) / 1024 / 1024 / 1024,
        2
    ) AS minimum_size_gb,
    ROUND(
        MAX(bytes) / 1024 / 1024 / 1024,
        2
    ) AS maximum_size_gb
FROM v$standby_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 17. THREADS WITH MULTIPLE STANDBY REDO SIZES
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(DISTINCT bytes) AS distinct_sizes
FROM v$standby_log
GROUP BY thread#
HAVING COUNT(DISTINCT bytes) > 1
ORDER BY thread#;

PROMPT
PROMPT 18. STANDBY REDO THREAD COVERAGE
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS standby_groups,
    COUNT(DISTINCT bytes) AS distinct_sizes,
    SUM(
        CASE
            WHEN status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_groups,
    SUM(
        CASE
            WHEN status = 'UNASSIGNED' THEN 1
            ELSE 0
        END
    ) AS unassigned_groups
FROM v$standby_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 19. ONLINE REDO THREADS WITHOUT STANDBY REDO LOGS
PROMPT ----------------------------------------------------------------

SELECT
    o.thread#
FROM
(
    SELECT DISTINCT thread#
    FROM v$log
) o
WHERE NOT EXISTS
(
    SELECT 1
    FROM v$standby_log s
    WHERE s.thread# = o.thread#
)
ORDER BY o.thread#;

PROMPT
PROMPT 20. STANDBY REDO LOG CURRENT ACTIVITY
PROMPT ----------------------------------------------------------------

SELECT
    group#,
    thread#,
    sequence#,
    status,
    archived,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    first_change#,
    next_change#
FROM v$standby_log
WHERE status <> 'UNASSIGNED'
ORDER BY thread#, sequence# DESC;

PROMPT
PROMPT 21. STANDBY REDO LOG STATUS COUNTS
PROMPT ----------------------------------------------------------------

SELECT
    status,
    COUNT(*) AS group_count
FROM v$standby_log
GROUP BY status
ORDER BY status;

PROMPT
PROMPT 22. STANDBY REDO LOGS PER THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS standby_redo_groups,
    MIN(group#) AS first_group,
    MAX(group#) AS last_group
FROM v$standby_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 23. STANDBY REDO LOG MEMBERS BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    l.thread#,
    COUNT(DISTINCT l.group#) AS standby_groups,
    COUNT(lf.member) AS total_members
FROM v$standby_log l
LEFT JOIN v$logfile lf
    ON l.group# = lf.group#
GROUP BY l.thread#
ORDER BY l.thread#;

PROMPT
PROMPT 24. DATA GUARD MRP STATUS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    client_process,
    thread#,
    sequence#,
    block#,
    blocks,
    delay_mins
FROM v$managed_standby
WHERE process LIKE 'MRP%'
ORDER BY process;

PROMPT
PROMPT 25. RFS STATUS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    client_process,
    thread#,
    sequence#,
    block#,
    blocks
FROM v$managed_standby
WHERE process LIKE 'RFS%'
ORDER BY thread#, sequence# DESC;

PROMPT
PROMPT 26. ARCHIVE DESTINATION STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    destination,
    target,
    status,
    db_unique_name,
    synchronization_status,
    gap_status,
    error
FROM v$archive_dest_status
WHERE target = 'STANDBY'
ORDER BY dest_id;

PROMPT
PROMPT 27. ARCHIVE GAP
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    low_sequence#,
    high_sequence#
FROM v$archive_gap
ORDER BY thread#;

PROMPT
PROMPT 28. RECENT STANDBY REDO RELATED ALERTS
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       UPPER(message_text) LIKE '%STANDBY REDO%'
    OR UPPER(message_text) LIKE '%REDO LOG%'
    OR UPPER(message_text) LIKE '%RFS%'
    OR UPPER(message_text) LIKE '%MRP%'
    OR UPPER(message_text) LIKE '%ARCHIVE GAP%'
  )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT 29. STANDBY REDO LOG HEALTH SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS standby_groups,
    SUM(
        CASE
            WHEN status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_groups,
    SUM(
        CASE
            WHEN status = 'UNASSIGNED' THEN 1
            ELSE 0
        END
    ) AS unassigned_groups,
    SUM(
        CASE
            WHEN status = 'CLEARING'
              OR status = 'CLEARING_CURRENT'
            THEN 1
            ELSE 0
        END
    ) AS clearing_groups,
    COUNT(DISTINCT thread#) AS covered_threads
FROM v$standby_log;

PROMPT
PROMPT 30. QUICK STANDBY REDO CHECK
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    COUNT(s.group#) AS standby_groups,
    COUNT(DISTINCT s.thread#) AS standby_threads,
    SUM(
        CASE
            WHEN s.status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_groups,
    SUM(
        CASE
            WHEN s.status = 'UNASSIGNED' THEN 1
            ELSE 0
        END
    ) AS unassigned_groups,
    CASE
        WHEN d.database_role NOT IN (
            'PHYSICAL STANDBY',
            'LOGICAL STANDBY'
        )
            THEN 'INFO - DATABASE IS NOT A STANDBY'

        WHEN COUNT(s.group#) = 0
            THEN 'CHECK - NO STANDBY REDO LOGS FOUND'

        WHEN EXISTS (
            SELECT 1
            FROM v$archive_gap
        )
            THEN 'CHECK - ARCHIVE GAP EXISTS'

        ELSE
            'INFO - REVIEW SRL CONFIGURATION'
    END AS health_status
FROM v$database d
LEFT JOIN v$standby_log s
    ON 1 = 1
GROUP BY d.database_role;

PROMPT
PROMPT ================================================================
PROMPT STANDBY REDO LOG DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Confirm standby redo logs exist.
PROMPT 2. Check SRL coverage for every RAC redo thread.
PROMPT 3. Compare SRL count with online redo configuration.
PROMPT 4. Compare SRL size with the corresponding online redo size.
PROMPT 5. Review ACTIVE and UNASSIGNED SRLs.
PROMPT 6. Check SRL member count and member paths.
PROMPT 7. Identify SRL groups with a single member.
PROMPT 8. Review inconsistent SRL sizes.
PROMPT 9. Check MRP and RFS activity.
PROMPT 10. Check V$ARCHIVE_GAP.
PROMPT 11. Review Data Guard destination status.
PROMPT 12. Review recent standby redo related alert messages.
PROMPT
PROMPT IMPORTANT:
PROMPT - This script is read-only.
PROMPT - Standby redo requirements depend on the Data Guard architecture.
PROMPT - A common design uses sufficient SRLs per primary redo thread,
PROMPT   but exact requirements should be validated against the Oracle
PROMPT   Data Guard configuration and version.
PROMPT - SRLs are normally expected to be sized appropriately for the
PROMPT   corresponding online redo logs.
PROMPT - ACTIVE does not automatically mean a problem.
PROMPT - UNASSIGNED is not automatically an error.
PROMPT - A single SRL member is a resilience concern, not necessarily
PROMPT   an immediate failure.
PROMPT - V$MANAGED_STANDBY is version-dependent.
PROMPT - Do not add, drop, or resize standby redo logs based only on
PROMPT   this report.
PROMPT
PROMPT ================================================================
PROMPT END OF STANDBY REDO LOG STATUS MONITOR
PROMPT ================================================================
 