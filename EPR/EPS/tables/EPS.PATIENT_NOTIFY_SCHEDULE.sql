-- ============================================================================
-- Azure SQL Conversion: EPS.PATIENT_NOTIFY_SCHEDULE
-- Source: Oracle (EPS database)  
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-29
-- ============================================================================

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID with ~25+ partitions
--       All partitions removed for Azure SQL (non-partitioned implementation)
--       Partitioning strategy can be reapplied post-migration if needed

CREATE TABLE [EPS].[PATIENT_NOTIFY_SCHEDULE]
(
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [MESSAGE_TYPE] VARCHAR(1) NULL,
    [DAY_OF_WEEK] VARCHAR(9) NOT NULL,
    [START_TIME] VARCHAR(5) NULL,
    [END_TIME] VARCHAR(5) NULL,
    [PATIENT_TIME_ZONE] VARCHAR(40) NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    [ID_AAL] BIGINT NULL,
    
    CONSTRAINT [PATIENT_NOTIFY_SCHEDULE_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]) WITH (FILLFACTOR = 90),
    CONSTRAINT [PATIENT_NOTIFY_SCHEDULE_UK1] UNIQUE ([CHAIN_ID], [ID_PATIENT], [DAY_OF_WEEK]),
    CONSTRAINT [PATIENT_NOTIFY_SCHEDULE_FK1] FOREIGN KEY ([CHAIN_ID]) 
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [PATIENT_NOTIFY_SCHEDULE_FK2] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT]) 
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
)
-- NOTE: Oracle storage and tuning parameters removed (handled automatically by Azure SQL)
-- NOTE: SUPPLEMENTAL LOG DATA clause removed (not applicable to Azure SQL)
-- NOTE: All Oracle-specific partition definitions removed
-- NOTE: Recommended index strategy: Create nonclustered indexes on CHAIN_ID for query optimization

-- Support Index Recommendations:
-- CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTIFY_SCHEDULE_CHAIN_ID] ON [EPS].[PATIENT_NOTIFY_SCHEDULE] ([CHAIN_ID]);
-- CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTIFY_SCHEDULE_PATIENT_ID] ON [EPS].[PATIENT_NOTIFY_SCHEDULE] ([ID_PATIENT]);
