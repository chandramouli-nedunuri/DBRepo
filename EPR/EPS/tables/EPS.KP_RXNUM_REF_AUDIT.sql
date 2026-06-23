-- EPS.KP_RXNUM_REF_AUDIT.sql
-- Oracle EPS Database Schema Conversion to Azure SQL Server 2019+
-- Table: EPS.KP_RXNUM_REF_AUDIT
-- Source Lines: 3280 | Columns: 11 | Type: Composite Partitioned Audit
-- Conversion Date: 2024 | Status: ✓ CONVERTED
--
-- CONVERSION NOTES:
-- 1. Composite LIST+RANGE partitioning removed (4 chains: GEAGLE, ECOM, HANNAF, MEIJER)
--    with monthly AUDIT_TIMESTAMP subpartitions (2026-04, 2026-05, 2026-06)
-- 2. Created nonclustered indexes on CHAIN_ID and AUDIT_TIMESTAMP
-- 3. SUPPLEMENTAL LOG DATA clause removed (not applicable in Azure SQL)
-- 4. Compression applied (PAGE for large audit table)
-- 5. No FK constraints present
-- 6. Post-migration: Implement monthly RANGE partitioning by AUDIT_TIMESTAMP for archival
-- 7. Recommendation: Archive records older than 24 months to separate schema
-- ============================================================================

CREATE TABLE [EPS].[KP_RXNUM_REF_AUDIT] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [LAST_UPDATED] DATETIME,
    [ID_AAL] BIGINT,
    [OLD_KP_RX_NUM] VARCHAR(35),
    [KP_RX_NUM] VARCHAR(35),
    [ACTIVE_RX_RX_NUMBER] BIGINT,
    [ACTIVE_RX_NHIN_ID] BIGINT,
    [ACTIVE_RX_FILLED] DATETIME,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);
GO

-- Create indexes for audit data retrieval
CREATE NONCLUSTERED INDEX [IDX_KP_RXNUM_REF_AUDIT_CHAIN_ID]
    ON [EPS].[KP_RXNUM_REF_AUDIT]([CHAIN_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_KP_RXNUM_REF_AUDIT_TIMESTAMP]
    ON [EPS].[KP_RXNUM_REF_AUDIT]([AUDIT_TIMESTAMP])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_KP_RXNUM_REF_AUDIT_KP_NUM]
    ON [EPS].[KP_RXNUM_REF_AUDIT]([KP_RX_NUM])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression for space efficiency
ALTER TABLE [EPS].[KP_RXNUM_REF_AUDIT]
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Verify row count: SELECT COUNT(*) FROM [EPS].[KP_RXNUM_REF_AUDIT];
-- 2. Implement RANGE partitioning by AUDIT_TIMESTAMP (monthly sliding window):
--    - Create partition function: RANGE LEFT FOR VALUES ('2025-01-01', '2025-02-01', ... '2026-12-01')
--    - Create partition scheme with FILE GROUPs
--    - Rebuild table with partitioned structure
-- 3. Set up monthly archival job for records > 24 months
-- 4. Create clustered index on (CHAIN_ID, AUDIT_TIMESTAMP) if needed for range queries
