-- =====================================================================
-- TABLE: EPS.FDB_PATIENT_ALLERGY
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.FDB_PATIENT_ALLERGY.sql (1,924 lines)
-- 
-- CONVERSION NOTES:
-- ├─ LIST partitioning by CHAIN_ID removed (13 named partitions)
-- ├─ Created nonclustered indexes on CHAIN_ID, ID_PATIENT, and ALLERGY_IDENTIFIER
-- ├─ Oracle storage parameters removed (PCTFREE, INITRANS, TABLESPACE, etc.)
-- ├─ Data type mappings: NUMBER(22,0)→BIGINT, NUMBER(10,0)→INT, TIMESTAMP(6)→DATETIME2(6)
-- ├─ USING INDEX clause removed (Oracle-specific index syntax)
-- └─ No DEFERRABLE foreign keys detected
--
-- PARTITIONING STRATEGY REMOVED:
--   Previous: LIST (CHAIN_ID) with 13 partitions: GEAGLE, ECOM, HANNAF, MEIJER, 
--            RXCOM, SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY, MEDSHP, ACMEHQ
--   Replacement: Nonclustered indexes for partition elimination
--   Note: High-cardinality table (patient allergies) - consider distribution optimization
-- =====================================================================

CREATE TABLE [EPS].[FDB_PATIENT_ALLERGY] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [ALLERGY_TYPE] VARCHAR(20) NOT NULL,
    [ALLERGY_IDENTIFIER] INT NOT NULL,
    [SEVERITY] VARCHAR(255),
    [ALLERGY_CLASSIFICATION] VARCHAR(255),
    [ALLERGY_COMMENT] VARCHAR(300),
    [NHIN_ID] BIGINT,
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME,
    [DELETED] VARCHAR(1),
    [ADDED_BY] VARCHAR(255),
    [ALLERGEN_DESCRIPTION] VARCHAR(255),
    [ADD_DATE] DATETIME2(6),
    CONSTRAINT [PK_FDB_PATIENT_ALLERGY] PRIMARY KEY ([CHAIN_ID], [ID])
);
GO

-- Create indexes for partition key and patient lookup
CREATE NONCLUSTERED INDEX [IDX_FDB_PATIENT_ALLERGY_CHAIN_ID] 
    ON [EPS].[FDB_PATIENT_ALLERGY]([CHAIN_ID])
    INCLUDE ([ID_PATIENT], [ALLERGY_TYPE])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FDB_PATIENT_ALLERGY_PATIENT] 
    ON [EPS].[FDB_PATIENT_ALLERGY]([ID_PATIENT], [CHAIN_ID])
    INCLUDE ([ALLERGY_TYPE], [SEVERITY])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FDB_PATIENT_ALLERGY_ALLERGY_ID] 
    ON [EPS].[FDB_PATIENT_ALLERGY]([ALLERGY_IDENTIFIER])
    INCLUDE ([CHAIN_ID], [ID_PATIENT])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression (PAGE for patient-centric lookup tables)
ALTER TABLE [EPS].[FDB_PATIENT_ALLERGY] 
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Validate [DELETED] column filtering strategy (nulls vs 'N' vs 'Y')
-- 2. Create filtered index for active allergies: WHERE [DELETED] IS NULL
-- 3. Monitor [ID_PATIENT] queries for plan optimization
-- 4. Validate [ALLERGY_IDENTIFIER] foreign key to FDB master table
-- 5. Update application queries to leverage indexes on (ID_PATIENT, ALLERGY_TYPE)
