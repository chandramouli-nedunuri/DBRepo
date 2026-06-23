-- ============================================================================
-- Azure SQL Conversion: EPS.PATIENT_PROGRAM_AUDIT
-- Standard Audit Table (paired with CSD_23800 variant)
-- Source: Oracle (EPS database)
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-29
-- ============================================================================

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID (~25 extended chains)
--       All partitions removed for Azure SQL (non-partitioned implementation)
--       Composite partitioning strategy removed

CREATE TABLE [EPS].[PATIENT_PROGRAM_AUDIT]
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
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,  -- Standard audit has mandatory AUDIT_TIMESTAMP
    
    CONSTRAINT [PATIENT_PROGRAM_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]) WITH (FILLFACTOR = 90),
    CONSTRAINT [PATIENT_PROGRAM_AUDIT_FK1] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT]) 
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
)
-- NOTE: Oracle storage and tuning parameters removed
-- NOTE: SUPPLEMENTAL LOG DATA clause removed
-- NOTE: All Oracle partitioning removed (original: LIST by CHAIN_ID with ~25 extended chains)
-- Paired Audit: This is the standard audit table; see PATIENT_PROGRAM_AUDIT_CSD_23800 for CSD variant
