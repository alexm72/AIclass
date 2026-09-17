-- =============================================
-- SCRIPT: 3_StandardJobs (Environment-Aware)
-- VERSION: v1
-- CREATED: 2026-05-15
-- PURPOSE: Create standard SQL Agent maintenance jobs during new server
--          "priming"; schedules vary based on environment (PROD vs LOWER).
--          LOWER ENV SERVER changes :
--             * Job 02 (Integrity Check User DBs) -> 1st & 3rd Sunday 9PM
--             * Job 03 (IndexOptimize)            -> Every Friday 9PM
--             * Job 08 (Shrink Tlog)              -> Every Sunday 10PM
--          PROD ENV SERVER schedule is unchanged from the prior version of this script.
-- SERVER: Any newly-built SQL Server during build/priming
-- DATABASE: SQLTools (must already exist on the target server)
-- IMPACT: WILL MAKE CHANGES - creates SQL Agent jobs, steps, and schedules
-- TARGET VERSION: SQL Server 2022+
-- HOW TO RUN: 1) Open in SSMS connected to the new server.
--             2) Set @Environment below to either 'PROD' or 'LOWER'.
--             3) Execute. Script aborts with an error if @Environment is blank/invalid.
-- =============================================
--This script creates the standard jobs as part of a new server build
--8/1/2023 Renee':  Updated index optimize to include options to update statistics
--5/15/2026 Plamen: Added @Environment parameter (PROD / LOWER) per Hemanth's request
--                  to apply different schedules to lower environments.

USE SQLTools

SET NOCOUNT ON

-- =============================================
-- NEW: Environment selector
--   Must be 'PROD' or 'LOWER' (case-insensitive, whitespace trimmed).
--   If blank or invalid, the script aborts BEFORE creating any jobs.
-- =============================================
DECLARE @Environment NVARCHAR(20)

SET @Environment = N'' -- <<<<HERE SET TO 'PROD' OR 'LOWER' BEFORE RUNNING >>>>

SET @Environment = UPPER(LTRIM(RTRIM(ISNULL(@Environment, N''))))

IF @Environment NOT IN (N'PROD', N'LOWER')
BEGIN
    RAISERROR(
        '@Environment must be set to either ''PROD'' or ''LOWER'' before running this script. Aborting - NO jobs were created.',
        16, 1)
    RETURN
END

PRINT '===================================================='
PRINT 'Creating standard maintenance jobs for environment: ' + @Environment
PRINT '===================================================='
-- =============================================

DECLARE @DatabaseName NVARCHAR(MAX)
DECLARE @OutputFileDirectory NVARCHAR(MAX)
DECLARE @LogToTable NVARCHAR(MAX)
DECLARE @Version NUMERIC(18,10)

DECLARE @JobCategory NVARCHAR(MAX)
DECLARE @JobName01 VARCHAR(MAX)
DECLARE @JobName02 VARCHAR(MAX)
DECLARE @JobName03 VARCHAR(MAX)
DECLARE @JobName04 VARCHAR(MAX)
DECLARE @JobName05 VARCHAR(MAX)
DECLARE @JobName06 VARCHAR(MAX)
DECLARE @JobName07 VARCHAR(MAX)
DECLARE @JobName08 VARCHAR(MAX)
DECLARE @JobName09 VARCHAR(MAX)

DECLARE @JobCommand01 VARCHAR(MAX)
DECLARE @JobCommand02 VARCHAR(MAX)
DECLARE @JobCommand03 VARCHAR(MAX)
DECLARE @JobCommand04 VARCHAR(MAX)
DECLARE @JobCommand05 VARCHAR(MAX)
DECLARE @JobCommand06 VARCHAR(MAX)
DECLARE @JobCommand07 VARCHAR(MAX)
DECLARE @JobCommand08 VARCHAR(MAX)
DECLARE @JobCommand09 VARCHAR(MAX)

DECLARE @OutputFile01 NVARCHAR(MAX)
DECLARE @OutputFile02 NVARCHAR(MAX)
DECLARE @OutputFile03 NVARCHAR(MAX)
DECLARE @OutputFile04 NVARCHAR(MAX)
DECLARE @OutputFile05 NVARCHAR(MAX)

DECLARE @TokenServer NVARCHAR(MAX)
DECLARE @TokenJobID NVARCHAR(MAX)
DECLARE @TokenStepID NVARCHAR(MAX)
DECLARE @TokenDate NVARCHAR(MAX)
DECLARE @TokenTime NVARCHAR(MAX)
DECLARE @TokenLogDirectory NVARCHAR(MAX)

SET @DatabaseName = DB_NAME(DB_ID())
SET @OutputFileDirectory = NULL         -- Specify the output file directory. If no directory is specified, then the SQL Server error log directory is used.
SET @LogToTable          = 'Y'          -- Log commands to a table.
SET @TokenServer = '$' + '(ESCAPE_SQUOTE(SRVR))'
SET @TokenJobID = '$' + '(ESCAPE_SQUOTE(JOBID))'
SET @TokenStepID = '$' + '(ESCAPE_SQUOTE(STEPID))'
SET @TokenDate = '$' + '(ESCAPE_SQUOTE(STRTDT))'
SET @TokenTime = '$' + '(ESCAPE_SQUOTE(STRTTM))'
SET @TokenLogDirectory = '$' + '(ESCAPE_SQUOTE(SQLLOGDIR))'
SET @JobCategory = 'Database Maintenance'
SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX)))),'.','') AS numeric(18,10))

BEGIN
  IF @Version >= 11
  BEGIN
    SELECT @OutputFileDirectory = [path]
    FROM sys.dm_os_server_diagnostics_log_configurations
  END
  ELSE
  BEGIN
    SELECT @OutputFileDirectory = LEFT(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(MAX)),LEN(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(MAX))) - CHARINDEX('\',REVERSE(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(MAX)))))
  END
END

SET @JobName01 = 'DBA - DatabaseIntegrityCheck - Sys DBs'
SET @JobCommand01 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''SYSTEM_DATABASES''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
SET @OutputFile01 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'DatabaseIntegrityCheck_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile01) > 200 SET @OutputFile01 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile01) > 200 SET @OutputFile01 = NULL

SET @JobName02 = 'DBA - DatabaseIntegrityCheck - User DBs'
SET @JobCommand02 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''USER_DATABASES''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
SET @OutputFile02 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'DatabaseIntegrityCheck_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile02) > 200 SET @OutputFile02 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile02) > 200 SET @OutputFile02 = NULL

SET @JobName03 = 'DBA - IndexOptimize - User DBs'
--SET @JobCommand03 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[IndexOptimize] @Databases = ''USER_DATABASES''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
SET @JobCommand03 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[IndexOptimize] @Databases = ''USER_DATABASES'',@UpdateStatistics = ''ALL'', @OnlyModifiedStatistics=''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
SET @OutputFile03 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'IndexOptimize_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile03) > 200 SET @OutputFile03 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile03) > 200 SET @OutputFile03 = NULL

SET @JobName04 = 'DBA - Output File Cleanup'
SET @JobCommand04 = 'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '" /m *_*_*_*.txt /d -30 2^>^&1'') do if EXIST "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '"\%v echo del "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '"\%v& del "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '"\%v"'
SET @OutputFile04 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'OutputFileCleanup_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile04) > 200 SET @OutputFile04 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile04) > 200 SET @OutputFile04 = NULL

SET @JobName05 = 'DBA - CommandLog Table Cleanup'
SET @JobCommand05 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "DELETE FROM [dbo].[CommandLog] WHERE StartTime < DATEADD(dd,-30,GETDATE())" -b'
SET @OutputFile05 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'CommandLogCleanup_' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile05) > 200 SET @OutputFile05 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFile05) > 200 SET @OutputFile05 = NULL

SET @JobName06 = 'DBA - Track Connections'
SET @JobCommand06 = 'EXEC '+ @DatabaseName + '.dbo.up_TrackConnections'

SET @JobName07 = 'DBA - Recycle Logs'
SET @JobCommand07 = 'IF EXISTS (SELECT  [name] FROM master.sys.sysobjects where type = ''p''and name  like  ''sp_cycle_errorlog'')
	exec sp_cycle_errorlog'
	
SET @JobName08 = 'DBA - Shrink Tlog'
SET @JobCommand08 = 'EXEC '+ @DatabaseName + '.dbo.usp_DBA_ShrinkTlog'

-- =============================================
-- Job 01 - DBA - DatabaseIntegrityCheck - Sys DBs
-- Schedule: Daily 6PM  (SAME for PROD and LOWER)
-- =============================================
EXECUTE msdb.dbo.sp_add_job @job_name = @JobName01, @category_name = @JobCategory, @owner_login_name = 'sa'
EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName01, @step_name = @JobName01, @subsystem = 'CMDEXEC', @command = @JobCommand01, @output_file_name = @OutputFile01
EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName01
EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName01, @name = N'DBA - Daily 6PM', @enabled = 1, @freq_type = 4, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_start_date = 20100909, @active_end_date = 99991231, @active_start_time = 180000, @active_end_time = 235959

-- =============================================
-- Job 02 - DBA - DatabaseIntegrityCheck - User DBs
-- Schedule:
--   PROD  -> Friday 9PM weekly (original)
--   LOWER -> 1st & 3rd Sunday 9PM monthly (two schedules)
-- =============================================
EXECUTE msdb.dbo.sp_add_job @job_name = @JobName02, @category_name = @JobCategory, @owner_login_name = 'sa'
EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName02, @step_name = @JobName02, @subsystem = 'CMDEXEC', @command = @JobCommand02, @output_file_name = @OutputFile02
EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName02

IF @Environment = N'PROD'
BEGIN
    EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName02, @name = N'DBA - Friday 9PM', @enabled = 1, @freq_type = 8, @freq_interval = 32, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20100909, @active_end_date = 99991231, @active_start_time = 210000, @active_end_time = 235959
END
ELSE  -- LOWER
BEGIN
    -- LOWER: 1st Sunday 9PM (monthly relative)
    EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName02, @name = N'DBA - First Sunday 9PM', @enabled = 1, @freq_type = 32, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 1, @freq_recurrence_factor = 1, @active_start_date = 20260515, @active_end_date = 99991231, @active_start_time = 210000, @active_end_time = 235959
    -- LOWER: 3rd Sunday 9PM (monthly relative)
    EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName02, @name = N'DBA - Third Sunday 9PM', @enabled = 1, @freq_type = 32, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 4, @freq_recurrence_factor = 1, @active_start_date = 20260515, @active_end_date = 99991231, @active_start_time = 210000, @active_end_time = 235959
END

-- =============================================
-- Job 03 - DBA - IndexOptimize - User DBs
-- Schedule:
--   PROD  -> Saturday 9PM weekly (original)
--   LOWER -> Friday 9PM weekly (new)
-- =============================================
EXECUTE msdb.dbo.sp_add_job @job_name = @JobName03, @category_name = @JobCategory, @owner_login_name = 'sa'
EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName03, @step_name = @JobName03, @subsystem = 'CMDEXEC', @command = @JobCommand03, @output_file_name = @OutputFile03
EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName03

IF @Environment = N'PROD'
BEGIN
    EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName03, @name = N'DBA - Saturday 9PM', @enabled = 1, @freq_type = 8, @freq_interval = 64, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20100909, @active_end_date = 99991231, @active_start_time = 210000, @active_end_time = 235959
END
ELSE  -- LOWER
BEGIN
    EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName03, @name = N'DBA - Friday 9PM', @enabled = 1, @freq_type = 8, @freq_interval = 32, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20260515, @active_end_date = 99991231, @active_start_time = 210000, @active_end_time = 235959
END

-- =============================================
-- Job 04 - DBA - Output File Cleanup
-- Schedule: Friday 5AM  (SAME for PROD and LOWER)
-- =============================================
EXECUTE msdb.dbo.sp_add_job @job_name = @JobName04, @category_name = @JobCategory, @owner_login_name = 'sa'
EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName04, @step_name = @JobName04, @subsystem = 'CMDEXEC', @command = @JobCommand04, @output_file_name = @OutputFile04
EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName04
EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName04, @name = N'DBA - Friday 5AM', @enabled = 1, @freq_type = 8, @freq_interval = 32, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20100909, @active_end_date = 99991231, @active_start_time = 50000, @active_end_time = 235959


-- =============================================
-- Job 05 - DBA - CommandLog Table Cleanup
-- Schedule: Friday 2AM  (SAME for PROD and LOWER)
-- =============================================
EXECUTE msdb.dbo.sp_add_job @job_name = @JobName05, @category_name = @JobCategory, @owner_login_name = 'sa'
EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName05, @step_name = @JobName05, @subsystem = 'CMDEXEC', @command = @JobCommand05, @output_file_name = @OutputFile05
EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName05
EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName05, @name = N'DBA - Friday 2AM', @enabled = 1, @freq_type = 8, @freq_interval = 32, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20110817, @active_end_date = 99991231, @active_start_time = 20000, @active_end_time = 235959


-- =============================================
-- Job 06 - DBA - Track Connections
-- Schedule: Every 10 seconds  (SAME for PROD and LOWER)
-- =============================================
EXECUTE msdb.dbo.sp_add_job @job_name = @JobName06, @category_name = @JobCategory, @owner_login_name = 'sa'
EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName06, @step_name = @JobName06, @command = @JobCommand06, @database_name = @DatabaseName
EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName06
EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName06, @name = N'DBA - Every 10 Seconds', @enabled = 1, @freq_type = 4, @freq_interval = 1, @freq_subday_type = 2, @freq_subday_interval = 10, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_start_date = 20130101, @active_end_date = 99991231, @active_start_time = 0, @active_end_time = 235959

-- =============================================
-- Job 07 - DBA - Recycle Logs
-- Schedule: 3rd Sunday 9PM  (SAME for PROD and LOWER)
-- NOTE: in LOWER this 3rd-Sunday slot overlaps Job 02 (User DB Integrity).
--       sp_cycle_errorlog is sub-second so impact is negligible; left as-is.
-- =============================================
EXECUTE msdb.dbo.sp_add_job @job_name = @JobName07, @category_name = @JobCategory, @owner_login_name = 'sa'
EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName07, @step_name = @JobName07, @command = @JobCommand07, @database_name = 'master'
EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName07
EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName07, @name = N'DBA - Third Sunday 9PM', @enabled = 1, @freq_type = 32, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 4, @freq_recurrence_factor = 1, @active_start_date = 20150125, @active_end_date = 99991231, @active_start_time = 210000, @active_end_time = 235959

-- =============================================
-- Job 08 - DBA - Shrink Tlog
-- Schedule:
--   PROD  -> Sunday 9PM weekly (original)
--   LOWER -> Sunday 10PM weekly (new, to avoid 9PM collision with Integrity Check)
-- =============================================
EXECUTE msdb.dbo.sp_add_job @job_name = @JobName08, @category_name = @JobCategory, @owner_login_name = 'sa'
EXECUTE msdb.dbo.sp_add_jobstep @job_name = @JobName08, @step_name = @JobName08, @command = @JobCommand08, @database_name = 'master'
EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName08

IF @Environment = N'PROD'
BEGIN
    EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName08, @name = N'DBA - Sunday 9PM', @enabled = 1, @freq_type = 8, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20150125, @active_end_date = 99991231, @active_start_time = 210000, @active_end_time = 235959
END
ELSE  -- LOWER
BEGIN
    EXECUTE msdb.dbo.sp_add_jobschedule @job_name = @JobName08, @name = N'DBA - Sunday 10PM', @enabled = 1, @freq_type = 8, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20260515, @active_end_date = 99991231, @active_start_time = 220000, @active_end_time = 235959
END

PRINT '===================================================='
PRINT 'Standard maintenance jobs created successfully for environment: ' + @Environment
PRINT '===================================================='