-- -----------------------------------------------------------------------------------
-- Description  : Lists all objects being accessed in the schema.
-- Call Syntax  : @access (schema-name)
-- Requirements : Access to the v$views.
-- -----------------------------------------------------------------------------------
SET SERVEROUTPUT ON
SET PAGESIZE 1000
SET LINESIZE 255
SET VERIFY OFF

SELECT Substr(a.object,1,30) object,
       a.type,
       a.sid,
       b.username,
       b.osuser,
       b.program
FROM   v$access a,
       v$session b
WHERE  a.sid   = b.sid
AND    a.owner = Upper('&1');

PROMPT
SET PAGESIZE 18