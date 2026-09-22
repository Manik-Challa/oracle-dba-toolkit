Oracle DBA Toolkit 🚀



A practical collection of Oracle Database administration scripts, troubleshooting utilities, performance checks, security checks, storage monitoring, and operational runbooks.



Built for Oracle DBAs who need quick, reusable scripts for daily health checks, troubleshooting, performance analysis, security monitoring, and database operations.





🧰 How to Use



Clone the repository:



git clone https://github.com/Manik-Challa/oracle-dba-toolkit.git



Move into the repository:



cd oracle-dba-toolkit



Connect to Oracle using SQL\*Plus:



sqlplus / as sysdba



Run any script:



@oracle/health-check/database\_status.sql



or:



@oracle/performance/blocking\_sessions.sql





⚠️ Requirements



Most scripts are designed for Oracle Database environments where the DBA has access to the required dynamic performance views and data dictionary views.



Typical requirements may include access to:



V$INSTANCE

V$DATABASE

V$SESSION

V$SQL

V$ASM\_DISK

V$ASM\_DISKGROUP

V$RECOVERY\_FILE\_DEST

DBA\_USERS

DBA\_OBJECTS

DBA\_DATA\_FILES

DBA\_FREE\_SPACE

DBA\_TEMP\_FILES

UNIFIED\_AUDIT\_TRAIL



Run scripts with appropriate DBA privileges.





🤝 Contributions



Suggestions, improvements, additional DBA scripts, and troubleshooting utilities are welcome.



If you find an issue or have an improvement, feel free to open an Issue or submit a Pull Request.



👨‍💻 Author



Manik Challa



Oracle Database Administrator | Database Troubleshooting | Performance | Exadata | Oracle Security



⭐ If you find this toolkit useful, consider starring the repository.



Built for DBAs. One script at a time. 🚀







