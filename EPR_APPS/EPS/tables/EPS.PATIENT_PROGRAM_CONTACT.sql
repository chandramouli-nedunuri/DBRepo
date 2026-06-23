-- ============================================================================
-- Azure SQL Conversion: EPS.PATIENT_PROGRAM_CONTACT
-- Master Table (Program Contact Registry)
-- Source: Oracle (EPS database)
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-29
-- ============================================================================

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID (~25 extended chains)
--       All partitions removed for Azure SQL (non-partitioned implementation)
--       Partitioning strategy can be reapplied post-migration if needed

CREATE TABLE [EPS].[PATIENT_PROGRAM_CONTACT]
(
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [ID_PROGRAM] BIGINT NOT NULL,
    [CONTACT_POINT] VARCHAR(100) NULL,
    [CONTACT_TYPE] VARCHAR(50) NULL,
    [CONTACT_VALUE] VARCHAR(255) NULL,
    [START_DATE] DATETIME2(6) NULL,
    [END_DATE] DATETIME2(6) NULL,
    [PREFERRED_FLAG] VARCHAR(1) NULL,
    [LAST_UPDATED] DATETIME2(6) NOT NULL,
    [ID_AAL] BIGINT NULL,
    
    CONSTRAINT [PATIENT_PROGRAM_CONTACT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]) WITH (FILLFACTOR = 90),
    CONSTRAINT [PATIENT_PROGRAM_CONTACT_FK1] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT]) 
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID]),
    CONSTRAINT [PATIENT_PROGRAM_CONTACT_FK2] FOREIGN KEY ([CHAIN_ID], [ID_PROGRAM]) 
        REFERENCES [EPS].[PATIENT_PROGRAM] ([CHAIN_ID], [ID])
)
-- NOTE: Oracle storage and tuning parameters removed
-- NOTE: All Oracle partitioning removed (original: LIST by CHAIN_ID with ~25 extended chains)
-- NOTE: Foreign key deferrability not supported (Azure enforces immediately);
--       Pre-migration validation recommended
