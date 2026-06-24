-- =====================================================================
-- TABLE: EPS.FDB_PATIENT_ALLERGY_REACTION
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.FDB_PATIENT_ALLERGY_REACTION.sql (1,912 lines)
-- 
-- CONVERSION NOTES:
-- ├─ LIST partitioning by CHAIN_ID removed (13 named partitions)
-- ├─ Created nonclustered indexes on CHAIN_ID and FDB_ALLERGY_ID
-- ├─ Oracle storage parameters removed (PCTFREE, INITRANS, TABLESPACE, etc.)
-- ├─ Data type mappings: NUMBER(22,0)→BIGINT, VARCHAR2→VARCHAR
-- ├─ USING INDEX clause removed (Oracle-specific index syntax)
-- └─ No DEFERRABLE foreign keys detected
--
-- PARTITIONING STRATEGY REMOVED:
--   Previous: LIST (CHAIN_ID) with 14 partitions: GEAGLE, ECOM, HANNAF, MEIJER, 
--            RXCOM, SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY, MEDSHP, ACMEHQ, SPRVAL
--   Replacement: Nonclustered indexes for partition elimination effect
--   Note: Consider if CHAIN_ID distribution is unbalanced for hash partitioning
-- =====================================================================

CREATE TABLE [EPS].[FDB_PATIENT_ALLERGY_REACTION] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [FDB_ALLERGY_ID] BIGINT NOT NULL,
    [REACTION_DESCRIPTION] VARCHAR(255) NOT NULL,
    [LAST_UPDATED] DATETIME,
    [DELETED] VARCHAR(1),
    [ID_AAL] BIGINT,
    CONSTRAINT [PK_FDB_PATIENT_ALLERGY_REACTION] PRIMARY KEY ([CHAIN_ID], [ID])
);
GO

-- Create indexes for partition key and FDB lookup
CREATE NONCLUSTERED INDEX [IDX_FDB_PATIENT_ALLERGY_REACTION_CHAIN_ID] 
    ON [EPS].[FDB_PATIENT_ALLERGY_REACTION]([CHAIN_ID])
    INCLUDE ([ID], [FDB_ALLERGY_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FDB_PATIENT_ALLERGY_REACTION_FDB_ID] 
    ON [EPS].[FDB_PATIENT_ALLERGY_REACTION]([FDB_ALLERGY_ID])
    INCLUDE ([CHAIN_ID], [ID])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression (ROW for smaller detail tables)
ALTER TABLE [EPS].[FDB_PATIENT_ALLERGY_REACTION] 
    WITH (DATA_COMPRESSION = ROW);
GO

-- Post-deployment actions:
-- 1. Validate FDB_ALLERGY_ID foreign key exists (should reference FDB master table)
-- 2. Monitor CHAIN_ID distribution across index - consider hash partitioning if skewed
-- 3. Verify query plans using partitioning elimination for multi-chain queries
-- 4. Test insert/update performance compared to Oracle source
