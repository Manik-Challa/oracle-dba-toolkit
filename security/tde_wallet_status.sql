-- ================================================================
-- Oracle DBA Toolkit
-- TDE / Wallet / Keystore Status Monitoring
-- File: oracle/monitoring/tde_wallet_status.sql
--
-- Purpose:
--   Monitor Oracle TDE wallet / keystore configuration and status.
--
-- Covers:
--   1. Database / instance information
--   2. WALLET_ROOT
--   3. TDE_CONFIGURATION
--   4. V$ENCRYPTION_WALLET
--   5. Wallet status by container
--   6. Wallet type and keystore type
--   7. Primary / secondary keystore
--   8. Auto-login wallet status
--   9. TDE encrypted tablespaces
--  10. Encrypted columns
--  11. TDE master key information
--  12. Recent wallet/TDE errors
--  13. OKV-related configuration
--  14. RAC wallet consistency
--  15. Wallet health summary
--
-- Read-only monitoring script.
-- Does NOT open/close wallets or modify TDE configuration.
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN INSTANCE_NAME FORMAT A15
COLUMN HOST_NAME FORMAT A35
COLUMN VERSION FORMAT A20
COLUMN STATUS FORMAT A15
COLUMN OPEN_MODE FORMAT A20
COLUMN DATABASE_ROLE FORMAT A20

COLUMN NAME FORMAT A35
COLUMN VALUE FORMAT A100

COLUMN WRL_TYPE FORMAT A15
COLUMN WRL_PARAMETER FORMAT A80
COLUMN WALLET_TYPE FORMAT A20
COLUMN WALLET_OR KEYSTORE FORMAT A20
COLUMN STATUS FORMAT A15
COLUMN KEYSTORE FORMAT A20
COLUMN FULLY_BACKED_UP FORMAT A15

COLUMN CON_ID FORMAT 999
COLUMN CON_NAME FORMAT A25

COLUMN TABLESPACE_NAME FORMAT A30
COLUMN ENCRYPTIONALG FORMAT A20
COLUMN ENCRYPTED FORMAT A10

COLUMN OWNER FORMAT A25
COLUMN TABLE_NAME FORMAT A35
COLUMN COLUMN_NAME FORMAT A35
COLUMN ENCRYPTION_ALG FORMAT A25

COLUMN KEY_ID FORMAT A100
COLUMN ACTIVATION_TIME FORMAT A25
COLUMN CREATION_TIME FORMAT A25

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
PROMPT 4. ENCRYPTION WALLET / KEYSTORE STATUS
PROMPT ================================================================

SELECT
    con_id,
    wrl_type,
    wrl_parameter,
    wallet_type,
    wallet_or,
    status,
    keystore,
    fully_backed_up
FROM v$encryption_wallet
ORDER BY con_id, wallet_or;


PROMPT
PROMPT ================================================================
PROMPT 5. WALLET STATUS SUMMARY
PROMPT ================================================================

SELECT
    status,
    COUNT(*) AS wallet_count
FROM v$encryption_wallet
GROUP BY status
ORDER BY status;


PROMPT
PROMPT ================================================================
PROMPT 6. WALLET TYPE SUMMARY
PROMPT ================================================================

SELECT
    wallet_type,
    COUNT(*) AS wallet_count
FROM v$encryption_wallet
GROUP BY wallet_type
ORDER BY wallet_type;


PROMPT
PROMPT ================================================================
PROMPT 7. PRIMARY / SECONDARY KEYSTORE STATUS
PROMPT ================================================================

SELECT
    con_id,
    wallet_or,
    status,
    wallet_type,
    keystore,
    fully_backed_up
FROM v$encryption_wallet
ORDER BY con_id, wallet_or;


PROMPT
PROMPT ================================================================
PROMPT 8. WALLET STATUS BY CONTAINER
PROMPT ================================================================

SELECT
    w.con_id,
    NVL(c.name, 'UNKNOWN') AS con_name,
    w.wallet_or,
    w.wallet_type,
    w.status,
    w.keystore,
    w.fully_backed_up
FROM v$encryption_wallet w
LEFT JOIN v$containers c
    ON c.con_id = w.con_id
ORDER BY w.con_id, w.wallet_or;


PROMPT
PROMPT ================================================================
PROMPT 9. CLOSED WALLETS / KEYSTORES
PROMPT ================================================================

SELECT
    con_id,
    wrl_type,
    wallet_type,
    wallet_or,
    status,
    keystore,
    wrl_parameter
FROM v$encryption_wallet
WHERE status <> 'OPEN'
ORDER BY con_id, wallet_or;


PROMPT
PROMPT ================================================================
PROMPT 10. WALLET / KEYSTORE CONFIGURATION DETAILS
PROMPT ================================================================

SELECT
    con_id,
    wrl_type,
    wallet_type,
    wallet_or,
    keystore,
    status,
    fully_backed_up,
    wrl_parameter
FROM v$encryption_wallet
ORDER BY con_id, wrl_type, wallet_or;


PROMPT
PROMPT ================================================================
PROMPT 11. TDE ENCRYPTED TABLESPACES
PROMPT ================================================================

SELECT
    tablespace_name,
    encrypted,
    encryptionalg
FROM dba_tablespaces
WHERE encrypted = 'YES'
ORDER BY tablespace_name;


PROMPT
PROMPT ================================================================
PROMPT 12. ENCRYPTED TABLESPACE SUMMARY
PROMPT ================================================================

SELECT
    encrypted,
    COUNT(*) AS tablespace_count
FROM dba_tablespaces
GROUP BY encrypted
ORDER BY encrypted;


PROMPT
PROMPT ================================================================
PROMPT 13. ENCRYPTED COLUMNS
PROMPT ================================================================

SELECT
    owner,
    table_name,
    column_name,
    encryption_alg
FROM dba_encrypted_columns
ORDER BY owner, table_name, column_name;


PROMPT
PROMPT ================================================================
PROMPT 14. ENCRYPTED COLUMN SUMMARY
PROMPT ================================================================

SELECT
    owner,
    COUNT(*) AS encrypted_columns
FROM dba_encrypted_columns
GROUP BY owner
ORDER BY encrypted_columns DESC;


PROMPT
PROMPT ================================================================
PROMPT 15. TDE MASTER KEY INFORMATION
PROMPT ================================================================

SELECT
    keystore_type,
    key_id,
    creation_time,
    activation_time,
    backed_up
FROM v$encryption_keys
ORDER BY activation_time DESC;


PROMPT
PROMPT ================================================================
PROMPT 16. MASTER KEY SUMMARY
PROMPT ================================================================

SELECT
    keystore_type,
    COUNT(*) AS key_count
FROM v$encryption_keys
GROUP BY keystore_type
ORDER BY keystore_type;


PROMPT
PROMPT ================================================================
PROMPT 17. RECENT TDE / WALLET ALERTS - LAST 24 HOURS
PROMPT ================================================================

SELECT
    TO_CHAR(originating_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS message_time,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       UPPER(message_text) LIKE '%WALLET%'
    OR UPPER(message_text) LIKE '%TDE%'
    OR UPPER(message_text) LIKE '%KEYSTORE%'
    OR UPPER(message_text) LIKE '%ORA-283%'
    OR UPPER(message_text) LIKE '%ORA-284%'
    OR UPPER(message_text) LIKE '%OKV%'
  )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ================================================================
PROMPT 18. TDE / WALLET ERRORS - LAST 7 DAYS
PROMPT ================================================================

SELECT
    TO_CHAR(originating_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS message_time,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
       UPPER(message_text) LIKE '%ORA-283%'
    OR UPPER(message_text) LIKE '%ORA-284%'
    OR UPPER(message_text) LIKE '%WALLET%'
    OR UPPER(message_text) LIKE '%KEYSTORE%'
    OR UPPER(message_text) LIKE '%OKV%'
  )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ================================================================
PROMPT 19. ORACLE KEY MANAGER / OKV RELATED PARAMETERS
PROMPT ================================================================

SELECT
    name,
    value
FROM v$parameter
WHERE LOWER(name) IN (
    'wallet_root',
    'tde_configuration'
)
OR UPPER(value) LIKE '%OKV%'
ORDER BY name;


PROMPT
PROMPT ================================================================
PROMPT 20. WALLET STATUS BY INSTANCE - RAC
PROMPT ================================================================

SELECT
    inst_id,
    con_id,
    wallet_or,
    wallet_type,
    status,
    keystore,
    fully_backed_up
FROM gv$encryption_wallet
ORDER BY inst_id, con_id, wallet_or;


PROMPT
PROMPT ================================================================
PROMPT 21. RAC WALLET STATUS CONSISTENCY
PROMPT ================================================================

SELECT
    inst_id,
    status,
    COUNT(*) AS wallet_count
FROM gv$encryption_wallet
GROUP BY inst_id, status
ORDER BY inst_id, status;


PROMPT
PROMPT ================================================================
PROMPT 22. WALLET STATUS HEALTH CHECK
PROMPT ================================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'UNKNOWN - NO WALLET INFORMATION'
        WHEN SUM(CASE WHEN status = 'OPEN' THEN 1 ELSE 0 END) = COUNT(*)
            THEN 'HEALTHY - ALL REPORTED WALLETS OPEN'
        WHEN SUM(CASE WHEN status <> 'OPEN' THEN 1 ELSE 0 END) > 0
            THEN 'WARNING - ONE OR MORE WALLETS NOT OPEN'
        ELSE
            'CHECK REQUIRED'
    END AS wallet_health,
    COUNT(*) AS wallet_entries,
    SUM(CASE WHEN status = 'OPEN' THEN 1 ELSE 0 END) AS open_wallets,
    SUM(CASE WHEN status <> 'OPEN' THEN 1 ELSE 0 END) AS non_open_wallets
FROM v$encryption_wallet;


PROMPT
PROMPT ================================================================
PROMPT 23. TDE MASTER KEY BACKUP STATUS
PROMPT ================================================================

SELECT
    keystore_type,
    backed_up,
    COUNT(*) AS key_count
FROM v$encryption_keys
GROUP BY keystore_type, backed_up
ORDER BY keystore_type, backed_up;


PROMPT
PROMPT ================================================================
PROMPT 24. WALLET / TDE QUICK SUMMARY
PROMPT ================================================================

SELECT
    (SELECT value
       FROM v$parameter
      WHERE name = 'wallet_root') AS wallet_root,
    (SELECT value
       FROM v$parameter
      WHERE name = 'tde_configuration') AS tde_configuration,
    (SELECT COUNT(*)
       FROM v$encryption_wallet
      WHERE status = 'OPEN') AS open_wallets,
    (SELECT COUNT(*)
       FROM v$encryption_wallet
      WHERE status <> 'OPEN') AS non_open_wallets,
    (SELECT COUNT(*)
       FROM dba_tablespaces
      WHERE encrypted = 'YES') AS encrypted_tablespaces,
    (SELECT COUNT(*)
       FROM dba_encrypted_columns) AS encrypted_columns,
    (SELECT COUNT(*)
       FROM v$encryption_keys) AS master_keys
FROM dual;


PROMPT
PROMPT ================================================================
PROMPT DBA CHECKLIST
PROMPT ================================================================
PROMPT
PROMPT [ ] Verify WALLET_ROOT is correctly configured.
PROMPT [ ] Verify TDE_CONFIGURATION matches the intended keystore.
PROMPT [ ] Confirm required wallets / keystores are OPEN.
PROMPT [ ] Check PRIMARY and SECONDARY keystore status.
PROMPT [ ] Check wallet status across all PDBs.
PROMPT [ ] In RAC, verify wallet consistency across instances.
PROMPT [ ] Check recent ORA-283xx / ORA-284xx errors.
PROMPT [ ] Review OKV-related configuration when OKV is used.
PROMPT [ ] Verify TDE master keys exist and backup status.
PROMPT [ ] Review encrypted tablespaces and encrypted columns.
PROMPT [ ] Correlate wallet errors with alert.log and OKV logs.
PROMPT [ ] Do not open/close wallets blindly in production.
PROMPT
PROMPT ================================================================
PROMPT IMPORTANT NOTES
PROMPT ================================================================
PROMPT
PROMPT * This script is READ-ONLY.
PROMPT * It does not open or close wallets.
PROMPT * It does not rotate or create TDE master keys.
PROMPT * It does not modify WALLET_ROOT or TDE_CONFIGURATION.
PROMPT * CLOSED wallet status may be intentional depending on configuration.
PROMPT * UNDEFINED / UNKNOWN values should be investigated in context.
PROMPT * For OKV environments, verify connectivity and OKV-side status.
PROMPT * Cell/OS/network checks may be required for external keystores.
PROMPT * Always correlate database views with alert.log during incidents.
PROMPT
PROMPT ================================================================
PROMPT END OF TDE / WALLET HEALTH CHECK
PROMPT ================================================================

