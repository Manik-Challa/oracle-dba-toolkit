-- ================================================================
-- Oracle DBA Toolkit
-- TDE Master Key Status Monitoring
-- File: oracle/monitoring/tde_key_status.sql
--
-- Purpose:
--   Monitor Oracle Transparent Data Encryption (TDE) master keys
--   and key lifecycle information.
--
-- Covers:
--   1. Database / instance information
--   2. WALLET_ROOT
--   3. TDE_CONFIGURATION
--   4. TDE master key inventory
--   5. Current / active master key
--   6. Key creation and activation history
--   7. Key backup status
--   8. Keystore type
--   9. Keys by container
--  10. Keys by keystore
--  11. Recent TDE key-related alerts
--  12. RAC key visibility
--  13. Key health summary
--
-- Read-only monitoring script.
-- Does NOT create, rotate, activate, or back up keys.
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN INSTANCE_NAME FORMAT A18
COLUMN HOST_NAME FORMAT A35
COLUMN VERSION FORMAT A20
COLUMN STATUS FORMAT A15
COLUMN OPEN_MODE FORMAT A20
COLUMN DATABASE_ROLE FORMAT A20

COLUMN NAME FORMAT A35
COLUMN VALUE FORMAT A100

COLUMN KEY_ID FORMAT A100
COLUMN KEYSTORE_TYPE FORMAT A20
COLUMN CREATION_TIME FORMAT A25
COLUMN ACTIVATION_TIME FORMAT A25
COLUMN BACKED_UP FORMAT A12

COLUMN CON_ID FORMAT 999
COLUMN CON_NAME FORMAT A25

COLUMN MESSAGE_TIME FORMAT A25
COLUMN MESSAGE_TEXT FORMAT A120

PROMPT
PROMPT ================================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ================================================================

SELECT
    i.instance_name,
    i.host_name,
    i.version,
    i.status,
    d.open_mode,
    d.database_role
FROM v$instance i
CROSS JOIN v$database d;


PROMPT
PROMPT ================================================================
PROMPT 2. WALLET_ROOT
PROMPT ================================================================

SELECT
    name,
    value
FROM v$parameter
WHERE name = 'wallet_root';


PROMPT
PROMPT ================================================================
PROMPT 3. TDE_CONFIGURATION
PROMPT ================================================================

SELECT
    name,
    value
FROM v$parameter
WHERE name = 'tde_configuration';


PROMPT
PROMPT ================================================================
PROMPT 4. TDE MASTER KEY INVENTORY
PROMPT ================================================================

SELECT
    key_id,
    keystore_type,
    creation_time,
    activation_time,
    backed_up
FROM v$encryption_keys
ORDER BY activation_time DESC;


PROMPT
PROMPT ================================================================
PROMPT 5. MOST RECENT / ACTIVE MASTER KEY
PROMPT ================================================================

SELECT
    key_id,
    keystore_type,
    creation_time,
    activation_time,
    backed_up
FROM v$encryption_keys
WHERE activation_time = (
    SELECT MAX(activation_time)
    FROM v$encryption_keys
);


PROMPT
PROMPT ================================================================
PROMPT 6. MASTER KEY COUNT BY KEYSTORE TYPE
PROMPT ================================================================

SELECT
    keystore_type,
    COUNT(*) AS key_count
FROM v$encryption_keys
GROUP BY keystore_type
ORDER BY keystore_type;


PROMPT
PROMPT ================================================================
PROMPT 7. MASTER KEY BACKUP STATUS
PROMPT ================================================================

SELECT
    backed_up,
    COUNT(*) AS key_count
FROM v$encryption_keys
GROUP BY backed_up
ORDER BY backed_up;


PROMPT
PROMPT ================================================================
PROMPT 8. MASTER KEYS NOT BACKED UP
PROMPT ================================================================

SELECT
    key_id,
    keystore_type,
    creation_time,
    activation_time,
    backed_up
FROM v$encryption_keys
WHERE NVL(backed_up, 'NO') <> 'YES'
ORDER BY activation_time DESC;


PROMPT
PROMPT ================================================================
PROMPT 9. RECENT MASTER KEY CREATION
PROMPT ================================================================

SELECT
    key_id,
    keystore_type,
    creation_time,
    activation_time,
    backed_up
FROM v$encryption_keys
WHERE creation_time >= SYSTIMESTAMP - INTERVAL '365' DAY
ORDER BY creation_time DESC;


PROMPT
PROMPT ================================================================
PROMPT 10. RECENT MASTER KEY ACTIVATION
PROMPT ================================================================

SELECT
    key_id,
    keystore_type,
    creation_time,
    activation_time,
    backed_up
FROM v$encryption_keys
WHERE activation_time >= SYSTIMESTAMP - INTERVAL '365' DAY
ORDER BY activation_time DESC;


PROMPT
PROMPT ================================================================
PROMPT 11. KEY AGE SUMMARY
PROMPT ================================================================

SELECT
    keystore_type,
    MIN(creation_time) AS oldest_key,
    MAX(creation_time) AS newest_key,
    COUNT(*) AS total_keys
FROM v$encryption_keys
GROUP BY keystore_type
ORDER BY keystore_type;


PROMPT
PROMPT ================================================================
PROMPT 12. KEYS BY CONTAINER
PROMPT ================================================================

SELECT
    con_id,
    COUNT(*) AS key_count
FROM v$encryption_keys
GROUP BY con_id
ORDER BY con_id;


PROMPT
PROMPT ================================================================
PROMPT 13. KEYS BY CONTAINER WITH NAME
PROMPT ================================================================

SELECT
    k.con_id,
    NVL(c.name, 'UNKNOWN') AS con_name,
    k.keystore_type,
    COUNT(*) AS key_count
FROM v$encryption_keys k
LEFT JOIN v$containers c
    ON c.con_id = k.con_id
GROUP BY
    k.con_id,
    c.name,
    k.keystore_type
ORDER BY
    k.con_id,
    k.keystore_type;


PROMPT
PROMPT ================================================================
PROMPT 14. KEY HISTORY BY CONTAINER
PROMPT ================================================================

SELECT
    k.con_id,
    NVL(c.name, 'UNKNOWN') AS con_name,
    k.key_id,
    k.keystore_type,
    k.creation_time,
    k.activation_time,
    k.backed_up
FROM v$encryption_keys k
LEFT JOIN v$containers c
    ON c.con_id = k.con_id
ORDER BY
    k.con_id,
    k.activation_time DESC;


PROMPT
PROMPT ================================================================
PROMPT 15. CURRENT KEY PER CONTAINER
PROMPT ================================================================

SELECT
    k.con_id,
    NVL(c.name, 'UNKNOWN') AS con_name,
    k.key_id,
    k.keystore_type,
    k.creation_time,
    k.activation_time,
    k.backed_up
FROM v$encryption_keys k
LEFT JOIN v$containers c
    ON c.con_id = k.con_id
WHERE k.activation_time = (
    SELECT MAX(k2.activation_time)
    FROM v$encryption_keys k2
    WHERE k2.con_id = k.con_id
)
ORDER BY k.con_id;


PROMPT
PROMPT ================================================================
PROMPT 16. KEYSTORE TYPES IN USE
PROMPT ================================================================

SELECT DISTINCT
    keystore_type
FROM v$encryption_keys
ORDER BY keystore_type;


PROMPT
PROMPT ================================================================
PROMPT 17. TDE KEY / KEYSTORE RELATED ALERTS - LAST 24 HOURS
PROMPT ================================================================

SELECT
    TO_CHAR(
        originating_timestamp,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS message_time,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       UPPER(message_text) LIKE '%TDE%'
    OR UPPER(message_text) LIKE '%KEYSTORE%'
    OR UPPER(message_text) LIKE '%MASTER KEY%'
    OR UPPER(message_text) LIKE '%ORA-283%'
    OR UPPER(message_text) LIKE '%ORA-284%'
    OR UPPER(message_text) LIKE '%KEY MANAGEMENT%'
  )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ================================================================
PROMPT 18. TDE KEY / KEYSTORE ERRORS - LAST 7 DAYS
PROMPT ================================================================

SELECT
    TO_CHAR(
        originating_timestamp,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS message_time,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
       UPPER(message_text) LIKE '%ORA-283%'
    OR UPPER(message_text) LIKE '%ORA-284%'
    OR UPPER(message_text) LIKE '%KEYSTORE%'
    OR UPPER(message_text) LIKE '%MASTER KEY%'
    OR UPPER(message_text) LIKE '%TDE%'
  )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ================================================================
PROMPT 19. KEY-RELATED ORA ERRORS
PROMPT ================================================================

SELECT
    REGEXP_SUBSTR(
        message_text,
        'ORA-[0-9]+'
    ) AS error_code,
    COUNT(*) AS error_count
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND REGEXP_LIKE(
        message_text,
        'ORA-(283|284)[0-9]+'
      )
GROUP BY
    REGEXP_SUBSTR(
        message_text,
        'ORA-[0-9]+'
    )
ORDER BY error_count DESC;


PROMPT
PROMPT ================================================================
PROMPT 20. RAC KEY VISIBILITY
PROMPT ================================================================

SELECT
    inst_id,
    con_id,
    keystore_type,
    COUNT(*) AS key_count
FROM gv$encryption_keys
GROUP BY
    inst_id,
    con_id,
    keystore_type
ORDER BY
    inst_id,
    con_id,
    keystore_type;


PROMPT
PROMPT ================================================================
PROMPT 21. RAC KEY CONSISTENCY CHECK
PROMPT ================================================================

SELECT
    inst_id,
    COUNT(*) AS total_keys,
    COUNT(DISTINCT key_id) AS distinct_key_ids
FROM gv$encryption_keys
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ================================================================
PROMPT 22. MASTER KEY BACKUP HEALTH
PROMPT ================================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'UNKNOWN - NO TDE KEYS FOUND'
        WHEN SUM(
                CASE
                    WHEN NVL(backed_up, 'NO') <> 'YES'
                    THEN 1
                    ELSE 0
                END
             ) = 0
            THEN 'HEALTHY - ALL REPORTED KEYS BACKED UP'
        ELSE
            'WARNING - ONE OR MORE KEYS NOT BACKED UP'
    END AS key_backup_health,
    COUNT(*) AS total_keys,
    SUM(
        CASE
            WHEN NVL(backed_up, 'NO') = 'YES'
            THEN 1
            ELSE 0
        END
    ) AS backed_up_keys,
    SUM(
        CASE
            WHEN NVL(backed_up, 'NO') <> 'YES'
            THEN 1
            ELSE 0
        END
    ) AS keys_not_backed_up
FROM v$encryption_keys;


PROMPT
PROMPT ================================================================
PROMPT 23. TDE KEY HEALTH SUMMARY
PROMPT ================================================================

SELECT
    (SELECT COUNT(*)
       FROM v$encryption_keys) AS total_keys,

    (SELECT COUNT(*)
       FROM v$encryption_keys
      WHERE NVL(backed_up, 'NO') = 'YES') AS backed_up_keys,

    (SELECT COUNT(*)
       FROM v$encryption_keys
      WHERE NVL(backed_up, 'NO') <> 'YES') AS keys_not_backed_up,

    (SELECT COUNT(DISTINCT keystore_type)
       FROM v$encryption_keys) AS keystore_types,

    (SELECT COUNT(DISTINCT con_id)
       FROM v$encryption_keys) AS containers_with_keys
FROM dual;


PROMPT
PROMPT ================================================================
PROMPT 24. TDE KEY HEALTH STATUS
PROMPT ================================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'UNKNOWN - NO MASTER KEYS FOUND'

        WHEN SUM(
                CASE
                    WHEN NVL(backed_up, 'NO') <> 'YES'
                    THEN 1
                    ELSE 0
                END
             ) > 0
            THEN 'WARNING - KEY BACKUP REVIEW REQUIRED'

        ELSE
            'HEALTHY - MASTER KEY BACKUP STATUS OK'
    END AS key_health
FROM v$encryption_keys;


PROMPT
PROMPT ================================================================
PROMPT DBA CHECKLIST
PROMPT ================================================================
PROMPT
PROMPT [ ] Confirm TDE master keys exist.
PROMPT [ ] Identify the current/most recently activated key.
PROMPT [ ] Verify key creation and activation history.
PROMPT [ ] Verify master-key backup status.
PROMPT [ ] Investigate keys reported as not backed up.
PROMPT [ ] Verify expected keystore type.
PROMPT [ ] Check key visibility across PDBs.
PROMPT [ ] In RAC, compare key visibility across instances.
PROMPT [ ] Review recent ORA-283xx / ORA-284xx errors.
PROMPT [ ] Correlate key issues with alert.log.
PROMPT [ ] Confirm OKV integration when an external keystore is used.
PROMPT [ ] Do not rotate/create keys as part of monitoring.
PROMPT
PROMPT ================================================================
PROMPT IMPORTANT NOTES
PROMPT ================================================================
PROMPT
PROMPT * This script is READ-ONLY.
PROMPT * It does not create or rotate TDE master keys.
PROMPT * It does not activate or back up keys.
PROMPT * Historical keys may legitimately exist.
PROMPT * Multiple keys do not automatically indicate a problem.
PROMPT * Key backup status should be interpreted according to the
PROMPT   organization's TDE key-management procedure.
PROMPT * In RAC, compare key visibility and configuration carefully.
PROMPT * In OKV environments, database-side views should be correlated
PROMPT   with OKV-side key and connectivity information.
PROMPT * Availability of individual columns/views can vary by
PROMPT   Oracle release and configuration.
PROMPT
PROMPT ================================================================
PROMPT END OF TDE MASTER KEY STATUS CHECK
PROMPT ================================================================

