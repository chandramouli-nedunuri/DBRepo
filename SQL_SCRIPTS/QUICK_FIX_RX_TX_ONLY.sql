-- DIRECT FIX FOR RX_TX
-- The PK exists but is not on the partition scheme

USE [sqldb-epr-qa];
GO

PRINT 'RX_TX Fix: Dropping existing PK and recreating on partition scheme...';

BEGIN TRY
    -- Drop the existing non-partitioned PK
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_PK;
    PRINT 'Dropped RX_TX_PK';
    
    -- Create partitioned PK with ON clause
    ALTER TABLE EPS.RX_TX ADD CONSTRAINT PK_RX_TX PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'Created PK_RX_TX on partition scheme - SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO

-- VERIFY
SELECT 
    'RX_TX' as [Table],
    COUNT(DISTINCT partition_number) as [Partitions],
    CASE WHEN COUNT(DISTINCT partition_number) = 6 THEN 'PASS' ELSE 'FAIL' END as [Status]
FROM sys.partitions
WHERE object_id=OBJECT_ID('EPS.RX_TX') AND index_id=1;
