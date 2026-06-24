-- =====================================================================
-- TABLE: EPS.FREE_FORM_ALLERGY
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.FREE_FORM_ALLERGY.sql (1,925 lines)
-- 
-- CONVERSION NOTES:
-- ├─ LIST partitioning by CHAIN_ID removed (13 named partitions)
-- ├─ Created nonclustered indexes on CHAIN_ID and ID_PATIENT
-- ├─ Oracle storage parameters removed (PCTFREE, INITRANS, TABLESPACE, etc.)
-- ├─ Data type mappings: NUMBER→BIGINT, TIMESTAMP(6)→DATETIME2(6), VARCHAR2→VARCHAR
-- ├─ USING INDEX clause removed (Oracle-specific index syntax)
-- └─ No DEFERRABLE foreign keys detected
--
-- PARTITIONING STRATEGY REMOVED:
--   Previous: LIST (CHAIN_ID) with 13 partitions: GEAGLE, ECOM, HANNAF, MEIJER, 
--            RXCOM, SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY, MEDSHP, ACMEHQ
--   Replacement: Nonclustered indexes for partition elimination
--   Note: Free-form text allergies require validation and NLP processing
-- =====================================================================

CREATE TABLE [EPS].[FREE_FORM_ALLERGY] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [DESCRIPTION] VARCHAR(255) NOT NULL,
    [SEVERITY] VARCHAR(255),
    [ALLERGY_CLASSIFICATION] VARCHAR(255),
    [ALLERGY_COMMENT] VARCHAR(300),
    [ADDED_BY] VARCHAR(255),
    [NHIN_ID] BIGINT,
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME,
    [DELETED] VARCHAR(1),
    [ADD_DATE] DATETIME2(6),
    CONSTRAINT [PK_FREE_FORM_ALLERGY] PRIMARY KEY ([CHAIN_ID], [ID])
);
GO

-- Create indexes for partition key and patient lookup
CREATE NONCLUSTERED INDEX [IDX_FREE_FORM_ALLERGY_CHAIN_ID] 
    ON [EPS].[FREE_FORM_ALLERGY]([CHAIN_ID])
    INCLUDE ([ID_PATIENT], [DESCRIPTION])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FREE_FORM_ALLERGY_PATIENT] 
    ON [EPS].[FREE_FORM_ALLERGY]([ID_PATIENT], [CHAIN_ID])
    INCLUDE ([DESCRIPTION], [SEVERITY])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression (PAGE for text-based allergy descriptions)
ALTER TABLE [EPS].[FREE_FORM_ALLERGY] 
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Create full-text search index on [DESCRIPTION] for allergy text matching
-- 2. Validate [DESCRIPTION] varchar(255) length vs Oracle source (watch for truncation)
-- 3. Create filtered index for active allergies: WHERE [DELETED] IS NULL
-- 4. Implement data quality checks for free-form text consistency
-- 5. Monitor [ID_PATIENT] lookup performance and update application queries
-- 6. Consider NLP/NER processing for standardizing free-form descriptions to codified allergies
