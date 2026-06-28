-- DIAGNOSE DISEASE
USE [sqldb-epr-qa];
GO

PRINT 'Diagnosing DISEASE table...';
PRINT '';

-- Check if table exists
IF OBJECT_ID('EPS.DISEASE') IS NULL
BEGIN
    PRINT 'ERROR: DISEASE table does not exist in EPS schema!';
END
ELSE
BEGIN
    PRINT 'DISEASE table exists.';
    PRINT '';
    
    -- Check PK structure
    PRINT 'Current Primary Key:';
    SELECT 
        CONSTRAINT_NAME,
        COLUMN_NAME,
        ORDINAL_POSITION
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
    WHERE TABLE_NAME = 'DISEASE' AND TABLE_SCHEMA = 'EPS'
    ORDER BY ORDINAL_POSITION;
    
    PRINT '';
    
    -- Check partition count
    PRINT 'Partition information:';
    SELECT 
        COUNT(DISTINCT partition_number) as [Distinct_Partitions],
        COUNT(*) as [Total_Partition_Rows]
    FROM sys.partitions
    WHERE object_id=OBJECT_ID('EPS.DISEASE') AND index_id=1;
    
    PRINT '';
    
    -- Check index details
    PRINT 'Index Details:';
    SELECT 
        i.name as index_name,
        i.type_desc,
        p.partition_scheme_id,
        ps.name as partition_scheme_name
    FROM sys.indexes i
    LEFT JOIN sys.index_partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    LEFT JOIN sys.partition_schemes ps ON p.partition_scheme_id = ps.partition_scheme_id
    WHERE i.object_id = OBJECT_ID('EPS.DISEASE') AND i.index_id = 1;
END
GO
