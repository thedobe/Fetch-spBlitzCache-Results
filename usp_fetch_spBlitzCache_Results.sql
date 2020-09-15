USE [¿]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER  PROCEDURE [dbo].[usp_fetch_spBlitzCache_Results] (
	@Top INT = 5, 
	@DatabaseList VARCHAR(200) = NULL,
	@SortOrder VARCHAR(200) = 'CPU',
	@MinutesBack INT = -60,
	@Help BIT = NULL
)
AS
BEGIN

	/*
		@SortOrder Possible values are: 
		"CPU", "Reads", "Writes", "Duration", "Executions", "Recent Compilations", "Memory Grant", "Spills". 
		Additionally, the word "Average" or "Avg" can be used to sort on averages rather than total.
		"Executions per minute" and "Executions / minute" can be used to sort by execution per minute. For the truly lazy, "xpm" can also be used. 
		Note that when you use all or all avg, the only parameters you can use are @Top and @DatabaseName. All others will be ignored.
	*/

	SET NOCOUNT ON;

	IF (@Help = 1)
	BEGIN
		EXEC [¿].[dbo].[sp_BlitzCache] @Help = 1
		GOTO DoneWithExec
	END

	DECLARE @err_msg NVARCHAR(MAX)

	IF (@Top > 20)
	BEGIN
		SET @err_msg = '@Top (' + CAST(@Top AS VARCHAR(5)) + ') cannot be greater than 20!'
		SELECT @err_msg
		GOTO DoneWithExec
	END
	
	DECLARE @all_db BIT = 0
	IF (@DatabaseList IS NULL)
	BEGIN
		SET @all_db = 1
	END

	--	error handling for non-existing or offline database
	DECLARE @database_count TINYINT = (SELECT LEN(@DatabaseList) - LEN(REPLACE(@DatabaseList, ',', ''))) + 1
	IF (SELECT COUNT(*) FROM master.sys.databases CROSS APPLY STRING_SPLIT(@DatabaseList, ',') as t WHERE [name] IN (LTRIM(RTRIM(t.[value]))) AND state_desc = 'ONLINE') <> @database_count
	BEGIN
		SET @err_msg = 'SEE Messages Tab: A database name passed into @DatabaseList (' + @DatabaseList + ') does NOT exist OR is offline!' + char(13) + ''
			SELECT @err_msg
			GOTO DoneWithExec
	END
	
	/*
		loop through the passed in parameters for executing against spBlitzCache
		
		Parameters which may be of value:
		@DurationFilter = N -- minimum number in seconds to be considered
		@MinimumExecutionCount = N --minimum number of executions to be considered
	
	*/
	DECLARE @database_name SYSNAME, @s_OrderType VARCHAR(25), @OutputDatabaseName VARCHAR(255) = '¿', @OutputSchemaName VARCHAR(255) = 'dbo', @OutputTableName VARCHAR(255), @OutputStageTableName VARCHAR(255), @s_SQL VARCHAR(MAX)
	
	DECLARE cur_blitz CURSOR FOR SELECT LTRIM(RTRIM(Value)) FROM STRING_SPLIT(COALESCE(@DatabaseList, 'ALL'), ',')
	OPEN cur_blitz
		FETCH cur_blitz INTO @database_name
			WHILE @@FETCH_STATUS <> - 1
			BEGIN
				DECLARE cur_blitz_sortorder CURSOR FOR SELECT LTRIM(RTRIM(Value)) FROM STRING_SPLIT(@SortOrder, ',')
				OPEN cur_blitz_sortorder 
					FETCH cur_blitz_sortorder INTO @s_orderType
						WHILE @@FETCH_STATUS <> - 1
						BEGIN
							SET @OutputStageTableName = 'BlitzCache_Results_' + REPLACE(@s_OrderType, ' ', '_') + '_Stage'
							SET @OutputTableName = 'BlitzCache_Results_' + REPLACE(@s_OrderType, ' ', '_')
							
							--	If results table doesn't exist, run blitzcache for 1 to create shell and alter computed column(s)
							IF (SELECT [name] FROM sys.tables WHERE [name] = @OutputTableName) IS NULL
							BEGIN
								EXEC [¿].[dbo].[sp_BlitzCache] @OutputDatabaseName = @OutputDatabaseName, @OutputSchemaName = @OutputSchemaName, @OutputTableName = @OutputTableName, @Top = 1, @SortOrder = 'CPU', @HideSummary = 1
								SET @s_SQL = '
									TRUNCATE TABLE ' + @OutputTableName + '
								'
								EXEC(@s_SQL)
								
								--	fetch and alter computed columns
								DECLARE @col_name VARCHAR(255), @col_type VARCHAR(255), @col_len VARCHAR(255), @col_nullable VARCHAR(255)
								DECLARE cur_alter_col CURSOR FOR 
									SELECT c.[name], t.[name], t.max_length, t.is_nullable 
									FROM sys.columns c 
									INNER JOIN sys.types t ON t.system_type_id=c.system_type_id 
									WHERE 
										OBJECT_ID = OBJECT_ID(@OutputTableName) AND is_computed = 1
								OPEN cur_alter_col 
									FETCH cur_alter_col INTO @col_name, @col_type, @col_len, @col_nullable
										WHILE @@FETCH_STATUS <> - 1
										BEGIN
											SET @s_SQL = '
												ALTER TABLE ' + @OutputTableName + '
												DROP COLUMN [' + @col_name + ']
												
												ALTER TABLE ' + @OutputTableName + '
												ADD [' + @col_name + '] ' +
													CASE 
														WHEN @col_type in ('varchar', 'nvarchar') THEN '' + @col_type + '(MAX)' 
														ELSE @col_type
													END
													+ ' ' +
													CASE @col_nullable
														WHEN 1 THEN 'NULL' 
														ELSE 'NOT NULL'
													END +
													'
											'
											EXEC(@s_SQL)

										FETCH NEXT FROM cur_alter_col INTO @col_name, @col_type, @col_len, @col_nullable
									END
								CLOSE cur_alter_col
								DEALLOCATE cur_alter_col
							END
							
							--	fetch results into staging table
							SET @s_SQL = '
								EXEC [¿].[dbo].[sp_BlitzCache] ' +
									CASE @all_db
										WHEN 0 THEN ' @DatabaseName = ''' + @database_name + ''','
										ELSE ''
									END + '
									@Top = ' + CAST(@Top AS VARCHAR(5)) + ',
									@SortOrder = ''' + @s_OrderType + ''',
									@MinutesBack = ' + CAST(@MinutesBack AS VARCHAR(5)) + ',
									@HideSummary = 1,
									@IgnoreSystemDBs = 1,
									@OutputDatabaseName = ''' + @OutputDatabaseName + ''', 
									@OutputSchemaName = ''' + @OutputSchemaName + ''', 
									@OutputTableName = ''' + @OutputStageTableName + '''						
							'
							EXEC(@s_SQL)				
							
						FETCH NEXT FROM cur_blitz_sortorder INTO @s_OrderType
					END
				CLOSE cur_blitz_sortorder
				DEALLOCATE cur_blitz_sortorder
	
			FETCH NEXT FROM cur_blitz INTO @database_name
		END
	CLOSE cur_blitz
	DEALLOCATE cur_blitz
	
	--	move results from the staging table to the persisted table per '@SortOrder' and truncate the staging table
	DECLARE @object_id NVARCHAR(25), @insert_col_name VARCHAR(255), @insert_cols VARCHAR(MAX), @build_update VARCHAR(MAX), @build_cols VARCHAR(MAX), @n_SQL NVARCHAR(MAX)
	
	DECLARE cur_blitz_upsert CURSOR FOR SELECT LTRIM(RTRIM(Value)) FROM STRING_SPLIT(@SortOrder, ',')
	OPEN cur_blitz_upsert 
		FETCH cur_blitz_upsert INTO @s_orderType
			WHILE @@FETCH_STATUS <> - 1
			BEGIN
				SET @build_update = ''
				SET @OutputStageTableName = 'BlitzCache_Results_' + REPLACE(@s_OrderType, ' ', '_') + '_Stage'
				SET @OutputTableName = 'BlitzCache_Results_' + REPLACE(@s_OrderType, ' ', '_')
				
				--	fetch table object_id
				SET @n_SQL = N'SELECT @object_id = object_id FROM sys.tables WHERE [name] = ''' + @OutputTableName + ''''
					EXEC sp_executesql @n_SQL, N'@object_id NVARCHAR(25) OUTPUT', @object_id = @object_id OUTPUT
				
				--	build insert column(s)
				SELECT @insert_cols = STUFF((SELECT ', [' + [name] + ']' FROM sys.columns WHERE OBJECT_ID = CAST(@object_id AS INT) AND is_identity = 0 FOR XML PATH(''), TYPE).[value]('.', 'NVARCHAR(MAX)'), 1, 1, '')
				
				--	handle insert
				SET @s_SQL = '
					IF NOT EXISTS (
						SELECT *
						FROM ' + @OutputTableName + ' o
						INNER JOIN ' + @OutputStageTableName + ' s ON s.SqlHandle = o.sqlHandle AND s.planHandle = o.planHandle AND s.[Version] = o.[Version] AND s.QueryType = o.QueryType
					)
					BEGIN
						INSERT INTO ' + @OutputTableName + ' (' + @insert_cols + ')
						SELECT ' + @insert_cols + ' 
						FROM ' + @OutputStageTableName + ' s
						WHERE NOT EXISTS (
							SELECT *
							FROM ' + @OutputTableName + ' o
							WHERE o.SqlHandle = s.sqlHandle AND o.planHandle = s.planHandle AND o.[Version] = s.[Version] AND o.QueryType = s.QueryType
						)
					END
				ELSE	
					IF EXISTS (
						SELECT 1
						FROM ' + @OutputTableName + ' o
						INNER JOIN ' + @OutputStageTableName + ' s on s.SqlHandle = o.SqlHandle AND s.PlanHandle = o.PlanHandle AND s.[Version] = o.[Version] AND o.QueryType = s.QueryType
					)
					BEGIN
						UPDATE o SET
					'			
				--	build update column(s)
				DECLARE cur_blitz_fetch_col CURSOR FOR SELECT [name] FROM sys.columns WHERE is_identity = 0 AND OBJECT_ID = CAST(@object_id AS INT)
				OPEN cur_blitz_fetch_col
					FETCH cur_blitz_fetch_col INTO @insert_col_name
					WHILE @@FETCH_STATUS <> -1
					BEGIN
						SET @build_cols = '
						o.[' + @insert_col_name + '] = s.[' + @insert_col_name + '],'
							
						SET @build_update = COALESCE(@build_update, '') + @build_cols								
					
					FETCH NEXT FROM cur_blitz_fetch_col INTO @insert_col_name
					END
				CLOSE cur_blitz_fetch_col
				DEALLOCATE cur_blitz_fetch_col	
				
				--	remove trailng comma
				SET @build_update = SUBSTRING(@build_update, 1, LEN(@build_update) - 1)

				--	add the update column(s) to the variable
				SET @s_SQL = @s_SQL + @build_update
								
				SET @s_SQL = @s_SQL + '
					FROM ' + @OutputTableName + ' o
					INNER JOIN ' + @OutputStageTableName + ' s on s.SqlHandle = o.SqlHandle AND s.PlanHandle = o.PlanHandle AND s.[Version] = o.[Version] AND o.QueryType = s.QueryType	
				END

				TRUNCATE TABLE ' + @OutputStageTableName + '
				'
				
				EXEC(@s_SQL)
				
			FETCH NEXT FROM cur_blitz_upsert INTO @s_OrderType
		END
	CLOSE cur_blitz_upsert
	DEALLOCATE cur_blitz_upsert

	DoneWithExec:
	
END
