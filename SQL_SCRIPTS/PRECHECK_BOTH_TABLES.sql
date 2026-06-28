-- PRE-CHECK QUERIES FOR RX_TX AND DISEASE

USE [sqldb-epr-qa];
GO

PRINT '========== RX_TX PRE-CHECK ==========';
SELECT 
    CONSTRAINT_NAME,
    COLUMN_NAME,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'RX_TX' AND TABLE_SCHEMA = 'EPS'
ORDER BY ORDINAL_POSITION;

SELECT 
    COUNT(DISTINCT partition_number) as partition_count
FROM sys.partitions
WHERE object_id=OBJECT_ID('EPS.RX_TX') AND index_id=1;

PRINT '';
PRINT '========== DISEASE PRE-CHECK ==========';

IF OBJECT_ID('EPS.DISEASE') IS NULL
BEGIN
    PRINT 'ERROR: DISEASE table does not exist in EPS schema!';
END
ELSE
BEGIN
    PRINT 'DISEASE Primary Key:';
    SELECT 
        CONSTRAINT_NAME,
        COLUMN_NAME,
        ORDINAL_POSITION
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
    WHERE TABLE_NAME = 'DISEASE' AND TABLE_SCHEMA = 'EPS'
    ORDER BY ORDINAL_POSITION;
    
    PRINT '';
    PRINT 'DISEASE Partition Count:';
    SELECT 
        COUNT(DISTINCT partition_number) as partition_count
    FROM sys.partitions
    WHERE object_id=OBJECT_ID('EPS.DISEASE') AND index_id=1;
    
    PRINT '';
    PRINT 'DISEASE Index Details:';
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
