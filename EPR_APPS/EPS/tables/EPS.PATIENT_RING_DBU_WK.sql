-- ============================================================================
-- Azure SQL Conversion: EPS.PATIENT_RING_DBU_WK
-- Utility/Work Table (Ring DBU Processing)
-- Source: Oracle (EPS database)
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-29
-- ============================================================================

-- NOTE: Simple non-partitioned utility table
-- Purpose: Database Unit (DBU) work queue for data replication processing
-- NOTE: SUPPLEMENTAL LOG DATA clause removed (not applicable to Azure SQL)

CREATE TABLE [EPS].[PATIENT_RING_DBU_WK]
(
    [CHAIN_ID] BIGINT NULL,
    [NHIN_ID] BIGINT NULL,
    [PROCESSED_DATE] DATETIME2(6) NULL,
    
    CONSTRAINT [PATIENT_RING_DBU_WK_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [NHIN_ID])
)
-- NOTE: Oracle storage and tuning parameters removed
-- NOTE: SEGMENT CREATION DEFERRED removed (not applicable to Azure)
-- NOTE: COMPUTE STATISTICS removed (Azure handles statistics automatically)
-- Utility Table: This is a work queue table typically purged after processing
