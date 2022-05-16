 

CREATE    PROCEDURE dbo.BlitzCacheResults_Email

AS

BEGIN

 

--            rank the top N for CPU/Reads/Memory Grants

 

               DROP TABLE IF EXISTS #t

               CREATE TABLE #t (Metric VARCHAR(20), DatabaseName SYSNAME, QueryText VARCHAR(500), PlanHandle VARBINARY(64), SqlHandle VARBINARY(64), QueryHash BINARY(8))

              

               --            find test/recovered databases

               DECLARE @startDate DATE = (SELECT CAST(DATEADD(DAY, -7 - (DATEPART(WEEKDAY, GETUTCDATE()) + @@DATEFIRST - 2) % 7, GETUTCDATE()) AS DATE))

               DECLARE @endDate DATE = (SELECT CAST(DATEADD(DAY, -1 - (DATEPART(WEEKDAY, GETUTCDATE()) + @@DATEFIRST - 2) % 7, GETUTCDATE()) AS DATE))

               DECLARE @SortOrder VARCHAR(250) = (SELECT SUBSTRING(js.command, CHARINDEX('@SortOrder = ', js.command) + LEN('@SortOrder = '), 99) FROM msdb.dbo.sysjobs j INNER JOIN msdb.dbo.sysjobsteps js ON js.job_id=j.job_id WHERE j.name = 'DBA - Fetch BlitzCache')

               DECLARE @tableName SYSNAME, @SQL VARCHAR(MAX)

 

               --            return previous week monday through sunday and send findings

               DECLARE cur_blitz CURSOR FORWARD_ONLY STATIC FOR

                              SELECT t.[name] FROM sys.tables t CROSS APPLY STRING_SPLIT(@SortOrder, ',') AS l WHERE t.[name] LIKE 'BlitzCache_Results_%' + REPLACE(REPLACE(LTRIM(RTRIM(l.Value)), '''', ''), ' ', '_') + '%' AND t.[name] NOT LIKE '%Stage%'

 

               OPEN cur_blitz   

               FETCH NEXT FROM cur_blitz INTO @tableName 

               WHILE @@FETCH_STATUS = 0   

                              BEGIN

                              SET @SQL = '

SELECT TOP (5)

               CASE

                              WHEN ''' + @tableName + ''' LIKE ''%CPU%'' THEN ''CPU''

                              WHEN ''' + @tableName + ''' LIKE ''%Duration%'' THEN ''Duration''

                              WHEN ''' + @tableName + ''' LIKE ''%Memory_Grant%'' THEN ''Memory Grant''

                              WHEN ''' + @tableName + ''' LIKE ''%Reads%'' THEN ''Reads''

                              WHEN ''' + @tableName + ''' LIKE ''%Writes%'' THEN ''Writes''

                              ELSE ''Unknown''

               END AS Metric,

               DatabaseName, LEFT(QueryText,500), PlanHandle, SqlHandle, QueryHash

               FROM ' + @tableName + '

WHERE

               CAST(CheckDate AS DATE) >= ''' + CAST(@startDate AS VARCHAR(15)) + ''' AND 

               CAST(CheckDate AS DATE) <= ''' + CAST(@endDate AS VARCHAR(15)) + '''

ORDER BY

               CASE

                              WHEN ''' + @tableName + ''' LIKE ''%CPU%'' THEN AverageCPU

                              WHEN ''' + @tableName + ''' LIKE ''%Duration%'' THEN AverageDuration

                              WHEN ''' + @tableName + ''' LIKE ''%Memory_Grant%'' THEN AvgMaxMemoryGrant

                              WHEN ''' + @tableName + ''' LIKE ''%Reads%'' THEN AverageReads

                              WHEN ''' + @tableName + ''' LIKE ''%Writes%'' THEN AverageWrites

                              ELSE AverageCPU

               END

DESC

'

               INSERT INTO #t EXECUTE (@SQL)

                              FETCH NEXT FROM cur_blitz INTO @tableName

               END

CLOSE cur_blitz

DEALLOCATE cur_blitz

 

IF (SELECT COUNT(*) FROM #t) > 0

BEGIN

 

--            build email

DECLARE @ProfileName VARCHAR(50), @Subject VARCHAR(100), @Header VARCHAR(MAX),  @Body VARCHAR(MAX), @Recipients VARCHAR(255) = youremail@rate.com'

 

SET @Subject = 'BlitzCache Results - ' + @@SERVERNAME;

 

SET @Header = '<html><head>'

               + '<style>'

               + 'td {border: solid black 1px;padding-left:5px;padding-right:5px;padding-top:1px;padding-bottom:1px;font-size:12pt;color:Black;} '

               + '</style>'

               + '</head>';

 

SELECT @Body = (

               SELECT

                              ISNULL(Metric, '') AS [TD],

                              ISNULL(DatabaseName, '') AS [TD],

                              ISNULL(QueryText, '') AS [TD],

                              ISNULL(CONVERT(VARCHAR(1000), PlanHandle, 1), '') AS [TD],

                              ISNULL(CONVERT(VARCHAR(1000), SqlHandle, 1), '') AS [TD],

                              ISNULL(CONVERT(VARCHAR(1000), QueryHash, 1), '') AS [TD]

               FROM #t

               FOR XML RAW('tr'), ELEMENTS );

 

SET @Body = '<body>'

               + '<H4>Resource Intensive Objects on ' + @@SERVERNAME + ' (' + CAST(@startDate AS VARCHAR(15)) + ' - ' + CAST(@endDate AS VARCHAR(10)) + ')</H4>'

               + '<table cellpadding=5 cellspacing=0 border=1>'

               + '<tr bgcolor=#F6AC5D>'

                              + '<td align=center><b>Metric</b></td>'

                              + '<td align=center><b>DatabaseName</b></td>'

                              + '<td align=center><b>QueryText (LEFT 500)</b></td>'

                              + '<td align=center><b>PlanHandle</b></td>'

                              + '<td align=center><b>SqlHandle</b></td>'

                              + '<td align=center><b>QueryHash</b></td>'

               + '</tr>'

               + @Body

               + '</table></body></html>';

 

               EXEC [msdb].[dbo].[sp_send_dbmail]

                              @recipients = @Recipients,

                              @subject = @Subject,

                              @body = @Body,

                              @body_format = 'HTML',

                              @profile_name = @ProfileName;

END

 

--            delete stale data

DECLARE cur_blitz_del CURSOR FORWARD_ONLY STATIC FOR

                              SELECT t.[name] FROM sys.tables t WHERE t.[name] LIKE 'BlitzCache_Results_%' AND t.[name] NOT LIKE '%Stage%'

 

               OPEN cur_blitz_del   

               FETCH NEXT FROM cur_blitz_del INTO @tableName 

               WHILE @@FETCH_STATUS = 0   

                              BEGIN

                              SET @SQL = 'TRUNCATE TABLE ' + @tableName + ''

                              EXEC (@SQL)

                                             FETCH NEXT FROM cur_blitz_del INTO @tableName

                              END

CLOSE cur_blitz_del

DEALLOCATE cur_blitz_del

END
