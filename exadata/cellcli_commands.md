\# Exadata CellCLI Commands 🚀



A practical \*\*CellCLI quick-reference\*\* for Oracle Exadata storage-cell monitoring and troubleshooting.



Run CellCLI commands on the appropriate Exadata storage cell and use appropriate privileges. Avoid making configuration changes unless the impact and required change procedure are understood.



CellCLI (Cell Command Line Interface) is used to configure, manage, and monitor individual Oracle Exadata Storage Servers (Cells).



\----------------------------------------------------------------

🚀 Basic Usage



\# Connect to the Exadata cell server (as root, celladmin, or cellmonitor)

ssh celladmin@exadatacel01



\# Start the interactive CellCLI session

cellcli



\# Run a single command directly from the Linux shell

cellcli -e "list cell"



\# Execute across multiple cell nodes at once using dcli

dcli -g cell\_group cellcli -e "list griddisk"



\----------------------------------------------------------------



📊 Cell Server Status \& Monitoring

\-- View basic cell status and service health (CELLSRV, MS, RS)

list cell



\-- View complete cell details

list cell detail



\-- Display selective cell attributes

list cell attributes name, ipAddress0, status



\-- Monitor active cell alerts

list alerthistory where state = 'active'

list alerthistory detail



\----------------------------------------------------------------



💽 Disk \& Hardware Diagnostics

Physical Disks

\-- List physical disk statuses

list physicaldisk



\-- Check for failed or degraded disks

list physicaldisk where status != 'normal'



\-- Display detailed disk info (ID, type, error counts)

list physicaldisk attributes name, diskType, errHardReadCount, errHardWriteCount



LUNs \& Cell Disks

\-- List LUN attributes

list lun attributes name, cellDisk, raidLevel, status



\-- List cell disks and space status

list celldisk

list celldisk attributes name, size, freeSpace where freeSpace > 0



Grid Disks (ASM Disks)

\-- List all grid disks

list griddisk



\-- Filter active or inactive grid disks

list griddisk where status != 'active'



\-- View size and offset details for ASM disk groups

list griddisk attributes name, size, offset, celldisk



\----------------------------------------------------------------



⚡ Flash Cache \& Flash Log

\-- Check Flash Cache status and size

list flashcache detail



\-- View Flash Cache usage metrics

list metriccurrent where objectType = 'FLASHCACHE'



\-- Check Flash Log status

list flashlog detail



\----------------------------------------------------------------



📈 Performance \& Metrics

\-- Real-time metrics for cell CPU and run queue

list metriccurrent cl\_cput, cl\_runq detail



\-- Disk I/O metrics

list metriccurrent where objectType = 'GRIDDISK' and name like 'GD\_IO.\*'



\-- Historical CPU metrics over time

list metrichistory where objectType = 'CELL' and name = 'CL\_CPUT'



\----------------------------------------------------------------



⚙️ Administrative Actions

\-- Restart management server (MS)

alter cell restart services ms



\-- Shutdown cell services (CELLSRV, MS, RS)

alter cell shutdown services all



\----------------------------------------------------------------

Grid Disk \& Cache Modifications

\-- Inactivate grid disks (before maintenance or disk replacement)

alter griddisk GD\_01\_cell01 inactive



\-- Activate grid disks

alter griddisk GD\_01\_cell01 active



\-- Create Flash Cache across all available flash disks

create flashcache all



\----------------------------------------------------------------



💡 Common Diagnostic One-Liners

\# Check across all cells for non-normal physical disks via dcli

dcli -g cell\_group "cellcli -e 'list physicaldisk where status != \\"normal\\"'"



\# Check active alerts on all storage cells

dcli -g cell\_group "cellcli -e 'list alerthistory where state = \\"active\\"'"



&#x09;









