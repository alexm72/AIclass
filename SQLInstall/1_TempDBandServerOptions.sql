USE [master]
GO
DECLARE @CPUCount INT,
		@TempDBFilesToCREATE INT,
        @FileCount INT,
        @LogicalName SYSNAME,
        @FileName NVARCHAR(520),
        @PhysicalName NVARCHAR(520),
        @Size INT,
        @MaxSize INT,
        @Growth INT,
        @AlterCommand NVARCHAR(MAX),
		@TempDBDriveSize INT,
		@TempDBFileSize INT,
		@TempDBLogSize INT

--Get total drive size of F drive
SELECT @TempDBDriveSize = size_in_mb
FROM
	(SELECT DISTINCT(volume_mount_point), total_bytes/1048576 AS size_in_mb
	FROM sys.master_files AS f 
	CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id)
	GROUP BY volume_mount_point, total_bytes/1048576, available_bytes/1048576) a
WHERE volume_mount_point LIKE 'F%'

--SELECT @TempDBDriveSize
PRINT 'F drive capacity is ' + CONVERT(VARCHAR, @TempDBDriveSize) + 'MB'

--Get number of logical processors on the server
SELECT @CPUCount = cpu_count FROM sys.dm_os_sys_info

--Set maximum number of TempDB files to 8 IF more than 8 CPUs are found
SELECT @TempDBFilesToCREATE = CASE WHEN @CPUCount <= 8 THEN @CPUCount ELSE 8 END

PRINT CONVERT(VARCHAR, @CPUCount) + ' logical processors found; ' + CONVERT(VARCHAR, @TempDBFilesToCREATE) + ' TempDB files will be created'

--Calculate size of each TempDB file to USE 84% of the total drive capacity
SELECT @TempDBFileSize = FLOOR((@TempDBDriveSize * .84 / @TempDBFilesToCREATE)/16)*16

--Calculate initial TempDB log size to be 10% of total TempDB data file size
SELECT @TempDBLogSize = FLOOR((@TempDBDriveSize * .84 * .1)/16)*16

PRINT 'TempDB log file will be ' + CONVERT(VARCHAR, @TempDBLogSize) + 'MB in size'
PRINT 'Each TempDB file will be ' + CONVERT(VARCHAR, @TempDBFileSize) + 'MB in size'

--Size the TempDB log file
SELECT @AlterCommand = 'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N''templog'', SIZE = ' + CAST (@TempDBLogSize AS NVARCHAR) + 'MB , FILEGROWTH = 256MB )'
EXEC sp_executesql @AlterCommand

--Get the file names
SELECT  @PhysicalName = physical_name,
        @Size = @TempDBFileSize, 
        @MaxSize = @TempDBFileSize,
        @Growth =  0
FROM    tempdb.sys.database_files
WHERE   name = 'tempdev'

--Get current number of TempDB files
SELECT  @FileCount = COUNT(*)
FROM    tempdb.sys.database_files
WHERE   type_desc = 'ROWS'

--Size the default TempDB file
SELECT @AlterCommand = 'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N''tempdev'', SIZE = ' + CAST(@Size AS NVARCHAR) + 'MB, MAXSIZE = ' + CAST(@MaxSize AS NVARCHAR) + 'MB, FILEGROWTH = ' + CAST(@Growth AS NVARCHAR) + 'MB )'
--SELECT @AlterCommand
EXEC sp_executesql @AlterCommand

--Prepare the alter command and execute it per new TempDB file
IF @FileCount >= @TempDBFilesToCREATE PRINT 'Number of TempDB files already meets or exceeds the number of CPUs'
WHILE @FileCount < @TempDBFilesToCREATE -- Add * 0.25 here to add 1 file for every 4 cpus, * .5 for every 2 etc.
 BEGIN
    SELECT @LogicalName = 'tempdev' + CAST(@FileCount+1 AS NVARCHAR)
    SELECT @FileName = REPLACE(@PhysicalName, 'tempdb.mdf', @LogicalName + '.ndf')
    SELECT @AlterCommand = 'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''' + @LogicalName + ''', FILENAME = N''' +  @FileName + ''', SIZE = ' + CAST(@Size AS NVARCHAR) + 'MB, MAXSIZE = ' + CAST(@MaxSize AS NVARCHAR) + 'MB, FILEGROWTH = ' + CAST(@Growth AS NVARCHAR) + 'MB )'
    --SELECT @AlterCommand
   EXEC sp_executesql @AlterCommand
    SELECT @FileCount = @FileCount + 1
 END
GO

--Set the model DB to 256MB for data and log files
IF (SELECT (size*8)/1024 FROM sys.master_files WHERE name = 'modeldev') < 256
BEGIN
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', SIZE = 256MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB )
END
GO
IF (SELECT (size*8)/1024 FROM sys.master_files WHERE name = 'modellog') < 256
BEGIN
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', SIZE = 256MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB )
END
GO

--Set the memory allocated to SQL Server to 80% of total server memory
sp_configure 'show advanced options', 1;
GO
RECONFIGURE;
GO
DECLARE @MemoryMB INT,
		@Command NVARCHAR(MAX)
SELECT @MemoryMB = (total_physical_memory_kb/1024)*.8 FROM sys.dm_os_sys_memory
SELECT @Command = 'sp_configure ''max server memory'', ' + CONVERT(NVARCHAR, @MemoryMB)
EXEC sp_executesql @Command
SELECT @Command = 'sp_configure ''min server memory'', ' + CONVERT(NVARCHAR, @MemoryMB)
EXEC sp_executesql @Command
GO
RECONFIGURE;
GO

EXEC sys.sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;

EXEC sys.sp_configure N'cost threshold for parallelism', N'50'
RECONFIGURE WITH OVERRIDE;

EXEC sys.sp_configure N'backup compression default', N'1'
RECONFIGURE WITH OVERRIDE;

EXEC sys.sp_configure N'text repl size (B)', N'3145728'
RECONFIGURE WITH OVERRIDE;

EXEC sys.sp_configure 'max worker threads', 2048;
RECONFIGURE WITH OVERRIDE;

EXEC sys.sp_configure'user connections', 3000;
RECONFIGURE WITH OVERRIDE;

EXEC sys.sp_configure 'remote admin connections', 1;
RECONFIGURE WITH OVERRIDE;

EXEC sys.sp_configure 'Database Mail XPs', 1;
RECONFIGURE WITH OVERRIDE;

EXEC sys.sp_configure 'network packet size (B)', 8192; 
RECONFIGURE WITH OVERRIDE;
GO

--CREATE standard logins
ALTER LOGIN [sa] WITH PASSWORD=N'3&F4&Tf*IGPbapQ2'
GO

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'CORP\ACL_SQL_DBS_ADM')
CREATE LOGIN [CORP\ACL_SQL_DBS_ADM] FROM WINDOWS WITH DEFAULT_DATABASE = tempdb;
ALTER LOGIN [CORP\ACL_SQL_DBS_ADM] WITH DEFAULT_DATABASE = tempdb;

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'CORP\DBAProxy_svc')
CREATE LOGIN [CORP\DBAProxy_svc] FROM WINDOWS WITH DEFAULT_DATABASE = tempdb;

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'CORP\SS_NetworkSupport')
CREATE LOGIN [CORP\SS_NetworkSupport] FROM WINDOWS WITH DEFAULT_DATABASE = tempdb;

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'CORP\SQLdmSvc')
CREATE LOGIN [CORP\SQLdmSvc] FROM WINDOWS WITH DEFAULT_DATABASE=[tempdb];

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'CORP\ss_metacrawler')
CREATE LOGIN [CORP\ss_metacrawler] FROM WINDOWS WITH DEFAULT_DATABASE = master;

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'CORP\SVC_SPLUNK_DB_ACCESS')
CREATE LOGIN [CORP\SVC_SPLUNK_DB_ACCESS] FROM WINDOWS WITH DEFAULT_DATABASE = master;

GRANT CONNECT SQL, VIEW ANY DEFINITION TO [CORP\ss_metacrawler];

------------------------------------------------------------------------------------------------------------------------
-- Fixed server roles
------------------------------------------------------------------------------------------------------------------------

EXEC sp_addsrvrolemember [CORP\ACL_SQL_DBS_ADM], [sysadmin];
EXEC sp_addsrvrolemember [CORP\DBAProxy_svc], [sysadmin];
EXEC sp_addsrvrolemember [CORP\SQLdmSvc], [sysadmin];
EXEC sp_addsrvrolemember [CORP\SS_BackupOperators], [processadmin];
EXEC sp_addsrvrolemember [CORP\SS_NetworkSupport], [processadmin];
ALTER SERVER ROLE [sysadmin] ADD MEMBER [NT AUTHORITY\SYSTEM]
GO
--EXEC sp_addsrvrolemember [NT AUTHORITY\SYSTEM], [sysadmin];--is this for comvault only IF so sys admin?

------------------------------------------------------------------------------------------------------------------------
-- Server level permissions
------------------------------------------------------------------------------------------------------------------------
USE [master];

GRANT VIEW ANY DATABASE TO [CORP\SS_NetworkSupport];
GRANT VIEW ANY DEFINITION TO [CORP\SS_NetworkSupport];

GRANT VIEW ANY DATABASE TO [NT AUTHORITY\SYSTEM];
GRANT VIEW ANY DEFINITION TO [NT AUTHORITY\SYSTEM];

GRANT VIEW ANY DATABASE TO [CORP\SS_BackupOperators];
GRANT VIEW ANY DEFINITION TO [CORP\SS_BackupOperators];

GRANT VIEW ANY DATABASE TO [CORP\SVC_SPLUNK_DB_ACCESS];
GRANT VIEW ANY DEFINITION TO [CORP\SVC_SPLUNK_DB_ACCESS];
GRANT VIEW SERVER STATE TO [CORP\SVC_SPLUNK_DB_ACCESS];

------------------------------------------------------------------------------------------------------------------------
-- Fixed database roles
------------------------------------------------------------------------------------------------------------------------

USE model

IF EXISTS (SELECT name FROM sys.database_principals WHERE name = 'CORP\SS_BackupOperators')
	DROP USER [CORP\SS_BackupOperators];

CREATE USER [CORP\SS_BackupOperators] for login [CORP\SS_BackupOperators];
EXEC sp_addrolemember 'db_backupoperator', 'CORP\SS_BackupOperators';

IF EXISTS (SELECT name FROM sys.database_principals WHERE name = 'CORP\SS_NetworkSupport')
	DROP USER [CORP\SS_NetworkSupport];

CREATE USER [CORP\SS_NetworkSupport] for login [CORP\SS_NetworkSupport];
EXEC sp_addrolemember 'db_backupoperator', 'CORP\SS_NetworkSupport';

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE type_desc = 'DATABASE_ROLE' AND name = 'url_ProcExecutor')
			CREATE ROLE [url_ProcExecutor];
GRANT EXECUTE TO [url_ProcExecutor]; 

--EXEC master..sp_addsrvrolemember 
--	@loginame = N'***', 
--	@rolename = N'sysadmin'
GO

USE tempdb
GO