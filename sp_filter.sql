IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[sp_filter]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[sp_filter]
GO

/*---------------------------------
版本：1.0.0
日期：2014-01-14
內容：Update specified string in all tables and columns of a database
       opt = 0 only show, = 1 do change
---------------------------------*/
CREATE PROC sp_filter
   @SearchStr nvarchar(100),
   @ReplaceStr  varchar(100),
   @opt int
AS
  CREATE TABLE #Results (TableName nvarchar(256), ColumnName nvarchar(370), ColumnValue nvarchar(3630))

  SET NOCOUNT ON

  DECLARE @TableName nvarchar(256)
  SET  @TableName = ''
  DECLARE @ColumnName nvarchar(128), @SearchStr2 nvarchar(110)
  SET @SearchStr2 = QUOTENAME('%' + @SearchStr + '%','''')

  WHILE @TableName IS NOT NULL
  BEGIN
      SET @ColumnName = ''
      SET @TableName =
      (
          SELECT MIN(QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME))
          FROM INFORMATION_SCHEMA.TABLES
          WHERE TABLE_TYPE = 'BASE TABLE'
          AND QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) > @TableName
          AND OBJECTPROPERTY( OBJECT_ID( QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) ), 'IsMSShipped') = 0
      )

      WHILE (@TableName IS NOT NULL) AND (@ColumnName IS NOT NULL)
      BEGIN
          SET @ColumnName =
          (
              SELECT MIN(QUOTENAME(COLUMN_NAME))
              FROM INFORMATION_SCHEMA.COLUMNS
              WHERE TABLE_SCHEMA = PARSENAME(@TableName, 2)
              AND TABLE_NAME = PARSENAME(@TableName, 1)
              AND DATA_TYPE IN ('char', 'varchar', 'nchar', 'nvarchar')
              AND QUOTENAME(COLUMN_NAME) > @ColumnName
          )

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

  IF @opt = 0 SELECT distinct TableName, ColumnName, ColumnValue FROM #Results
  ELSE
  BEGIN
      DECLARE @TN nvarchar(256), @CN nvarchar(128), @SS nvarchar(110)
      DECLARE #c cursor fast_forward for SELECT distinct TableName, ColumnName, ColumnValue FROM #Results

      OPEN #c
      FETCH NEXT FROM #c INTO @TN, @CN, @SS
      WHILE @@fetch_status = 0
      BEGIN        
           EXEC (
              'UPDATE' + @TN + ' SET ' + @CN + ' = REPLACE(''' + @SS + ''',''' + @SearchStr + ''','''+ @ReplaceStr + ''')' + ' WHERE ' + @CN + ' = ''' + @SS + ''''
           )       
           FETCH NEXT FROM #c INTO @TN, @CN, @SS
      END
      CLOSE #c
      DEALLOCATE #c
  END  
GO 

IF EXISTS (SELECT 1 FROM sysobjects WHERE id=OBJECT_ID('sp_filter') AND OBJECTPROPERTY(id,'IsProcedure')=1)
   EXEC sp_app_grant 'sp_filter','EXEC';
GO