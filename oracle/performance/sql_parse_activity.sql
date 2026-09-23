-- ============================================================
-- Oracle DBA Toolkit
-- Script   : sql_parse_activity.sql
-- Purpose  : Monitor SQL parsing activity, hard parses,
--            soft parses, and parse-related workload
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN metric_name          FORMAT A35
COLUMN parsing_schema       FORMAT A25
COLUMN module               FORMAT A30
COLUMN sql_id               FORMAT A15
COLUMN executions           FORMAT 999,999,999,999
COLUMN parse_calls          FORMAT 999,999,999,999
COLUMN loads                FORMAT 999,999,999
COLUMN invalidations        FORMAT 999,999,999
COLUMN hard_parse_pct       FORMAT 999.99
COLUMN parses_per_exec      FORMAT 999.99
COLUMN sql_text             FORMAT A100 WORD_WRAPPED


PROMPT
PROMPT ============================================================
PROMPT DATABASE PARSE STATISTICS
PROMPT ============================================================

SELECT
    name AS metric_name,
    value
FROM v$sysstat
WHERE name IN
(
    'parse count (total)',
    'parse count (hard)',
    'parse count (failures)',
    'parse count (describe)',
    'execute count',
    'user calls'
)
ORDER BY name;


PROMPT
PROMPT ============================================================
PROMPT PARSE TO EXECUTE RATIO
PROMPT ============================================================

SELECT
    SUM(
        CASE
            WHEN name = 'parse count (total)'
            THEN value
        END
    ) AS total_parses,

    SUM(
        CASE
            WHEN name = 'parse count (hard)'
            THEN value
        END
    ) AS hard_parses,

    SUM(
        CASE
            WHEN name = 'execute count'
            THEN value
        END
    ) AS executions,

    ROUND(
        SUM(
            CASE
                WHEN name = 'parse count (total)'
                THEN value
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN name = 'execute count'
                    THEN value
                END
            ),
            0
        ) * 100,
        2
    ) AS parse_to_execute_pct
FROM v$sysstat
WHERE name IN
(
    'parse count (total)',
    'parse count (hard)',
    'execute count'
);


PROMPT
PROMPT ============================================================
PROMPT HARD PARSE PERCENTAGE
PROMPT ============================================================

SELECT
    total_parses,
    hard_parses,
    ROUND(
        hard_parses /
        NULLIF(total_parses, 0) * 100,
        2
    ) AS hard_parse_pct
FROM
(
    SELECT
        MAX(
            CASE
                WHEN name = 'parse count (total)'
                THEN value
            END
        ) AS total_parses,
        MAX(
            CASE
                WHEN name = 'parse count (hard)'
                THEN value
            END
        ) AS hard_parses
    FROM v$sysstat
);


PROMPT
PROMPT ============================================================
PROMPT PARSE FAILURES
PROMPT ============================================================

SELECT
    name AS metric_name,
    value
FROM v$sysstat
WHERE name IN
(
    'parse count (failures)',
    'parse count (hard)',
    'parse count (total)'
)
ORDER BY name;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGHEST PARSE CALLS
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    parse_calls,
    executions,
    ROUND(
        parse_calls /
        NULLIF(executions, 0),
        2
    ) AS parses_per_exec,
    loads,
    invalidations,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE parse_calls > 0
ORDER BY parse_calls DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH PARSE CALLS PER EXECUTION
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    parse_calls,
    executions,
    ROUND(
        parse_calls /
        NULLIF(executions, 0),
        2
    ) AS parses_per_exec,
    loads,
    invalidations,
    ROUND(
        cpu_time /
        NULLIF(executions, 0) / 1000,
        2
    ) AS cpu_per_exec_ms,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND parse_calls > 0
ORDER BY parse_calls / NULLIF(executions, 0) DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH PARSES AND LOW EXECUTION COUNT
PROMPT ============================================================
PROMPT Useful for identifying SQL that is parsed repeatedly.
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    parse_calls,
    executions,
    loads,
    invalidations,
    ROUND(
        parse_calls /
        NULLIF(executions, 0),
        2
    ) AS parses_per_exec,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE parse_calls > 100
  AND executions > 0
ORDER BY parse_calls DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT PARSE ACTIVITY BY PARSING SCHEMA
PROMPT ============================================================

SELECT
    parsing_schema_name AS parsing_schema,
    COUNT(DISTINCT sql_id) AS sql_count,
    SUM(parse_calls) AS parse_calls,
    SUM(executions) AS executions,
    SUM(loads) AS loads,
    SUM(invalidations) AS invalidations,
    ROUND(
        SUM(parse_calls) /
        NULLIF(SUM(executions), 0),
        2
    ) AS parses_per_exec
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
GROUP BY parsing_schema_name
ORDER BY parse_calls DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT PARSE ACTIVITY BY MODULE
PROMPT ============================================================

SELECT
    NVL(module, 'UNKNOWN') AS module,
    COUNT(DISTINCT sql_id) AS sql_count,
    SUM(parse_calls) AS parse_calls,
    SUM(executions) AS executions,
    SUM(loads) AS loads,
    SUM(invalidations) AS invalidations,
    ROUND(
        SUM(parse_calls) /
        NULLIF(SUM(executions), 0),
        2
    ) AS parses_per_exec
FROM v$sql
GROUP BY NVL(module, 'UNKNOWN')
ORDER BY parse_calls DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH PARSES AND MULTIPLE CHILD CURSORS
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    SUM(parse_calls) AS parse_calls,
    SUM(executions) AS executions,
    SUM(loads) AS loads,
    SUM(invalidations) AS invalidations,
    ROUND(
        SUM(parse_calls) /
        NULLIF(SUM(executions), 0),
        2
    ) AS parses_per_exec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING SUM(parse_calls) > 100
   AND COUNT(*) > 1
ORDER BY parse_calls DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH PARSES AND MULTIPLE PLANS
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    SUM(parse_calls) AS parse_calls,
    SUM(executions) AS executions,
    SUM(loads) AS loads,
    SUM(invalidations) AS invalidations,
    ROUND(
        SUM(parse_calls) /
        NULLIF(SUM(executions), 0),
        2
    ) AS parses_per_exec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING SUM(parse_calls) > 100
   AND COUNT(DISTINCT plan_hash_value) > 1
ORDER BY parse_calls DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT ACTIVE SESSIONS WITH PARSE-HEAVY SQL
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    q.parse_calls,
    q.executions,
    ROUND(
        q.parse_calls /
        NULLIF(q.executions, 0),
        2
    ) AS parses_per_exec,
    q.loads,
    q.invalidations,
    s.event,
    s.wait_class,
    s.module,
    SUBSTR(q.sql_text, 1, 100) AS sql_text
FROM v$session s
JOIN v$sql q
    ON q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND q.parse_calls > 0
ORDER BY q.parse_calls DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT PARSING / CURSOR SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS sql_cursors,
    COUNT(DISTINCT sql_id) AS sql_count,
    SUM(parse_calls) AS parse_calls,
    SUM(executions) AS executions,
    SUM(loads) AS loads,
    SUM(invalidations) AS invalidations,
    ROUND(
        SUM(parse_calls) /
        NULLIF(SUM(executions), 0),
        2
    ) AS parses_per_exec
FROM v$sql;


PROMPT
PROMPT ============================================================
PROMPT PARSE INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT If parse activity is high:
PROMPT
PROMPT 1. Check parse count (total).
PROMPT 2. Check parse count (hard).
PROMPT 3. Check parse count (failures).
PROMPT 4. Compare parses with executions.
PROMPT 5. Identify SQL with high PARSE_CALLS.
PROMPT 6. Check SQL with high PARSE_CALLS / EXECUTIONS.
PROMPT 7. Check multiple child cursors.
PROMPT 8. Check SQL invalidations.
PROMPT 9. Check multiple execution plans.
PROMPT 10. Investigate application cursor handling.
PROMPT
PROMPT ============================================================
PROMPT DBA NOTES
PROMPT ============================================================
PROMPT
PROMPT PARSE CALLS are cumulative SQL cursor statistics.
PROMPT
PROMPT High parse activity can be associated with:
PROMPT
PROMPT   - Excessive hard parsing
PROMPT   - Poor application cursor management
PROMPT   - Frequent SQL invalidations
PROMPT   - Excessive child cursors
PROMPT   - Literal SQL instead of bind variables
PROMPT   - Shared pool pressure
PROMPT
PROMPT High parse count alone does not automatically indicate
PROMPT a performance problem. Review the workload, execution
PROMPT count, hard parse count, CPU usage, and application behavior.
PROMPT
PROMPT For accurate parse rates, compare V$SYSSTAT snapshots
PROMPT over a defined time interval.
PROMPT
PROMPT ============================================================

