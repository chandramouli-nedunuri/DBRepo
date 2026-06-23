-- ============================================================================
-- Azure SQL Conversion: EPS.PATIENT_PROGRAM
-- Master Transaction Table (Patient Program Enrollment)
-- Source: Oracle (EPS database)
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-29
-- ============================================================================

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID (~25 extended chains)
--       All partitions removed for Azure SQL (non-partitioned implementation)
--       REVERSE INDEX converted to normal index with FILLFACTOR = 70
--       REVERSE index prevents hot-block contention; FILLFACTOR achieves similar effect

CREATE TABLE [EPS].[PATIENT_PROGRAM]
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
    
    CONSTRAINT [PATIENT_PROGRAM_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]) WITH (FILLFACTOR = 70),
    CONSTRAINT [PATIENT_PROGRAM_FK1] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT]) 
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
)
-- NOTE: Oracle storage and tuning parameters removed
-- NOTE: SUPPLEMENTAL LOG DATA clause removed
-- NOTE: All Oracle partitioning removed (original: LIST by CHAIN_ID with ~25 extended chains)
-- REVERSE INDEX CONVERSION: Oracle REVERSE index removed (prevent hot-block contention)
--     Azure Equivalent: FILLFACTOR = 70 set on primary key index
--     Effect: Slows page splits for sequential insert patterns
--     Monitoring: Track page split counts post-migration; fine-tune FILLFACTOR if needed (60-80 range typical)
-- NOTE: Foreign key deferrability not supported (Azure enforces immediately)

-- Post-Migration Index Recommendations (if performance tuning needed):
-- CREATE NONCLUSTERED INDEX [IX_PATIENT_PROGRAM_CHAIN_ID] ON [EPS].[PATIENT_PROGRAM] ([CHAIN_ID]);
-- CREATE NONCLUSTERED INDEX [IX_PATIENT_PROGRAM_PATIENT_ID] ON [EPS].[PATIENT_PROGRAM] ([ID_PATIENT]);
