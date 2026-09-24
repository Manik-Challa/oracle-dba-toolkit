-- ================================================================
-- Oracle DBA Toolkit
-- Script : dataguard_destinations.sql
-- Purpose: Monitor Oracle Data Guard Archive Destinations
-- Usage  : Run as SYS or a user with access to required V$ views
-- Scope  : Read-only monitoring
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name              FORMAT A20
COLUMN db_unique_name    FORMAT A25
COLUMN destination       FORMAT A60
COLUMN status             FORMAT A15
COLUMN type               FORMAT A12
COLUMN database_mode     FORMAT A20
COLUMN recovery_mode     FORMAT A30
COLUMN protection_mode   FORMAT A25
COLUMN protection_level  FORMAT A25
COLUMN error              FORMAT A70
COLUMN destination_name  FORMAT A25
COLUMN target             FORMAT A10
COLUMN valid_now         FORMAT A12
COLUMN valid_type        FORMAT A15
COLUMN binding           FORMAT A12
COLUMN schedule          FORMAT A12
COLUMN process           FORMAT A12
COLUMN archiver          FORMAT A12
COLUMN transmit_mode     FORMAT A20
COLUMN affirm            FORMAT A10
COLUMN net_timeout       FORMAT 999999
COLUMN reopen_secs       FORMAT 999999
COLUMN delay_mins        FORMAT 999999
COLUMN destination_id    FORMAT 999
COLUMN thread#           FORMAT 999
COLUMN sequence#         FORMAT 999999999
COLUMN applied_seq       FORMAT 999999999
COLUMN archived_seq      FORMAT 999999999
COLUMN gap               FORMAT 999999999
COLUMN error_count       FORMAT 999999999

PROMPT
PROMPT ================================================================
PROMPT ORACLE DATA GUARD DESTINATION MONITOR
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
PROMPT 2. ARCHIVE DESTINATION CONFIGURATION
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    target,
    status,
    binding,
    schedule,
    valid_now,
    valid_type,
    db_unique_name,
    process,
    transmit_mode,
    affirm,
    net_timeout,
    reopen,
    delay_mins
FROM v$archive_dest
WHERE destination IS NOT NULL
ORDER BY dest_id;

PROMPT
PROMPT 3. ENABLED ARCHIVE DESTINATIONS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    target,
    status,
    db_unique_name,
    binding,
    schedule
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

PROMPT
PROMPT 4. DESTINATIONS WITH ERRORS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    target,
    status,
    db_unique_name,
    error
FROM v$archive_dest
WHERE error IS NOT NULL
ORDER BY dest_id;

PROMPT
PROMPT 5. DESTINATIONS NOT VALID
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    target,
    status,
    valid_now,
    valid_type,
    db_unique_name,
    error
FROM v$archive_dest
WHERE valid_now <> 'YES'
   OR status NOT IN ('VALID', 'INACTIVE')
ORDER BY dest_id;

PROMPT
PROMPT 6. DESTINATION STATUS RUNTIME INFORMATION
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    status,
    type,
    database_mode,
    recovery_mode,
    protection_mode,
    synchronization_status,
    gap_status,
    archived_thread# AS thread#,
    archived_seq# AS archived_seq,
    applied_thread# AS applied_thread,
    applied_seq# AS applied_seq,
    error
FROM v$archive_dest_status
WHERE dest_id > 0
ORDER BY dest_id;

PROMPT
PROMPT 7. REMOTE DATA GUARD DESTINATIONS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    target,
    status,
    db_unique_name,
    binding,
    process,
    transmit_mode,
    affirm,
    net_timeout,
    reopen,
    delay_mins
FROM v$archive_dest
WHERE target = 'STANDBY'
ORDER BY dest_id;

PROMPT
PROMPT 8. VALID REMOTE DESTINATIONS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    status,
    db_unique_name,
    valid_now,
    valid_type,
    binding,
    schedule,
    error
FROM v$archive_dest
WHERE target = 'STANDBY'
  AND status = 'VALID'
ORDER BY dest_id;

PROMPT
PROMPT 9. STANDBY DESTINATIONS WITH ERRORS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    db_unique_name,
    status,
    error
FROM v$archive_dest
WHERE target = 'STANDBY'
  AND error IS NOT NULL
ORDER BY dest_id;

PROMPT
PROMPT 10. DESTINATION SYNCHRONIZATION STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    db_unique_name,
    status,
    synchronization_status,
    gap_status,
    archived_thread# AS thread#,
    archived_seq# AS archived_seq,
    applied_thread# AS applied_thread,
    applied_seq# AS applied_seq,
    error
FROM v$archive_dest_status
WHERE target = 'STANDBY'
ORDER BY dest_id;

PROMPT
PROMPT 11. DESTINATIONS WITH TRANSPORT / GAP PROBLEMS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    db_unique_name,
    status,
    synchronization_status,
    gap_status,
    error
FROM v$archive_dest_status
WHERE synchronization_status NOT IN ('CHECK CONFIGURATION', 'VALID', 'DESTINATION HAS A GAP')
   OR gap_status NOT IN ('NO GAP', 'UNKNOWN')
   OR error IS NOT NULL
ORDER BY dest_id;

PROMPT
PROMPT 12. DESTINATION ERROR DETAILS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    db_unique_name,
    status,
    error
FROM v$archive_dest
WHERE error IS NOT NULL
   OR status = 'ERROR'
ORDER BY dest_id;

PROMPT
PROMPT 13. DESTINATION LOG TRANSPORT SETTINGS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    db_unique_name,
    status,
    process,
    transmit_mode,
    affirm,
    net_timeout,
    reopen,
    binding,
    delay_mins
FROM v$archive_dest
WHERE target = 'STANDBY'
ORDER BY dest_id;

PROMPT
PROMPT 14. DESTINATION VALIDATION SETTINGS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    destination,
    target,
    status,
    valid_now,
    valid_type,
    binding,
    schedule
FROM v$archive_dest
ORDER BY dest_id;

PROMPT
PROMPT 15. DATA GUARD DESTINATION STATUS SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    target,
    status,
    COUNT(*) AS destination_count
FROM v$archive_dest
WHERE destination IS NOT NULL
GROUP BY target, status
ORDER BY target, status;

PROMPT
PROMPT 16. DESTINATION ERROR SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    CASE
        WHEN error IS NULL THEN 'NO ERROR'
        ELSE 'ERROR PRESENT'
    END AS error_status,
    COUNT(*) AS destination_count
FROM v$archive_dest
WHERE destination IS NOT NULL
GROUP BY
    CASE
        WHEN error IS NULL THEN 'NO ERROR'
        ELSE 'ERROR PRESENT'
    END
ORDER BY error_status;

PROMPT
PROMPT 17. DATA GUARD TRANSPORT LAG
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    datum_time,
    time_computed
FROM v$dataguard_stats
WHERE name IN (
    'transport lag',
    'apply lag',
    'apply finish time',
    'estimated startup time'
)
ORDER BY name;

PROMPT
PROMPT 18. ARCHIVE DESTINATION STATUS FROM GV$ VIEW
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    dest_id AS destination_id,
    status,
    type,
    database_mode,
    recovery_mode,
    synchronization_status,
    gap_status,
    archived_thread# AS thread#,
    archived_seq# AS archived_seq,
    applied_thread# AS applied_thread,
    applied_seq# AS applied_seq,
    error
FROM gv$archive_dest_status
WHERE dest_id > 0
ORDER BY dest_id, inst_id;

PROMPT
PROMPT 19. RAC DESTINATION STATUS BY INSTANCE
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    dest_id AS destination_id,
    status,
    db_unique_name,
    synchronization_status,
    gap_status,
    error
FROM gv$archive_dest_status
WHERE target = 'STANDBY'
ORDER BY dest_id, inst_id;

PROMPT
PROMPT 20. DATA GUARD ARCHIVE GAP
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    low_sequence#,
    high_sequence#
FROM v$archive_gap
ORDER BY thread#;

PROMPT
PROMPT 21. LATEST ARCHIVED SEQUENCE BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_archived_sequence
FROM v$archived_log
WHERE archived = 'YES'
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 22. LATEST APPLIED SEQUENCE BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_applied_sequence
FROM v$archived_log
WHERE applied = 'YES'
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 23. DESTINATION STATUS WITH SEQUENCE INFORMATION
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    db_unique_name,
    status,
    archived_thread# AS thread#,
    archived_seq# AS archived_seq,
    applied_thread# AS applied_thread,
    applied_seq# AS applied_seq,
    gap_status,
    synchronization_status
FROM v$archive_dest_status
WHERE target = 'STANDBY'
ORDER BY dest_id;

PROMPT
PROMPT 24. RECENT DATA GUARD RELATED ALERT MESSAGES
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       UPPER(message_text) LIKE '%DATA GUARD%'
    OR UPPER(message_text) LIKE '%DATAGUARD%'
    OR UPPER(message_text) LIKE '%ARCHIVE DEST%'
    OR UPPER(message_text) LIKE '%LNS%'
    OR UPPER(message_text) LIKE '%RFS%'
    OR UPPER(message_text) LIKE '%MRP%'
  )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT 25. DESTINATION HEALTH INDICATORS
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS configured_destinations,
    SUM(CASE WHEN status = 'VALID' THEN 1 ELSE 0 END) AS valid_destinations,
    SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) AS error_destinations,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_destinations,
    SUM(CASE WHEN error IS NOT NULL THEN 1 ELSE 0 END) AS destinations_with_errors
FROM v$archive_dest
WHERE destination IS NOT NULL;

PROMPT
PROMPT 26. STANDBY DESTINATION HEALTH
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS standby_destinations,
    SUM(CASE WHEN status = 'VALID' THEN 1 ELSE 0 END) AS valid_standby_destinations,
    SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) AS error_standby_destinations,
    SUM(CASE WHEN error IS NOT NULL THEN 1 ELSE 0 END) AS standby_destinations_with_errors
FROM v$archive_dest
WHERE target = 'STANDBY';

PROMPT
PROMPT 27. QUICK DATA GUARD DESTINATION CHECK
PROMPT ----------------------------------------------------------------

SELECT
    dest_id AS destination_id,
    db_unique_name,
    status,
    synchronization_status,
    gap_status,
    CASE
        WHEN status = 'ERROR'
            THEN 'CHECK - DESTINATION ERROR'
        WHEN error IS NOT NULL
            THEN 'CHECK - DESTINATION HAS ERROR'
        WHEN gap_status = 'DESTINATION HAS A GAP'
            THEN 'CHECK - ARCHIVE GAP'
        WHEN synchronization_status NOT IN
             ('CHECK CONFIGURATION', 'VALID')
            THEN 'CHECK - SYNCHRONIZATION STATUS'
        ELSE
            'OK - DESTINATION STATUS LOOKS NORMAL'
    END AS health_status,
    error
FROM v$archive_dest_status
WHERE target = 'STANDBY'
ORDER BY dest_id;

PROMPT
PROMPT ================================================================
PROMPT DATA GUARD DESTINATION DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Confirm intended archive destinations are configured.
PROMPT 2. Check destination STATUS.
PROMPT 3. Review destinations with ERROR messages.
PROMPT 4. Check VALID_NOW and VALID_TYPE.
PROMPT 5. Review transport/synchronization status.
PROMPT 6. Check Data Guard GAP_STATUS.
PROMPT 7. Review transport and apply lag.
PROMPT 8. Check destination network/transport settings.
PROMPT 9. Review RAC destination status per instance.
PROMPT 10. Check V$ARCHIVE_GAP for standby gaps.
PROMPT 11. Review recent Data Guard-related alert messages.
PROMPT 12. Correlate destination issues with LNS/RFS/MRP activity.
PROMPT 13. Confirm standby redo logs and redo thread coverage.
PROMPT 14. Investigate before changing LOG_ARCHIVE_DEST parameters.
PROMPT
PROMPT IMPORTANT:
PROMPT - INACTIVE is not automatically an error; it may be intentional.
PROMPT - ERROR status requires investigation of the destination error.
PROMPT - GAP_STATUS should be interpreted with V$ARCHIVE_GAP and DG state.
PROMPT - Sequence differences are investigation indicators, not formal lag.
PROMPT - Use V$DATAGUARD_STATS for transport/apply lag where applicable.
PROMPT - RAC environments should be reviewed per instance/thread.
PROMPT - V$ARCHIVE_DEST_STATUS columns can vary by Oracle release.
PROMPT - Do not modify archive destinations based only on this report.
PROMPT - This script performs monitoring only; no configuration changes.
PROMPT
PROMPT ================================================================
PROMPT END OF DATA GUARD DESTINATION MONITOR
PROMPT ================================================================
 