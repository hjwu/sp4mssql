IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[sp_filter]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[sp_filter]
GO

/*---------------------------------
version：1.0.0
date：2014-01-14
description：
Update specified string in all tables and columns of a database
       opt = 0 only show, = 1 do change
---------------------------------*/
CREATE PROC sp_filter
  @SearchStr   NVARCHAR(100),
  @ReplaceStr  VARCHAR(100),
  @opt         INT
AS

CREATE TABLE #Results (TableName NVARCHAR(256), ColumnName NVARCHAR(370), ColumnValue NVARCHAR(3630))

SET NOCOUNT ON

DECLARE @TableName NVARCHAR(256) = ''

DECLARE @ColumnName NVARCHAR(128), @SearchStr2 NVARCHAR(110)
SET @SearchStr2 = QUOTENAME('%' + @SearchStr + '%','''')

WHILE @TableName IS NOT NULL
BEGIN
    SET @ColumnName = ''

    SELECT @TableName = MIN(QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME))
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE'
    AND QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) > @TableName
    AND OBJECTPROPERTY( OBJECT_ID( QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) ), 'IsMSShipped') = 0


    WHILE (@TableName IS NOT NULL) AND (@ColumnName IS NOT NULL)
    BEGIN
    
        SELECT @ColumnName = MIN(QUOTENAME(COLUMN_NAME))
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = PARSENAME(@TableName, 2)
        AND TABLE_NAME = PARSENAME(@TableName, 1)
        AND UPPER(DATA_TYPE) IN ('CHAR', 'VARCHAR', 'NCHAR', 'NVARCHAR')
        AND QUOTENAME(COLUMN_NAME) > @ColumnName


        IF @ColumnName IS NOT NULL
        BEGIN
            INSERT INTO #Results
            EXEC
            (
            'SELECT ''' + @TableName + ''',''' + @ColumnName + ''', LEFT(' + @ColumnName + ', 3630) 
            FROM ' + @TableName + ' (NOLOCK) ' +
            ' WHERE ' + @ColumnName + ' LIKE ' + @SearchStr2
            )
        END
    END
END

IF @opt = 0 
    SELECT DISTINCT TableName, ColumnName, ColumnValue FROM #Results
ELSE
BEGIN
    DECLARE @TN NVARCHAR(256), @CN NVARCHAR(128), @SS NVARCHAR(110)
    DECLARE #c CURSOR FAST_FORWARD FOR SELECT distinct TableName, ColumnName, ColumnValue FROM #Results

    OPEN #c
    FETCH NEXT FROM #c INTO @TN, @CN, @SS
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC 
        (
        'UPDATE' + @TN + ' SET ' + @CN + ' = REPLACE(''' + @SS + ''',''' + @SearchStr + ''','''+ @ReplaceStr + ''')' + ' WHERE ' + @CN + ' = ''' + @SS + ''''
        )
        FETCH NEXT FROM #c INTO @TN, @CN, @SS
    END
    CLOSE #c
    DEALLOCATE #c
END  
GO 
