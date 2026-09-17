PRINT '*** DBMail'
GO

------------------------------------------------------------------------------------------------------------------------
-- Configuration script for SQL Support
------------------------------------------------------------------------------------------------------------------------

-- Create a Database Mail account
exec msdb.dbo.sysmail_add_account_sp
    @account_name = 'SQL Alert System Account',
    @description = 'Mail account for administrative tasks.',
    @email_address = 'SQLAlertSystem@azblue.com',
    @replyto_address = '',
    @display_name = '',
    @mailserver_name = 'appmail.azblue.com'; -- ipmail.bcbsaz.com

-- Create a Database Mail profile
exec msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'SQL Alert System Profile',
    @description = 'Mail profile for administrative tasks.';

-- Add the account to the profile
exec msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = 'SQL Alert System Profile',
    @account_name = 'SQL Alert System Account',
    @sequence_number =1;

PRINT '*** Operators'
GO

use [msdb];

-----------------------------------------------------------------------------------------------
-- Add an operator to receive notification
-----------------------------------------------------------------------------------------------
-- SQL Support
if  exists (select name from msdb.dbo.sysoperators where name = N'SQL Support')
	exec msdb.dbo.sp_delete_operator @name = N'SQL Support';

exec msdb.dbo.sp_add_operator 
	@name = N'DBATeam', 
	@enabled = 1, 
	@email_address = N'DBATeam@azblue.com';

use [msdb];

------------------------------------------------------------------------------------------------------------------------
-- Alerts based on severity levels 17 through 25 events
------------------------------------------------------------------------------------------------------------------------
if  exists (select name from msdb.dbo.sysalerts where name = N'Sev.17: Insufficient Resources')
	exec msdb.dbo.sp_delete_alert @name = N'Sev.17: Insufficient Resources'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Sev.17: Insufficient Resources', 
		@severity = 17,
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Sev.18: Internal Error')
	exec msdb.dbo.sp_delete_alert @name = N'Sev.18: Internal Error'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Sev.18: Internal Error', 
		@severity = 18,
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Sev.19: Error in Resource')
	exec msdb.dbo.sp_delete_alert @name = N'Sev.19: Error in Resource'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Sev.19: Error in Resource', 
		@severity = 19,
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Sev.20: Error in Current Process')
	exec msdb.dbo.sp_delete_alert @name = N'Sev.20: Error in Current Process'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Sev.20: Error in Current Process', 
		@severity = 20,
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Sev.21: Error in Database Processes')
	exec msdb.dbo.sp_delete_alert @name = N'Sev.21: Error in Database Processes'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Sev.21: Error in Database Processes', 
		@severity = 21,
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Sev.22: Table Integrity Suspect')
	exec msdb.dbo.sp_delete_alert @name = N'Sev.22: Table Integrity Suspect'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Sev.22: Table Integrity Suspect', 
		@severity = 22,
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Sev.23: Database Integrity Suspect')
	exec msdb.dbo.sp_delete_alert @name = N'Sev.23: Database Integrity Suspect'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Sev.23: Database Integrity Suspect', 
		@severity = 23,
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Sev.24: Hardware Error')
	exec msdb.dbo.sp_delete_alert @name = N'Sev.24: Hardware Error'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Sev.24: Hardware Error', 
		@severity = 24,
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Sev.25: Fatal Error')
	exec msdb.dbo.sp_delete_alert @name = N'Sev.25: Fatal Error'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Sev.25: Fatal Error', 
		@severity = 25,
		@enabled = 1, 
		@delay_between_responses = 300;
end

------------------------------------------------------------------------------------------------------------------------
-- Alerts based on performance condition events
------------------------------------------------------------------------------------------------------------------------
declare 
	@instance nvarchar(32),
	@performance_condition nvarchar(512);
	
if charindex('\', @@servername) = 0
	set @instance = N'SQLServer'
else
	set @instance = N'MSSQL$' + substring(@@servername, charindex ('\', @@servername) + 1, len(@@servername));

if  exists (select name from msdb.dbo.sysalerts where name = N'Perf: Number of Deadlocks/sec')
	exec msdb.dbo.sp_delete_alert @name = N'Perf: Number of Deadlocks/sec'
begin
	set @performance_condition = @instance + N':Locks|Number of Deadlocks/sec|Database|>|0.99';
	
	exec msdb.dbo.sp_add_alert 
		@name = N'Perf: Number of Deadlocks/sec', 
		@performance_condition = @performance_condition, 
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Perf: Lock Timeouts (timeout > 0)/sec')
	exec msdb.dbo.sp_delete_alert @name = N'Perf: Lock Timeouts (timeout > 0)/sec'
begin
	set @performance_condition = @instance + N':Locks|Lock Timeouts (timeout > 0)/sec|Database|>|0.99';

	exec msdb.dbo.sp_add_alert 
		@name = N'Perf: Lock Timeouts (timeout > 0)/sec', 
		@performance_condition = @performance_condition, 
		@enabled = 1, 
		@delay_between_responses = 300;
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Perf: Batch Requests/sec')
	exec msdb.dbo.sp_delete_alert @name = N'Perf: Batch Requests/sec'
begin
	set @performance_condition = @instance + N':SQL Statistics|Batch Requests/sec||>|30000';

	exec msdb.dbo.sp_add_alert 
		@name = N'Perf: Batch Requests/sec', 
		@performance_condition = @performance_condition, 
		@enabled = 1, 
		@delay_between_responses = 300;
end

------------------------------------------------------------------------------------------------------------------------
-- Alerts based on specific error codes
------------------------------------------------------------------------------------------------------------------------
if  exists (select name from msdb.dbo.sysalerts where name = N'Error 17803: Memory Allocation Failure')
	exec msdb.dbo.sp_delete_alert @name = N'Error 17803: Memory Allocation Failure'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Error 17803: Memory Allocation Failure', 
		@message_id = 17803, 
		@enabled = 1, 
		@delay_between_responses = 300
		--@job_name = N'Error: Force Restart';
end

if  exists (select name from msdb.dbo.sysalerts where name = N'Backup: Failure on Backup Device')
	exec msdb.dbo.sp_delete_alert @name = N'Backup: Failure on Backup Device'
begin
	exec msdb.dbo.sp_add_alert 
		@name = N'Backup: Failure on Backup Device', 
		@message_id = 18210, 
		@enabled = 1, 
		@delay_between_responses = 300;
end

PRINT '*** notifications'
GO

use [msdb];

------------------------------------------------------------------------------------------------------------------------
-- Notification based on severity levels 17 through 25 events
------------------------------------------------------------------------------------------------------------------------
-- SQL Support
begin
	exec msdb.dbo.sp_add_notification
		@alert_name = N'Sev.17: Insufficient Resources',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Sev.18: Internal Error',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Sev.19: Error in Resource',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Sev.20: Error in Current Process',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Sev.21: Error in Database Processes',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Sev.22: Table Integrity Suspect',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Sev.23: Database Integrity Suspect',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Sev.24: Hardware Error',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Sev.25: Fatal Error',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email
end

------------------------------------------------------------------------------------------------------------------------
-- Notification based on performance condition events
------------------------------------------------------------------------------------------------------------------------
-- SQL Support
begin
	exec msdb.dbo.sp_add_notification
		@alert_name = N'Perf: Number of Deadlocks/sec',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Perf: Lock Timeouts (timeout > 0)/sec',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Perf: Batch Requests/sec',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email
end

------------------------------------------------------------------------------------------------------------------------
-- Alerts based on specific error codes
------------------------------------------------------------------------------------------------------------------------
-- SQL Support
begin
	exec msdb.dbo.sp_add_notification
		@alert_name = N'Error 17803: Memory Allocation Failure',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email

	exec msdb.dbo.sp_add_notification
		@alert_name = N'Backup: Failure on Backup Device',
		@operator_name = N'DBATeam',
		@notification_method = 1; -- Email
END

--Update sysoperators to include Operations for Prod servers
DECLARE @ServerName VARCHAR(20)
SELECT @ServerName = @@SERVERNAME

IF @ServerName LIKE 'MP%'
	UPDATE msdb..sysoperators 
	SET name = 'DBATeam & Operations', 
	email_address = 'DBATeam@azblue.com;OperationsInbox@azblue.com' 
	WHERE name = 'DBATeam' 
GO

-------------------------------------------------------------------------------------------------------------------
-- Update DBA Managed SQL Agent Jobs to send email notification on failures
-------------------------------------------------------------------------------------------------------------------
USE [msdb]
GO

--add notifications for failure to all jobs
DECLARE @QuotedIdentifier char(1); SET @QuotedIdentifier = '' -- use '''' for single quote
DECLARE @ListDelimeter char(1); SET @ListDelimeter = ';'
DECLARE @CSVlist varchar(max) --use varchar(8000) for SQL Server 2000
 
--no event log, email on failure
SELECT	@CSVlist = COALESCE(@CSVlist + @ListDelimeter, '') + @QuotedIdentifier + 
'
EXEC msdb.dbo.sp_update_job @job_id=N'''
+ convert(varchar(max),[job_id]) +
''', 
		@notify_level_eventlog=0,
		@notify_level_email=2, 
		@notify_email_operator_name=N''DBATeam''' -- Change this to the operator you need to be notified.
 + @QuotedIdentifier
from msdb.dbo.sysjobs
where name like 'DBA -%' OR name = 'syspolicy_purge_history'

--print @csvlist
EXEC (@CSVlist)
GO

--------------------------------------------------------------------------------------------------------------------------
--  Update SQL Agent Properties Alert System with Mail Session information
--------------------------------------------------------------------------------------------------------------------------
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1, 
		@databasemail_profile=N'SQL Alert System Profile', 
		@use_databasemail=1
GO
