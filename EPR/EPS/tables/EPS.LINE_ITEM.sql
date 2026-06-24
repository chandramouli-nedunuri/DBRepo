-- EPS.LINE_ITEM.sql
-- Oracle EPS Database Schema Conversion to Azure SQL Server 2019+
-- Table: EPS.LINE_ITEM
-- Source Lines: 1929 | Columns: 18 | Type: Transaction Detail
-- Conversion Date: 2024 | Status: ✓ CONVERTED
--
-- CONVERSION NOTES:
-- 1. LIST partitioning by CHAIN_ID removed (13+ partitions)
-- 2. Created nonclustered indexes on CHAIN_ID, ID_PATIENT, RX_NUMBER
-- 3. NUMBER(22,0) → BIGINT, NUMBER(38,0) → BIGINT types converted
-- 4. NOLOGGING removed (not applicable in Azure SQL)
-- 5. Compression applied (ROW for transaction data mixed cardinality)
-- 6. No FK constraints present
-- 7. Transaction data includes message source tracking and therapeutic conversions
-- 8. Post-migration: Implement archival for completed transactions
-- ============================================================================

CREATE TABLE [EPS].[LINE_ITEM] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [TASK_ID] BIGINT,
    [NHIN_ID] BIGINT,
    [MRN_REGION_CODE] VARCHAR(20),
    [MRN_ID] VARCHAR(40),
    [RX_STATE] VARCHAR(2),
    [KP_RX_NUM] VARCHAR(35),
    [RX_NUMBER] BIGINT,
    [LAST_UPDATED] DATETIME,
    [ID_AAL] BIGINT,
    [PRESCRIBER_SENDING_APPLICATION] VARCHAR(13),
    [PRESCRIBER_ORDER_NUMBER] VARCHAR(35),
    [THERAPEUTIC_CONVERSION] VARCHAR(1),
    [NON_KP_PRESCRIBER_ORDER_NUMBER] VARCHAR(35),
    [LAST_MESSAGE_SOURCE] VARCHAR(35),
    CONSTRAINT [PK_LINE_ITEM] PRIMARY KEY ([CHAIN_ID], [ID])
);
GO

-- Create indexes for transaction queries
CREATE NONCLUSTERED INDEX [IDX_LINE_ITEM_CHAIN_ID]
    ON [EPS].[LINE_ITEM]([CHAIN_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_LINE_ITEM_PATIENT_ID]
    ON [EPS].[LINE_ITEM]([ID_PATIENT])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_LINE_ITEM_RX_NUMBER]
    ON [EPS].[LINE_ITEM]([RX_NUMBER])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_LINE_ITEM_TASK_ID]
    ON [EPS].[LINE_ITEM]([TASK_ID])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression
ALTER TABLE [EPS].[LINE_ITEM]
    WITH (DATA_COMPRESSION = ROW);
GO

-- Post-deployment actions:
-- 1. Verify migration: SELECT COUNT(*) FROM [EPS].[LINE_ITEM];
-- 2. Check therapeutic conversion codes: SELECT DISTINCT [THERAPEUTIC_CONVERSION] FROM [EPS].[LINE_ITEM];
-- 3. Validate RX_NUMBER references against transaction tables
-- 4. Archive completed line items (LAST_UPDATED > 2 years) to archive schema
-- 5. Create view: vw_LINE_ITEM_PENDING_TRANSACTIONS for active items only
