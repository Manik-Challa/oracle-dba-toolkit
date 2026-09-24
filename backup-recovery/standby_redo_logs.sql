-- ============================================================================
-- standby_redo_logs.sql
-- Oracle DBA Toolkit
--
-- Purpose:
--   Standby Redo Log (SRL) configuration and health check for
--   Oracle Data Guard environments.
--
-- Scope:
--   - Standby redo log groups
--   - SRL status and size
--   - Thread coverage
--   - Primary redo log comparison
--   - RAC thread coverage
--   - SRL sizing checks
--   - SRL groups currently in use
--   - Data Guard destination status
--   - Managed recovery status
--
-- Notes:
--   - Read-only script.
--   - Run on the standby database for the most useful SRL information.
--   - Some sections are also useful on a primary database.
--   - SRL requirements depend on the Data Guard/RAC architecture.
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN db_name              FORMAT A15
COLUMN db_unique_name       FORMAT A25
COLUMN database_role        FORMAT A20
COLUMN open_mode            FORMAT A20
COLUMN protection_mode      FORMAT A25
COLUMN protection_level     FORMAT A25

COLUMN thread#              FORMAT 999
COLUMN group#               FORMAT 9999
COLUMN sequence#            FORMAT 999999999
COLUMN size_mb              FORMAT 9999999990.00
COLUMN blocksize            FORMAT 999999
COLUMN members              FORMAT 999
COLUMN status                FORMAT A12
COLUMN archived              FORMAT A10
COLUMN instance              FORMAT A20
COLUMN first_time            FORMAT A20
COLUMN last_time             FORMAT A20

COLUMN min_size_mb           FORMAT 9999999990.00
COLUMN max_size_mb           FORMAT 9999999990.00
COLUMN primary_groups        FORMAT 999
COLUMN standby_groups        FORMAT 999
COLUMN required_srl_groups   FORMAT 999
COLUMN difference             FORMAT 999

COLUMN dest_id               FORMAT 999
COLUMN destination           FORMAT A45
COLUMN target                FORMAT A10
COLUMN valid_now             FORMAT A12
COLUMN valid_type            FORMAT A15
COLUMN error                 FORMAT A70

COLUMN process               FORMAT A12
COLUMN client_process        FORMAT A20
COLUMN process_status        FORMAT A20
COLUMN recovery_mode         FORMAT A30

PROMPT
PROMPT ============================================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================================

SELECT
    name AS db_name,
    db_unique_name,
    database_role,
    open_mode,
    protection_mode,
    protection_level
FROM v$database;

PROMPT
PROMPT ============================================================================
PROMPT 2. INSTANCE INFORMATION
PROMPT ============================================================================

SELECT
    instance_number,
    instance_name AS instance,
    host_name,
    status,
    thread#
FROM gv$instance
ORDER BY instance_number;

PROMPT
PROMPT ============================================================================
PROMPT 3. ONLINE REDO LOG CONFIGURATION
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    members,
    status,
    archived
FROM gv$log
ORDER BY
    thread#,
    group#;

PROMPT
PROMPT ============================================================================
PROMPT 4. ONLINE REDO LOG MEMBER DETAILS
PROMPT ============================================================================

SELECT
    l.thread#,
    l.group#,
    ROUND(l.bytes / 1024 / 1024, 2) AS size_mb,
    l.members,
    l.status,
    lf.member
FROM gv$log l
JOIN v$logfile lf
    ON l.group# = lf.group#
ORDER BY
    l.thread#,
    l.group#,
    lf.member;

PROMPT
PROMPT ============================================================================
PROMPT 5. STANDBY REDO LOG GROUPS
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    members,
    status,
    archived
FROM gv$standby_log
ORDER BY
    thread#,
    group#;

PROMPT
PROMPT ============================================================================
PROMPT 6. STANDBY REDO LOG MEMBER DETAILS
PROMPT ============================================================================

SELECT
    sl.thread#,
    sl.group#,
    ROUND(sl.bytes / 1024 / 1024, 2) AS size_mb,
    sl.status,
    lf.member
FROM gv$standby_log sl
JOIN v$logfile lf
    ON sl.group# = lf.group#
ORDER BY
    sl.thread#,
    sl.group#,
    lf.member;

PROMPT
PROMPT ============================================================================
PROMPT 7. STANDBY REDO LOG STATUS SUMMARY
PROMPT ============================================================================

SELECT
    status,
    COUNT(*) AS group_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb
FROM gv$standby_log
GROUP BY status
ORDER BY status;

PROMPT
PROMPT ============================================================================
PROMPT 8. STANDBY REDO LOGS CURRENTLY IN USE
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    sequence#,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    status,
    archived,
    first_time,
    last_time
FROM gv$standby_log
WHERE status <> 'UNASSIGNED'
ORDER BY
    thread#,
    group#;

PROMPT
PROMPT ============================================================================
PROMPT 9. STANDBY REDO LOGS BY THREAD
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS standby_groups,
    ROUND(MIN(bytes) / 1024 / 1024, 2) AS min_size_mb,
    ROUND(MAX(bytes) / 1024 / 1024, 2) AS max_size_mb
FROM gv$standby_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT ============================================================================
PROMPT 10. ONLINE REDO LOGS BY THREAD
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS primary_groups,
    ROUND(MIN(bytes) / 1024 / 1024, 2) AS min_size_mb,
    ROUND(MAX(bytes) / 1024 / 1024, 2) AS max_size_mb
FROM gv$log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT ============================================================================
PROMPT 11. SRL COUNT VS ONLINE REDO COUNT
PROMPT ============================================================================

SELECT
    p.thread#,
    p.primary_groups,
    NVL(s.standby_groups, 0) AS standby_groups,
    p.primary_groups + 1 AS recommended_minimum_groups,
    CASE
        WHEN NVL(s.standby_groups, 0) >= p.primary_groups + 1
        THEN 'OK'
        ELSE 'CHECK - SRL COUNT'
    END AS health
FROM
(
    SELECT
        thread#,
        COUNT(*) AS primary_groups
    FROM gv$log
    GROUP BY thread#
) p
LEFT JOIN
(
    SELECT
        thread#,
        COUNT(*) AS standby_groups
    FROM gv$standby_log
    GROUP BY thread#
) s
    ON p.thread# = s.thread#
ORDER BY p.thread#;

PROMPT
PROMPT ============================================================================
PROMPT 12. SRL SIZE VS ONLINE REDO SIZE
PROMPT ============================================================================

SELECT
    p.thread#,
    ROUND(MIN(p.bytes) / 1024 / 1024, 2) AS primary_min_mb,
    ROUND(MAX(p.bytes) / 1024 / 1024, 2) AS primary_max_mb,
    ROUND(MIN(NVL(s.bytes, 0)) / 1024 / 1024, 2) AS standby_min_mb,
    ROUND(MAX(NVL(s.bytes, 0)) / 1024 / 1024, 2) AS standby_max_mb
FROM gv$log p
LEFT JOIN gv$standby_log s
    ON p.thread# = s.thread#
GROUP BY p.thread#
ORDER BY p.thread#;

PROMPT
PROMPT ============================================================================
PROMPT 13. SRL GROUPS SMALLER THAN PRIMARY REDO LOGS
PROMPT ============================================================================

SELECT
    sl.thread#,
    sl.group#,
    ROUND(sl.bytes / 1024 / 1024, 2) AS standby_size_mb,
    ROUND(
        (
            SELECT MAX(l.bytes)
            FROM gv$log l
            WHERE l.thread# = sl.thread#
        ) / 1024 / 1024,
        2
    ) AS primary_max_size_mb,
    CASE
        WHEN sl.bytes <
             (
                 SELECT MAX(l.bytes)
                 FROM gv$log l
                 WHERE l.thread# = sl.thread#
             )
        THEN 'CHECK - SRL SMALLER'
        ELSE 'OK'
    END AS health
FROM gv$standby_log sl
ORDER BY
    sl.thread#,
    sl.group#;

PROMPT
PROMPT ============================================================================
PROMPT 14. RAC THREAD COVERAGE
PROMPT ============================================================================

SELECT
    t.thread#,
    t.primary_groups,
    NVL(s.standby_groups, 0) AS standby_groups,
    CASE
        WHEN NVL(s.standby_groups, 0) >= t.primary_groups + 1
        THEN 'OK'
        ELSE 'CHECK - THREAD SRL COVERAGE'
    END AS health
FROM
(
    SELECT
        thread#,
        COUNT(*) AS primary_groups
    FROM gv$log
    GROUP BY thread#
) t
LEFT JOIN
(
    SELECT
        thread#,
        COUNT(*) AS standby_groups
    FROM gv$standby_log
    GROUP BY thread#
) s
    ON t.thread# = s.thread#
ORDER BY t.thread#;

PROMPT
PROMPT ============================================================================
PROMPT 15. THREADS WITH NO STANDBY REDO LOGS
PROMPT ============================================================================

SELECT
    p.thread#,
    p.primary_groups,
    NVL(s.standby_groups, 0) AS standby_groups,
    'CHECK - NO SRL COVERAGE' AS health
FROM
(
    SELECT
        thread#,
        COUNT(*) AS primary_groups
    FROM gv$log
    GROUP BY thread#
) p
LEFT JOIN
(
    SELECT
        thread#,
        COUNT(*) AS standby_groups
    FROM gv$standby_log
    GROUP BY thread#
) s
    ON p.thread# = s.thread#
WHERE NVL(s.standby_groups, 0) = 0
ORDER BY p.thread#;

PROMPT
PROMPT ============================================================================
PROMPT 16. SRL LOG MEMBERS
PROMPT ============================================================================

SELECT
    sl.thread#,
    sl.group#,
    sl.status,
    lf.type,
    lf.member
FROM gv$standby_log sl
JOIN v$logfile lf
    ON sl.group# = lf.group#
ORDER BY
    sl.thread#,
    sl.group#,
    lf.member;

PROMPT
PROMPT ============================================================================
PROMPT 17. SRL GROUPS WITH SINGLE MEMBER
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    members,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    status,
    CASE
        WHEN members = 1
        THEN 'CHECK - SINGLE MEMBER'
        ELSE 'OK'
    END AS health
FROM gv$standby_log
WHERE members = 1
ORDER BY
    thread#,
    group#;

PROMPT
PROMPT ============================================================================
PROMPT 18. SRL SIZE CONSISTENCY
PROMPT ============================================================================

SELECT
    thread#,
    ROUND(MIN(bytes) / 1024 / 1024, 2) AS min_size_mb,
    ROUND(MAX(bytes) / 1024 / 1024, 2) AS max_size_mb,
    CASE
        WHEN MIN(bytes) = MAX(bytes)
        THEN 'OK - CONSISTENT'
        ELSE 'CHECK - MIXED SRL SIZES'
    END AS health
FROM gv$standby_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT ============================================================================
PROMPT 19. MANAGED RECOVERY PROCESS STATUS
PROMPT ============================================================================

SELECT
    process,
    client_process,
    status,
    thread#,
    sequence#
FROM gv$managed_standby
ORDER BY
    process,
    thread#;

PROMPT
PROMPT ============================================================================
PROMPT 20. MANAGED RECOVERY PROCESS SUMMARY
PROMPT ============================================================================

SELECT
    process,
    status,
    COUNT(*) AS process_count
FROM gv$managed_standby
GROUP BY
    process,
    status
ORDER BY
    process,
    status;

PROMPT
PROMPT ============================================================================
PROMPT 21. REDO APPLY / RECOVERY MODE
PROMPT ============================================================================

SELECT
    recovery_mode,
    COUNT(*) AS process_count
FROM gv$managed_standby
GROUP BY recovery_mode
ORDER BY recovery_mode;

PROMPT
PROMPT ============================================================================
PROMPT 22. CURRENT STANDBY APPLY SEQUENCES
PROMPT ============================================================================

SELECT
    thread#,
    MAX(sequence#) AS latest_srl_sequence
FROM gv$standby_log
WHERE status <> 'UNASSIGNED'
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT ============================================================================
PROMPT 23. DATA GUARD DESTINATION STATUS
PROMPT ============================================================================

SELECT
    dest_id,
    target,
    status,
    valid_now,
    valid_type,
    destination,
    error
FROM v$archive_dest
WHERE target = 'STANDBY'
ORDER BY dest_id;

PROMPT
PROMPT ============================================================================
PROMPT 24. DATA GUARD DESTINATION RUNTIME STATUS
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    type,
    database_mode,
    recovery_mode,
    protection_mode,
    synchronization_status,
    synchronized,
    gap_status,
    error
FROM v$archive_dest_status
WHERE type = 'PHYSICAL'
ORDER BY dest_id;

PROMPT
PROMPT ============================================================================
PROMPT 25. SRL LOGS NOT CURRENTLY ASSIGNED
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS unassigned_groups,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS unassigned_gb
FROM gv$standby_log
WHERE status = 'UNASSIGNED'
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT ============================================================================
PROMPT 26. SRL LOGS CURRENTLY ASSIGNED / ACTIVE
PROMPT ============================================================================

SELECT
    thread#,
    status,
    COUNT(*) AS group_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb
FROM gv$standby_log
WHERE status <> 'UNASSIGNED'
GROUP BY
    thread#,
    status
ORDER BY
    thread#,
    status;

PROMPT
PROMPT ============================================================================
PROMPT 27. SRL HEALTH SUMMARY
PROMPT ============================================================================

SELECT
    COUNT(*) AS total_srl_groups,
    SUM(CASE WHEN status = 'UNASSIGNED' THEN 1 ELSE 0 END)
        AS unassigned_groups,
    SUM(CASE WHEN status <> 'UNASSIGNED' THEN 1 ELSE 0 END)
        AS active_or_assigned_groups,
    SUM(CASE WHEN members = 1 THEN 1 ELSE 0 END)
        AS single_member_groups
FROM gv$standby_log;

PROMPT
PROMPT ============================================================================
PROMPT 28. SRL CONFIGURATION CHECK
PROMPT ============================================================================

SELECT
    CASE
        WHEN NOT EXISTS
             (
                 SELECT 1
                 FROM gv$standby_log
             )
        THEN 'CHECK - NO STANDBY REDO LOGS'
        ELSE 'SRL GROUPS EXIST'
    END AS srl_status
FROM dual;

PROMPT
PROMPT ============================================================================
PROMPT 29. QUICK STANDBY REDO LOG CHECK
PROMPT ============================================================================

SELECT
    (
        SELECT COUNT(*)
        FROM gv$standby_log
    ) AS total_srl_groups,

    (
        SELECT COUNT(*)
        FROM gv$standby_log
        WHERE status = 'UNASSIGNED'
    ) AS unassigned_groups,

    (
        SELECT COUNT(*)
        FROM gv$standby_log
        WHERE members = 1
    ) AS single_member_groups,

    (
        SELECT COUNT(*)
        FROM gv$standby_log sl
        WHERE sl.bytes <
              (
                  SELECT MAX(l.bytes)
                  FROM gv$log l
                  WHERE l.thread# = sl.thread#
              )
    ) AS undersized_srl_groups
FROM dual;

PROMPT
PROMPT ============================================================================
PROMPT 30. DBA CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Confirm standby redo logs exist.
PROMPT [ ] Confirm every primary/RAC thread has SRL coverage.
PROMPT [ ] Confirm SRL count is sufficient for the Data Guard design.
PROMPT [ ] Confirm SRL size is at least the corresponding online redo size.
PROMPT [ ] Confirm SRL members have appropriate multiplexing.
PROMPT [ ] Check SRL STATUS for unexpected assignments or reuse.
PROMPT [ ] Check managed recovery / redo apply processes.
PROMPT [ ] Check V$ARCHIVE_DEST and V$ARCHIVE_DEST_STATUS.
PROMPT [ ] Check transport and apply lag separately.
PROMPT [ ] Investigate Data Guard gap status.
PROMPT [ ] Confirm storage paths for all SRL members.
PROMPT [ ] Consider standby redo log placement and I/O performance.
PROMPT [ ] For RAC, verify SRLs for every redo thread.
PROMPT [ ] Do not add/drop SRLs during an incident without validating the impact.
PROMPT [ ] Use Data Guard Broker / DGMGRL where Broker manages the configuration.
PROMPT
PROMPT ============================================================================
PROMPT END OF STANDBY REDO LOG CHECK
PROMPT ============================================================================

