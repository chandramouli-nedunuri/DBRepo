-- ============================================================================
-- Azure SQL Conversion: EPS.PATIENT_PROGRAM_AUDIT_CSD_23800
-- CSD Variant #3 (Preserved Separately - No Consolidation)
-- Source: Oracle (EPS database)
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-29
-- ============================================================================

-- DECISION: CSD variants preserved separately (not consolidated)
-- This variant is a Conflict-Sensitive Data (CSD) audit table with distinct characteristics
-- Paired with: EPS.PATIENT_PROGRAM_AUDIT (standard audit table)

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID (~25 extended chains)
--       All partitions removed for Azure SQL (non-partitioned implementation)
--       Composite partitioning (LIST + RANGE) strategy removed

CREATE TABLE [EPS].[PATIENT_PROGRAM_AUDIT_CSD_23800]
(
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [NHIN_ID] BIGINT NOT NULL,
    [ECC_PROGRAM_IDENTIFIER] BIGINT NOT NULL,
    [PROGRAM_ADDED_DATE] DATETIME2(6) NOT NULL,
    [OPT_OUT] VARCHAR(1) NULL,
    [DELETED] VARCHAR(1) NULL,
    [DEACTIVATED_DATE] DATETIME2(6) NULL,
    [LAST_UPDATED] DATETIME2(6) NOT NULL,
    [ID_AAL] BIGINT NULL,
    [ID_CREATOR] BIGINT NULL,
    [ID_MODIFIER] BIGINT NULL,
    [DATE_CREATED] DATETIME2(6) NULL,
    [DATE_MODIFIED] DATETIME2(6) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NULL,  -- NOTE: CSD variant has nullable AUDIT_TIMESTAMP (differs from standard audit)
    
    CONSTRAINT [PATIENT_PROGRAM_AUDIT_CSD_23800_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]) WITH (FILLFACTOR = 90),
    CONSTRAINT [PATIENT_PROGRAM_AUDIT_CSD_23800_FK1] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT]) 
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
)
-- NOTE: Oracle storage and tuning parameters removed
-- NOTE: SUPPLEMENTAL LOG DATA clause removed
-- NOTE: All partitioning (LIST by CHAIN_ID) removed
-- CSD MARKER: This is a Conflict-Sensitive Data variant (preserved separately per consolidation decision)
-- Decision Framework: Variants preserved separately (no auto-consolidation to main table)
