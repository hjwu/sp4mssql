if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_desc]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_desc]
GO

--List Columns AND Types for USER_TABLE, VIEW, SQL_TABLE_VALUED_FUNCTION and USER_DEFINED_TYPE
--GET Return Data Type for Scalar Function

CREATE PROC sp_desc @name VARCHAR(20) 
AS

SET nocount ON
SET xact_abort ON

DECLARE @ret int
SELECT @ret=0

BEGIN TRY
  DECLARE @sp_columns TABLE(
    TABLE_QUALIFIER sysname, TABLE_OWNER sysname, TABLE_NAME sysname, COLUMN_NAME sysname,
    DATA_TYPE smallint, [TYPE_NAME] sysname, [PRECISION] int, [LENGTH] int, SCALE smallint,
    RADIX smallint, NULLABLE smallint, REMARKS varchar(254), COLUMN_DEF nvarchar(4000),
    SQL_DATA_TYPE smallint, SQL_DATETIME_SUB smallint, CHAR_OCTET_LENGTH int, ORDINAL_POSITION int,
    IS_NULLABLE varchar(254), SS_DATA_TYPE tinyint)

  DECLARE @sproc_columns TABLE(
    PROCEDURE_QUALIFIER sysname, PROCEDURE_OWNER sysname, [PROCEDURE_NAME] nvarchar(134),
    COLUMN_NAME sysname, COLUMN_TYPE smallint, DATA_TYPE smallint, [TYPE_NAME] sysname,
    [PRECISION] int, [LENGTH] int, [SCALE] smallint, RADIX smallint, NULLABLE smallint,
    REMARKS varchar(254), COLUMN_DEF nvarchar(4000), SQL_DATA_TYPE smallint, 
    SQL_DATETIME_SUB smallint, CHAR_OCTET_LENGTH int, ORDINAL_POSITION int, 
    IS_NULLABLE varchar(254), SS_DATA_TYPE tinyint)		

  DECLARE @type_desc NVARCHAR(60);
  SELECT @type_desc = type_desc FROM sys.objects WHERE name = @name;

  IF @type_desc = 'SQL_SCALAR_FUNCTION'
  BEGIN
    INSERT @sproc_columns
    EXEC sys.sp_sproc_columns @name

    SELECT [TYPE_NAME] +		
    CASE UPPER([TYPE_NAME]) 
      WHEN 'NUMERIC' THEN ' (' + CAST([PRECISION] AS VARCHAR) + ',' + CAST([SCALE] AS VARCHAR) + ')'
      WHEN 'CHAR' THEN ' (' + CAST([LENGTH] AS VARCHAR) + ')'
      WHEN 'VARCHAR' THEN ' (' + CAST([LENGTH] AS VARCHAR) + ')'
      WHEN 'NVARCHAR' THEN ' (' + CAST([LENGTH] AS VARCHAR) + ')'					  
      ELSE '' END AS [Type]
    FROM @sproc_columns
    WHERE COLUMN_NAME = '@RETURN_VALUE'
  END

  ELSE IF @type_desc = 'SQL_TABLE_VALUED_FUNCTION' OR @type_desc = 'VIEW' 
  BEGIN
    INSERT @sp_columns 
    EXEC sp_columns @name

    SELECT COLUMN_NAME AS Name,
    UPPER([TYPE_NAME]) +
    CASE UPPER([TYPE_NAME]) 
      WHEN 'NUMERIC' THEN ' (' + CAST([PRECISION] AS VARCHAR) + ',' + CAST([SCALE] AS VARCHAR) + ')'
      WHEN 'CHAR' THEN ' (' + CAST([LENGTH] AS VARCHAR) + ')'
      WHEN 'VARCHAR' THEN ' (' + CAST([LENGTH] AS VARCHAR) + ')'
      WHEN 'NVARCHAR' THEN ' (' + CAST([LENGTH] AS VARCHAR) + ')'
      ELSE '' END AS [Type]
    FROM @sp_columns
  END

  ELSE IF @type_desc = 'USER_TABLE'      	   
  BEGIN
    INSERT @sp_columns 
    EXEC sp_columns @name

    DECLARE @returnTable TABLE(Name VARCHAR(40), [Type] VARCHAR(50), [Cname] VARCHAR(40), [Options] VARCHAR(MAX))

    INSERT @returnTable
    SELECT COLUMN_NAME, 
    UPPER([TYPE_NAME]) +
    CASE UPPER([TYPE_NAME]) 
      WHEN 'NUMERIC' THEN ' (' + CAST([PRECISION] AS VARCHAR) + ',' + CAST([SCALE] AS VARCHAR) + ')'
      WHEN 'CHAR' THEN ' (' + CAST([LENGTH] AS VARCHAR) + ')'
      WHEN 'VARCHAR' THEN ' (' + CAST([LENGTH] AS VARCHAR) + ')'
      WHEN 'NVARCHAR' THEN ' (' + CAST([LENGTH] AS VARCHAR) + ')'
      ELSE '' END, 
    '', ''		   
    FROM @sp_columns		  

    UPDATE @returnTable 
    SET [Cname] = a.ctitle,
        [Options] = CASE [Type] 
          WHEN 'SMALLINT' THEN CAST(a.opt_type AS VARCHAR)
          ELSE '' END
    FROM @returnTable r, app_table_field a
    WHERE a.tablename  = @name 
    AND a.fieldname = r.Name;

    DECLARE @item VARCHAR(30), @option VARCHAR(MAX), @comments VARCHAR(MAX)
    DECLARE #c1 CURSOR FAST_FORWARD FOR (SELECT DISTINCT Options FROM @returnTable WHERE Options <> '')
    OPEN #c1
    FETCH NEXT FROM #c1 INTO @option
    WHILE @@fetch_status = 0
    BEGIN		
      SET @comments = ''		
      DECLARE #c2 CURSOR FAST_FORWARD FOR (SELECT name FROM app_table_field_option_item WHERE opt_no = @option)
      OPEN #c2
      FETCH NEXT FROM #c2 INTO @item
      WHILE @@fetch_status = 0
      BEGIN
        SET @comments = @comments + @item + ' '
        FETCH NEXT FROM #c2 INTO @item
      END	
      CLOSE #c2
      DEALLOCATE #c2
      UPDATE @returnTable SET Options = Options + '\' + @comments WHERE Options = @option			

      FETCH NEXT FROM #c1 INTO @option
    END
    CLOSE #c1
    DEALLOCATE #c1

    SELECT * FROM @returnTable	 
  END
  ELSE
  BEGIN
    DECLARE @count INT
    SELECT @count = COUNT(*) 
    FROM sys.table_types
    WHERE name = @name

    IF @count > 0
    BEGIN
      SELECT c.name AS Name,
      UPPER(t.name) +
      CASE UPPER(t.name) 
        WHEN 'NUMERIC' THEN ' (' + CAST(c.[precision] AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR) + ')'
        WHEN 'CHAR' THEN ' (' + CAST(c.max_length AS VARCHAR) + ')'
        WHEN 'VARCHAR' THEN ' (' + CAST(c.max_length AS VARCHAR) + ')'
        WHEN 'NVARCHAR' THEN ' (' + CAST(c.max_length AS VARCHAR) + ')'
        ELSE '' END AS [Type] 
      FROM sys.table_types as tt, sys.columns as c, sys.types as t 
      WHERE tt.type_table_object_id = c.object_id 
      AND c.system_type_id = t.system_type_id 
      AND tt.name = @name
    END
    ELSE SELECT 'NOT VALID QUERY NAME' AS [MESSAGE]
  END
END TRY

BEGIN CATCH
  GOTO err_handler		
END CATCH;

SELECT @ret=1
GOTO finally

err_handler:
  select @ret=0;
  if @@TRANCOUNT > 0 rollback tran;
  select * from fn_error_info();
  return @ret;

finally:
  return @ret;
GO

IF EXISTS (SELECT 1 FROM sysobjects WHERE id=OBJECT_ID('sp_app_grant') AND OBJECTPROPERTY(id,'IsProcedure')=1)
EXEC sp_app_grant 'sp_desc','EXEC';
GO
