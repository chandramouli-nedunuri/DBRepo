-- Architected Azure SQL conversion of Oracle package EPS.PKG_AUDIT
-- Source: Packages/EPS.PKG_AUDIT.txt
-- Base target: Azure SQL/Packages/EPS.PKG_AUDIT.txt
-- File: Azure SQL/Packages/EPS.PKG_AUDIT.txt_v1
-- NOTE: Oracle package source is partially truncated in tool output, so this v1 focuses on
-- fully replacing Oracle-specific metadata wrappers with Azure SQL-safe helpers and procedures.

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'EPS')
BEGIN
    EXEC('CREATE SCHEMA [EPS]');
END;
GO

/*
Migration strategy:
- Oracle package/functions -> standalone T-SQL functions/procedures in schema [EPS]
- Oracle USER_* dictionary views -> sys.tables/sys.columns/sys.indexes/sys.schemas/sys.sql_modules/sys.triggers
- Oracle DBMS_METADATA / DBMS_LOB / pipelined functions -> metadata-driven T-SQL string generation
- Oracle tablespace logic -> Azure filegroup/storage placeholder values (not physically equivalent in Azure SQL)
- Oracle row-level trigger generation -> SQL Server set-based inserted/deleted trigger generation
- Oracle EXECUTE IMMEDIATE -> sp_executesql / EXEC
- Oracle ROWID-dependent warnings -> eliminated by key-based metadata logic only
- NUMBER warnings -> mitigated with BIGINT/INT where appropriate
*/

CREATE OR ALTER FUNCTION [EPS].[PKG_AUDIT_Fn_LookupPdxSchemaConfig]
(
    @p_key NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
AS
BEGIN
    DECLARE @l_val NVARCHAR(4000);

    SELECT TOP (1) @l_val = CAST([value] AS NVARCHAR(4000))
    FROM dbo.pdx_schema_config
    WHERE UPPER([key]) = UPPER(@p_key)
      AND [source] = N'P';

    IF @l_val IS NULL
        THROW 53015, 'Unable to lookup key in pdx_schema_config.', 1;

    RETURN @l_val;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_AUDIT_Fn_GetTablespace]
(
    @p_Type NVARCHAR(20),
    @p_Name NVARCHAR(128) = NULL
)
RETURNS NVARCHAR(128)
AS
BEGIN
    DECLARE @f_Ts NVARCHAR(128) = NULL;
    SET @f_Ts = CASE UPPER(@p_Type)
                    WHEN N'TABLE' THEN N'PRIMARY'
                    WHEN N'INDEX' THEN N'PRIMARY'
                    WHEN N'LOB'   THEN N'PRIMARY'
                    ELSE N'PRIMARY'
                END;
    RETURN @f_Ts;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_AUDIT_Fn_ListAuditTables_inline]()
RETURNS TABLE
AS
RETURN
(
    WITH x AS
    (
        SELECT t.name AS TABLE_NAME,
               COALESCE(m.AUDIT_TABLE, CONCAT(t.name, N'_AUDIT')) AS AUDIT_TABLE
        FROM sys.tables t
        LEFT JOIN dbo.AUDIT_TABLE_MAPPING m
            ON m.APP_TABLE = t.name
        WHERE t.is_ms_shipped = 0

        UNION
        SELECT N'AUDIT_ACCESS_LOG', N'AUDIT_ACCESS_LOG'
        UNION
        SELECT N'AUDIT_MESSAGE_CONTENT', N'AUDIT_MESSAGE_CONTENT'
    )
    SELECT TABLE_NAME, AUDIT_TABLE
    FROM x
);
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_BuildErrorText]
    @Context NVARCHAR(4000),
    @ErrorText NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @ErrorText =
        @Context + CHAR(10)
        + N'ERROR_NUMBER=' + CONVERT(NVARCHAR(20), ERROR_NUMBER()) + CHAR(10)
        + N'ERROR_MESSAGE=' + COALESCE(ERROR_MESSAGE(), N'<NULL>') + CHAR(10)
        + N'ERROR_PROCEDURE=' + COALESCE(ERROR_PROCEDURE(), N'<NULL>') + CHAR(10)
        + N'ERROR_LINE=' + CONVERT(NVARCHAR(20), ERROR_LINE());
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_GetPartitionDesign]
    @AuditTable SYSNAME,
    @PartitionDdl NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    /*
    Azure SQL Database does not support Oracle-style tablespace/subpartition syntax parity.
    This procedure records the intended storage deviation explicitly so orchestration code
    can preserve the migration decision in one place.
    */
    SET @PartitionDdl = N'-- Storage deviation: Oracle tablespace/list partition/subpartition logic for ' 
                      + QUOTENAME(@AuditTable)
                      + N' is not emitted in Azure SQL Database. Use optional SQL Server partition function/scheme redesign if required.';
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_GenerateAuditTableDdl]
    @BaseTable SYSNAME,
    @AuditTable SYSNAME,
    @GeneratedDdl NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @base_object_id INT = OBJECT_ID(N'dbo.' + QUOTENAME(@BaseTable), N'U');
    DECLARE @has_audit_timestamp BIT = 0;
    DECLARE @column_list NVARCHAR(MAX);
    DECLARE @partition_note NVARCHAR(MAX);

    IF @base_object_id IS NULL
        THROW 53201, 'Base table not found for audit-table DDL generation.', 1;

    SELECT @has_audit_timestamp = CASE WHEN EXISTS (
        SELECT 1 FROM sys.columns WHERE object_id = @base_object_id AND name = N'AUDIT_TIMESTAMP'
    ) THEN 1 ELSE 0 END;

    SELECT @column_list = STRING_AGG(
        N'    ' + QUOTENAME(c.name) + N' ' +
        CASE
            WHEN ty.name IN (N'varchar', N'char', N'varbinary', N'binary')
                THEN ty.name + N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CONVERT(NVARCHAR(20), c.max_length) END + N')'
            WHEN ty.name IN (N'nvarchar', N'nchar')
                THEN ty.name + N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CONVERT(NVARCHAR(20), c.max_length / 2) END + N')'
            WHEN ty.name IN (N'decimal', N'numeric')
                THEN ty.name + N'(' + CONVERT(NVARCHAR(10), c.[precision]) + N',' + CONVERT(NVARCHAR(10), c.scale) + N')'
            WHEN ty.name IN (N'datetime2', N'time', N'datetimeoffset')
                THEN ty.name + N'(' + CONVERT(NVARCHAR(10), c.scale) + N')'
            ELSE ty.name
        END
        + CASE WHEN c.is_identity = 1 THEN N' IDENTITY(1,1)' ELSE N'' END
        + CASE WHEN c.is_nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END,
        N',' + CHAR(10)
    ) WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c
    INNER JOIN sys.types ty
        ON ty.user_type_id = c.user_type_id
    WHERE c.object_id = @base_object_id;

    EXEC [EPS].[PKG_AUDIT_GetPartitionDesign]
        @AuditTable = @AuditTable,
        @PartitionDdl = @partition_note OUTPUT;

    SET @GeneratedDdl = N'CREATE TABLE dbo.' + QUOTENAME(@AuditTable) + N' (' + CHAR(10)
        + COALESCE(@column_list, N'')
        + CASE WHEN RIGHT(@AuditTable, 6) = N'_AUDIT' THEN N',' + CHAR(10) + N'    [DML_TYPE] NVARCHAR(1) NULL' ELSE N'' END
        + CASE WHEN RIGHT(@AuditTable, 6) = N'_AUDIT' THEN N',' + CHAR(10) + N'    [ID_AUDIT] BIGINT NOT NULL DEFAULT NEXT VALUE FOR dbo.AUDIT_SEQ' ELSE N'' END
        + CASE WHEN RIGHT(@AuditTable, 6) = N'_AUDIT'
               THEN N',' + CHAR(10) + N'    [AUDIT_TIMESTAMP] DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()'
               ELSE CASE WHEN @has_audit_timestamp = 0 THEN N',' + CHAR(10) + N'    [AUDIT_TIMESTAMP] DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()' ELSE N'' END END
        + CHAR(10) + N');' + CHAR(10) + COALESCE(@partition_note, N'');
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_AUDIT_Fn_GetTriggerName]
(
    @p_AuditName NVARCHAR(128)
)
RETURNS NVARCHAR(128)
AS
BEGIN
    DECLARE @v_Return NVARCHAR(128) = NULL;
    DECLARE @v_TriggerExt NVARCHAR(10) = N'AU';
    DECLARE @l_c INT = 0;
    DECLARE @f_DmlTypeFound INT = 0;
    DECLARE @object_id INT;

    SET @object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@p_AuditName), N'U');

    IF @object_id IS NULL
        THROW 53101, 'Audit table not found. Unable to create trigger.', 1;

    SELECT @l_c = COUNT(*)
    FROM sys.columns
    WHERE object_id = @object_id
      AND name IN (N'ID_AUDIT', N'AUDIT_TIMESTAMP');

    SELECT @f_DmlTypeFound = COUNT(*)
    FROM sys.columns
    WHERE object_id = @object_id
      AND name = N'DML_TYPE';

    IF @l_c <> 2
        THROW 53102, 'ID_AUDIT or AUDIT_TIMESTAMP missing from audit table.', 1;

    IF @f_DmlTypeFound = 1
        SET @v_TriggerExt += N'D';

    SET @v_TriggerExt += N'R';
    SET @v_Return = REPLACE(@p_AuditName, N'_AUDIT', N'_' + @v_TriggerExt);

    RETURN @v_Return;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_AUDIT_Fn_GetTriggerInsert]
(
    @p_TableName NVARCHAR(128),
    @p_AuditName NVARCHAR(128),
    @p_TrigExt NVARCHAR(20),
    @p_Type NVARCHAR(10)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @column_list NVARCHAR(MAX) = N'';
    DECLARE @select_list NVARCHAR(MAX) = N'';
    DECLARE @v_Ddl NVARCHAR(MAX) = N'';
    DECLARE @table_object_id INT = OBJECT_ID(N'dbo.' + QUOTENAME(@p_TableName), N'U');
    DECLARE @audit_object_id INT = OBJECT_ID(N'dbo.' + QUOTENAME(@p_AuditName), N'U');
    DECLARE @source_alias NVARCHAR(20) = CASE WHEN UPPER(@p_Type) = N'U' THEN N'i' ELSE N'd' END;

    IF @table_object_id IS NULL OR @audit_object_id IS NULL
        THROW 53103, 'Base or audit table not found while building trigger insert.', 1;

    SELECT @column_list = STRING_AGG(QUOTENAME(t.name), N',' + CHAR(10) + N'           '),
           @select_list = STRING_AGG(@source_alias + N'.' + QUOTENAME(t.name), N',' + CHAR(10) + N'           ')
    FROM sys.columns t
    INNER JOIN sys.columns a
        ON a.name = t.name
       AND a.object_id = @audit_object_id
    WHERE t.object_id = @table_object_id;

    SET @v_Ddl = N'    INSERT INTO dbo.' + QUOTENAME(@p_AuditName) + N' (' + CHAR(10)
             + N'           ' + COALESCE(@column_list, N'')
             + CASE WHEN CHARINDEX(N'D', UPPER(@p_TrigExt)) > 0 THEN N',' + CHAR(10) + N'           [DML_TYPE]' ELSE N'' END
             + N',' + CHAR(10) + N'           [ID_AUDIT]'
             + N',' + CHAR(10) + N'           [AUDIT_TIMESTAMP]' + CHAR(10)
             + N'    )' + CHAR(10)
             + N'    SELECT ' + CHAR(10)
             + N'           ' + COALESCE(@select_list, N'')
             + CASE WHEN CHARINDEX(N'D', UPPER(@p_TrigExt)) > 0 THEN N',' + CHAR(10) + N'           N''' + @p_Type + N'''' ELSE N'' END
             + N',' + CHAR(10) + N'           NEXT VALUE FOR dbo.AUDIT_SEQ'
             + N',' + CHAR(10) + N'           SYSUTCDATETIME()' + CHAR(10)
             + N'    FROM ' + CASE WHEN UPPER(@p_Type) = N'U' THEN N'inserted' ELSE N'deleted' END + N' ' + @source_alias + N';' + CHAR(10);

    RETURN @v_Ddl;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_AUDIT_Fn_GetTriggerDdl]
(
    @p_TrigName NVARCHAR(128),
    @p_TableName NVARCHAR(128),
    @p_AuditName NVARCHAR(128)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @v_Ddl NVARCHAR(MAX) = N'';
    DECLARE @v_TrigType NVARCHAR(50) = RIGHT(@p_TrigName, CHARINDEX(N'_', REVERSE(@p_TrigName)) - 1);
    DECLARE @event_list NVARCHAR(100) = STUFF(
            CASE WHEN CHARINDEX(N'U', @v_TrigType) > 0 THEN N', UPDATE' ELSE N'' END
          + CASE WHEN CHARINDEX(N'D', @v_TrigType) > 0 THEN N', DELETE' ELSE N'' END,
          1, 2, N''
        );

    SET @v_Ddl = N'CREATE OR ALTER TRIGGER dbo.' + QUOTENAME(@p_TrigName) + CHAR(10)
        + N'ON dbo.' + QUOTENAME(@p_TableName) + CHAR(10)
        + N'AFTER ' + @event_list + CHAR(10)
        + N'AS' + CHAR(10)
        + N'BEGIN' + CHAR(10)
        + N'    SET NOCOUNT ON;' + CHAR(10);

    IF CHARINDEX(N'U', @v_TrigType) > 0
        SET @v_Ddl += [EPS].[PKG_AUDIT_Fn_GetTriggerInsert](@p_TableName, @p_AuditName, @v_TrigType, N'U');

    IF CHARINDEX(N'D', @v_TrigType) > 0
        SET @v_Ddl += [EPS].[PKG_AUDIT_Fn_GetTriggerInsert](@p_TableName, @p_AuditName, @v_TrigType, N'D');

    SET @v_Ddl += N'END;' + CHAR(10);

    RETURN @v_Ddl;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_GenerateTriggerDdl]
    @TableName SYSNAME,
    @AuditTable SYSNAME,
    @GeneratedDdl NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TriggerName SYSNAME;
    SET @TriggerName = [EPS].[PKG_AUDIT_Fn_GetTriggerName](@AuditTable);
    SET @GeneratedDdl = [EPS].[PKG_AUDIT_Fn_GetTriggerDdl](@TriggerName, @TableName, @AuditTable);
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_GenerateIndexDdl]
    @BaseTable SYSNAME,
    @AuditTable SYSNAME,
    @GeneratedDdl NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @base_object_id INT = OBJECT_ID(N'dbo.' + QUOTENAME(@BaseTable), N'U');

    IF @base_object_id IS NULL
        THROW 53202, 'Base table not found for index DDL generation.', 1;

    ;WITH idx AS
    (
        SELECT i.index_id,
               i.name,
               i.is_unique,
               i.type_desc
        FROM sys.indexes i
        WHERE i.object_id = @base_object_id
          AND i.type_desc <> N'HEAP'
          AND i.is_hypothetical = 0
          AND i.name IS NOT NULL
    ),
    cols AS
    (
        SELECT i.name AS index_name,
               ic.key_ordinal,
               ic.is_included_column,
               c.name AS column_name
        FROM idx i
        INNER JOIN sys.index_columns ic
            ON ic.object_id = @base_object_id
           AND ic.index_id = i.index_id
        INNER JOIN sys.columns c
            ON c.object_id = ic.object_id
           AND c.column_id = ic.column_id
    )
    SELECT @GeneratedDdl = STRING_AGG(
        N'CREATE ' + CASE WHEN i.is_unique = 1 THEN N'UNIQUE ' ELSE N'' END + i.type_desc + N' INDEX ' + QUOTENAME(i.name)
        + N' ON dbo.' + QUOTENAME(@AuditTable) + N' ('
        + COALESCE((
            SELECT STRING_AGG(QUOTENAME(c1.column_name), N', ') WITHIN GROUP (ORDER BY c1.key_ordinal)
            FROM cols c1
            WHERE c1.index_name = i.name
              AND c1.is_included_column = 0
        ), N'')
        + CASE
            WHEN i.is_unique = 1
             AND NOT EXISTS (
                    SELECT 1 FROM cols c2 WHERE c2.index_name = i.name AND UPPER(c2.column_name) = N'AUDIT_TIMESTAMP'
                )
            THEN CASE WHEN EXISTS (
                    SELECT 1 FROM cols c3 WHERE c3.index_name = i.name AND c3.is_included_column = 0
                ) THEN N', [AUDIT_TIMESTAMP]' ELSE N'[AUDIT_TIMESTAMP]' END
            ELSE N''
          END
        + N')'
        + CASE WHEN EXISTS (
                SELECT 1 FROM cols c4 WHERE c4.index_name = i.name AND c4.is_included_column = 1
            )
            THEN N' INCLUDE (' + (
                SELECT STRING_AGG(QUOTENAME(c5.column_name), N', ') WITHIN GROUP (ORDER BY c5.column_name)
                FROM cols c5
                WHERE c5.index_name = i.name
                  AND c5.is_included_column = 1
            ) + N')'
            ELSE N''
          END
        + N';',
        CHAR(10) + CHAR(10)
    )
    FROM idx i;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_AUDIT_Fn_GetDdl]
(
    @p_Name NVARCHAR(128),
    @p_NewName NVARCHAR(128),
    @p_Type NVARCHAR(20)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @v_Ddl NVARCHAR(MAX) = N'';
    DECLARE @obj_id INT;

    IF UPPER(@p_Type) = N'TABLE'
    BEGIN
        SET @obj_id = OBJECT_ID(N'dbo.' + QUOTENAME(@p_Name), N'U');

        IF @obj_id IS NULL
            THROW 53104, 'Object not found for table DDL generation.', 1;

        EXEC [EPS].[PKG_AUDIT_GenerateAuditTableDdl]
            @BaseTable = @p_Name,
            @AuditTable = @p_NewName,
            @GeneratedDdl = @v_Ddl OUTPUT;
    END
    ELSE IF UPPER(@p_Type) = N'INDEX'
    BEGIN
        EXEC [EPS].[PKG_AUDIT_GenerateIndexDdl]
            @BaseTable = @p_Name,
            @AuditTable = @p_NewName,
            @GeneratedDdl = @v_Ddl OUTPUT;
    END
    ELSE
    BEGIN
        SET @v_Ddl = N'-- Unsupported DDL type requested: ' + @p_Type;
    END

    RETURN @v_Ddl;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_Sp_VerifyMappingRecords]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_BadTabs NVARCHAR(MAX) = NULL;

    ;WITH bad AS
    (
        SELECT atm.APP_TABLE
        FROM dbo.AUDIT_TABLE_MAPPING atm
        LEFT JOIN sys.tables t
            ON t.name = atm.APP_TABLE
        WHERE t.object_id IS NULL
    )
    SELECT @v_BadTabs = STRING_AGG(APP_TABLE, N', ')
    FROM bad;

    IF @v_BadTabs IS NOT NULL
        THROW 53001, 'Mapping table records exist for tables that do not exist.', 1;

    ;WITH missing_audit AS
    (
        SELECT atm.APP_TABLE, atm.AUDIT_TABLE
        FROM dbo.AUDIT_TABLE_MAPPING atm
        LEFT JOIN sys.tables t
            ON t.name = atm.AUDIT_TABLE
        WHERE t.object_id IS NULL
    )
    SELECT * INTO #missing_audit FROM missing_audit;

    DECLARE @app_table NVARCHAR(128);
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT APP_TABLE FROM #missing_audit;
    OPEN cur;
    FETCH NEXT FROM cur INTO @app_table;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [EPS].[PKG_AUDIT_Sp_CreateAudit] @p_Table = @app_table;
        FETCH NEXT FROM cur INTO @app_table;
    END
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_Sp_ModifyIndexes]
(
    @p_Table NVARCHAR(128),
    @p_AuditTable NVARCHAR(128),
    @p_CopyTable NVARCHAR(128),
    @p_TS NVARCHAR(128),
    @p_Ext NVARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ddl NVARCHAR(MAX);
    EXEC [EPS].[PKG_AUDIT_GenerateIndexDdl]
        @BaseTable = @p_CopyTable,
        @AuditTable = @p_AuditTable,
        @GeneratedDdl = @ddl OUTPUT;

    IF @ddl IS NOT NULL AND LTRIM(RTRIM(@ddl)) <> N''
        EXEC sp_executesql @ddl;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_Sp_CreateAuditTable]
(
    @p_Table NVARCHAR(128),
    @p_AuditTable NVARCHAR(128),
    @p_TableTS NVARCHAR(128),
    @p_CopyTable NVARCHAR(128) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @base_table NVARCHAR(128) = COALESCE(@p_CopyTable, @p_Table);
    DECLARE @ddl NVARCHAR(MAX);

    EXEC [EPS].[PKG_AUDIT_GenerateAuditTableDdl]
        @BaseTable = @base_table,
        @AuditTable = @p_AuditTable,
        @GeneratedDdl = @ddl OUTPUT;

    EXEC sp_executesql @ddl;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_Sp_DropTrigger]
(
    @p_TableName NVARCHAR(128),
    @p_AuditName NVARCHAR(128)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @trigger_name NVARCHAR(128);
    DECLARE trg_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT tr.name
        FROM sys.triggers tr
        INNER JOIN sys.tables tb ON tb.object_id = tr.parent_id
        INNER JOIN sys.sql_modules sm ON sm.object_id = tr.object_id
        WHERE tb.name = @p_TableName
          AND UPPER(sm.definition) LIKE N'%' + UPPER(@p_AuditName) + N'%';

    OPEN trg_cur;
    FETCH NEXT FROM trg_cur INTO @trigger_name;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC (N'DROP TRIGGER dbo.' + QUOTENAME(@trigger_name) + N';');
        FETCH NEXT FROM trg_cur INTO @trigger_name;
    END
    CLOSE trg_cur;
    DEALLOCATE trg_cur;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_Sp_CreateTrigger]
(
    @p_TableName NVARCHAR(128),
    @p_AuditName NVARCHAR(128)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_Ddl NVARCHAR(MAX);

    EXEC [EPS].[PKG_AUDIT_Sp_DropTrigger] @p_TableName = @p_TableName, @p_AuditName = @p_AuditName;
    EXEC [EPS].[PKG_AUDIT_GenerateTriggerDdl]
        @TableName = @p_TableName,
        @AuditTable = @p_AuditName,
        @GeneratedDdl = @v_Ddl OUTPUT;

    EXEC sp_executesql @v_Ddl;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_Sp_AddMappingRecord]
(
    @p_TableName NVARCHAR(128),
    @p_AuditTable NVARCHAR(128)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_TableName NVARCHAR(128) = UPPER(@p_TableName);
    DECLARE @v_AuditTable NVARCHAR(128) = UPPER(@p_AuditTable);
    DECLARE @f_AuditTable NVARCHAR(128) = NULL;
    DECLARE @f_Count INT = 0;

    SELECT TOP (1) @f_AuditTable = AUDIT_TABLE
    FROM [EPS].[PKG_AUDIT_Fn_ListAuditTables_inline]()
    WHERE TABLE_NAME = @v_TableName;

    IF @f_AuditTable IS NULL
    BEGIN
        SELECT @f_Count = COUNT(*)
        FROM sys.tables
        WHERE name = @v_TableName;

        IF @f_Count = 0
            THROW 53003, 'Table does not exist as a user table. Unable to create mapping record.', 1;

        INSERT INTO dbo.AUDIT_TABLE_MAPPING (APP_TABLE, AUDIT_TABLE)
        VALUES (@v_TableName, @v_AuditTable);
    END
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_AUDIT_Sp_CreateAudit]
(
    @p_Table NVARCHAR(128),
    @p_ReplaceAudit NVARCHAR(1) = N'N',
    @p_TableTS NVARCHAR(128) = NULL,
    @p_IndexTS NVARCHAR(128) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @v_Table NVARCHAR(128) = UPPER(@p_Table);
    DECLARE @v_TableTS NVARCHAR(128) = UPPER(@p_TableTS);
    DECLARE @v_IndexTS NVARCHAR(128) = UPPER(@p_IndexTS);
    DECLARE @v_ReplaceAudit NVARCHAR(5) = COALESCE(UPPER(@p_ReplaceAudit), N'N');
    DECLARE @v_Sql NVARCHAR(MAX) = NULL;
    DECLARE @v_CopyTable NVARCHAR(128) = NULL;
    DECLARE @v_Ext NVARCHAR(20) = CONVERT(NVARCHAR(20), FORMAT(SYSUTCDATETIME(), 'MMddyy'));
    DECLARE @f_AuditTable NVARCHAR(128) = NULL;
    DECLARE @f_Count INT = 0;
    DECLARE @v_error NVARCHAR(MAX);

    BEGIN TRY
        SELECT TOP (1) @f_AuditTable = AUDIT_TABLE
        FROM [EPS].[PKG_AUDIT_Fn_ListAuditTables_inline]()
        WHERE TABLE_NAME = @v_Table;

        IF @f_AuditTable IS NULL
        BEGIN
            IF LEN(@v_Table + N'_AUDIT') > 128
                THROW 53004, 'Audit name too long.', 1;
            SET @f_AuditTable = @v_Table + N'_AUDIT';
        END

        IF @v_TableTS IS NULL
            SET @v_TableTS = [EPS].[PKG_AUDIT_Fn_GetTablespace](N'TABLE', @v_Table);

        IF @v_IndexTS IS NULL
            SET @v_IndexTS = [EPS].[PKG_AUDIT_Fn_GetTablespace](N'INDEX', @f_AuditTable);

        IF @v_ReplaceAudit = N'N'
        BEGIN
            NULL;
        END
        ELSE IF @v_ReplaceAudit = N'Y'
        BEGIN
            SET @v_CopyTable = LEFT(@f_AuditTable, 120) + @v_Ext;
            IF OBJECT_ID(N'dbo.' + QUOTENAME(@f_AuditTable), N'U') IS NOT NULL
            BEGIN
                IF OBJECT_ID(N'dbo.' + QUOTENAME(@v_CopyTable), N'U') IS NOT NULL
                    THROW 53005, 'Copy table already exists.', 1;

                SET @v_Sql = N'EXEC sp_rename ''dbo.' + @f_AuditTable + N''', ''' + @v_CopyTable + N''';';
                EXEC sp_executesql @v_Sql;
            END
        END
        ELSE
            THROW 53006, 'Invalid replace flag.', 1;

        SELECT @f_Count = COUNT(*)
        FROM sys.tables
        WHERE name = @f_AuditTable;

        IF @f_Count = 0
        BEGIN
            IF @v_Table IN (N'AUDIT_ACCESS_LOG', N'AUDIT_MESSAGE_CONTENT')
            BEGIN
                SELECT @f_Count = COUNT(*) FROM sys.tables WHERE name = @v_CopyTable;
                IF @f_Count = 0
                    THROW 53007, 'Base table missing for audit replacement.', 1;
                EXEC [EPS].[PKG_AUDIT_Sp_CreateAuditTable] @p_Table = @v_CopyTable, @p_AuditTable = @f_AuditTable, @p_TableTS = @v_TableTS, @p_CopyTable = @v_CopyTable;
            END
            ELSE
            BEGIN
                EXEC [EPS].[PKG_AUDIT_Sp_CreateAuditTable] @p_Table = @v_Table, @p_AuditTable = @f_AuditTable, @p_TableTS = @v_TableTS, @p_CopyTable = @v_CopyTable;
            END
        END

        EXEC [EPS].[PKG_AUDIT_Sp_ModifyIndexes]
            @p_Table = @v_Table,
            @p_AuditTable = @f_AuditTable,
            @p_CopyTable = COALESCE(@v_CopyTable, @v_Table),
            @p_TS = @v_IndexTS,
            @p_Ext = @v_Ext;

        EXEC [EPS].[PKG_AUDIT_Sp_CreateTrigger] @p_TableName = @v_Table, @p_AuditName = @f_AuditTable;
    END TRY
    BEGIN CATCH
        EXEC [EPS].[PKG_AUDIT_BuildErrorText]
            @Context = N'PKG_AUDIT_Sp_CreateAudit failed.',
            @ErrorText = @v_error OUTPUT;
        THROW 53008, @v_error, 1;
    END CATCH
END;
GO
