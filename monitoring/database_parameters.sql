-- ============================================================
-- Oracle Database Parameters Monitoring
-- File   : database_parameters.sql
-- Purpose: Monitor important and non-default database parameters
-- Author : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name             FORMAT A45
COLUMN value            FORMAT A100 WORD_WRAP
COLUMN display_value    FORMAT A100 WORD_WRAP
COLUMN description      FORMAT A80 WORD_WRAP
COLUMN isdefault        FORMAT A10
COLUMN issys_modifiable FORMAT A18
COLUMN isinstance_modifiable FORMAT A20
COLUMN ismodified       FORMAT A15
COLUMN type             FORMAT 999

PROMPT
PROMPT ============================================================
PROMPT ORACLE DATABASE PARAMETERS MONITORING
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
    database_role,
    log_mode
FROM v$database;

SELECT
    instance_name,
    host_name,
    version,
    status,
    startup_time
FROM v$instance;

-- ============================================================
-- 2. MEMORY PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. MEMORY PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'memory_target',
    'memory_max_target',
    'sga_target',
    'sga_max_size',
    'pga_aggregate_target',
    'pga_aggregate_limit',
    'use_large_pages',
    'pre_page_sga',
    'lock_sga'
)
ORDER BY name;

-- ============================================================
-- 3. PROCESSES / SESSIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. PROCESSES / SESSIONS PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'processes',
    'sessions',
    'transactions',
    'open_cursors',
    'sessions_cached_cursors'
)
ORDER BY name;

-- ============================================================
-- 4. UNDO PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. UNDO PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'undo_management',
    'undo_tablespace',
    'undo_retention',
    'temp_undo_enabled'
)
ORDER BY name;

-- ============================================================
-- 5. REDO / ARCHIVE PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. REDO / ARCHIVE PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'log_archive_start',
    'log_archive_dest',
    'log_archive_dest_1',
    'log_archive_dest_2',
    'log_archive_dest_3',
    'log_archive_dest_4',
    'log_archive_dest_5',
    'log_archive_dest_6',
    'log_archive_dest_7',
    'log_archive_dest_8',
    'log_archive_dest_9',
    'log_archive_dest_10',
    'log_archive_dest_state_1',
    'log_archive_dest_state_2',
    'log_archive_format'
)
ORDER BY name;

-- ============================================================
-- 6. CONTROL FILE / RECOVERY PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. CONTROL FILE / RECOVERY PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'control_files',
    'db_recovery_file_dest',
    'db_recovery_file_dest_size',
    'db_create_file_dest'
)
ORDER BY name;

-- ============================================================
-- 7. OPTIMIZER PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. OPTIMIZER PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'optimizer_mode',
    'optimizer_features_enable',
    'optimizer_dynamic_sampling',
    'optimizer_index_cost_adj',
    'optimizer_index_caching',
    'cursor_sharing',
    'statistics_level',
    'optimizer_adaptive_plans',
    'optimizer_adaptive_statistics'
)
ORDER BY name;

-- ============================================================
-- 8. CURSOR / SHARED POOL PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. CURSOR / SHARED POOL PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'open_cursors',
    'session_cached_cursors',
    'cursor_sharing',
    'shared_pool_size',
    'shared_pool_reserved_size'
)
ORDER BY name;

-- ============================================================
-- 9. PARALLEL EXECUTION PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. PARALLEL EXECUTION PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'parallel_degree_policy',
    'parallel_degree_limit',
    'parallel_max_servers',
    'parallel_min_servers',
    'parallel_servers_target',
    'parallel_min_percent',
    'parallel_force_local',
    'parallel_execution_message_size'
)
ORDER BY name;

-- ============================================================
-- 10. SECURITY / AUDIT PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. SECURITY / AUDIT PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'audit_trail',
    'audit_sys_operations',
    'audit_syslog_level',
    'os_authent_prefix',
    'remote_os_authent',
    'remote_login_passwordfile',
    'sec_case_sensitive_logon'
)
ORDER BY name;

-- ============================================================
-- 11. NETWORK / CONNECTION PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. NETWORK / CONNECTION PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'local_listener',
    'remote_listener',
    'dispatchers',
    'shared_servers',
    'max_dispatchers',
    'max_shared_servers',
    'inbound_connect_timeout'
)
ORDER BY name;

-- ============================================================
-- 12. FILE / TABLESPACE PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. FILE / TABLESPACE PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'db_files',
    'db_block_size',
    'db_writer_processes',
    'filesystemio_options',
    'disk_asynch_io',
    'db_create_file_dest',
    'db_create_online_log_dest_1',
    'db_create_online_log_dest_2'
)
ORDER BY name;

-- ============================================================
-- 13. NLS PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. NLS PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault
FROM v$parameter
WHERE name LIKE 'nls_%'
ORDER BY name;

-- ============================================================
-- 14. TDE / WALLET PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. TDE / WALLET PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name IN
(
    'wallet_root',
    'tde_configuration'
)
ORDER BY name;

-- ============================================================
-- 15. NON-DEFAULT PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. NON-DEFAULT PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE isdefault = 'FALSE'
ORDER BY name;

-- ============================================================
-- 16. PARAMETERS MODIFIED FROM DEFAULT
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. MODIFIED PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE ismodified <> 'FALSE'
ORDER BY name;

-- ============================================================
-- 17. PARAMETERS REQUIRING RESTART
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. PARAMETERS NOT DYNAMICALLY MODIFIABLE
PROMPT ============================================================

SELECT
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable,
    isinstance_modifiable
FROM v$parameter
WHERE issys_modifiable = 'FALSE'
ORDER BY name;

-- ============================================================
-- 18. HIDDEN / UNDERSCORE PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. HIDDEN / UNDERSCORE PARAMETERS
PROMPT ============================================================

SELECT
    name,
    value,
    isdefault,
    issys_modifiable,
    ismodified
FROM v$parameter
WHERE name LIKE '\_%' ESCAPE '\'
ORDER BY name;

-- ============================================================
-- 19. RAC INSTANCE-SPECIFIC PARAMETERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. RAC INSTANCE-SPECIFIC PARAMETER VALUES
PROMPT ============================================================

SELECT
    inst_id,
    name,
    value,
    isdefault,
    issys_modifiable,
    ismodified
FROM gv$parameter
WHERE name IN
(
    'instance_number',
    'thread',
    'instance_name',
    'instance_groups',
    'undo_tablespace',
    'local_listener',
    'remote_listener'
)
ORDER BY name, inst_id;

-- ============================================================
-- 20. IMPORTANT PARAMETERS QUICK VIEW
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. IMPORTANT PARAMETERS QUICK VIEW
PROMPT ============================================================

SELECT
    name,
    display_value,
    isdefault,
    ismodified
FROM v$parameter
WHERE name IN
(
    'processes',
    'sessions',
    'transactions',
    'open_cursors',
    'sga_target',
    'sga_max_size',
    'pga_aggregate_target',
    'pga_aggregate_limit',
    'memory_target',
    'memory_max_target',
    'undo_tablespace',
    'undo_retention',
    'db_recovery_file_dest',
    'db_recovery_file_dest_size',
    'optimizer_mode',
    'optimizer_features_enable',
    'cursor_sharing',
    'statistics_level',
    'parallel_degree_policy',
    'remote_login_passwordfile',
    'audit_trail',
    'wallet_root',
    'tde_configuration'
)
ORDER BY name;

-- ============================================================
-- 21. PARAMETER HEALTH SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 21. PARAMETER HEALTH SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS total_parameters,
    SUM(
        CASE
            WHEN isdefault = 'FALSE' THEN 1
            ELSE 0
        END
    ) AS non_default_parameters,
    SUM(
        CASE
            WHEN ismodified <> 'FALSE' THEN 1
            ELSE 0
        END
    ) AS modified_parameters
FROM v$parameter;

PROMPT
PROMPT ============================================================
PROMPT INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. Non-default does not automatically mean incorrect.
PROMPT 2. Compare important parameters with your approved baseline.
PROMPT 3. Check ISMODIFIED before assuming a parameter change is persistent.
PROMPT 4. Parameters with ISSYS_MODIFIABLE = FALSE generally require restart.
PROMPT 5. RAC environments should be checked through GV$PARAMETER.
PROMPT 6. Investigate underscore parameters carefully before changing them.
PROMPT 7. Do not change production parameters from a monitoring script.
PROMPT 8. Validate parameter changes against Oracle documentation and your
PROMPT    organization's change-management process.
PROMPT
PROMPT ============================================================
PROMPT END OF DATABASE PARAMETER MONITORING
PROMPT ============================================================

