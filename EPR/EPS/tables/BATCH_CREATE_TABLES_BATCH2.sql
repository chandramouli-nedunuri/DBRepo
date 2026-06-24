-- =====================================================================
-- BATCH TABLE CREATION SCRIPT - BATCH 2
-- =====================================================================
-- Combined tables for single execution
-- Execution Date: 2026-06-08
-- Tables: 10 total (CREATE TABLE only)
-- Schema: EPS, SEC_ADMIN
-- Note: Indexes and compression handled in separate script
-- Compatible with: DBeaver, SQL Server, Azure SQL
-- =====================================================================

-- =====================================================================
-- TABLE 1: EPS.DISEASE
-- =====================================================================
CREATE TABLE [EPS].[DISEASE] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [DELETED] CHAR(1),
    [LAST] DATETIME,
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [DS_CODE] VARCHAR(30),
    [DURATION] CHAR(1),
    [ICD9] VARCHAR(10),
    [ICD9_TYPE] CHAR(1),
    [STOP] DATETIME,
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [DIAGNOSIS_QUALIFIER] VARCHAR(2),
    [CONVERTED] VARCHAR(1),
    CONSTRAINT [FK_DISEASE_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_DISEASE_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [FK_DISEASE_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 2: EPS.DISEASE_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[DISEASE_AUDIT] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [DELETED] CHAR(1),
    [LAST] DATETIME,
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [DS_CODE] VARCHAR(30),
    [DURATION] CHAR(1),
    [ICD9] VARCHAR(10),
    [ICD9_TYPE] CHAR(1),
    [STOP] DATETIME,
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [ID_AUDIT] BIGINT,
    [DIAGNOSIS_QUALIFIER] VARCHAR(2),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [CONVERTED] VARCHAR(1)
);

-- =====================================================================
-- TABLE 3: EPS.DW_DATA_EXTRACT_TIMESTAMP
-- =====================================================================
CREATE TABLE [EPS].[DW_DATA_EXTRACT_TIMESTAMP] (
    [PREVIOUS_EXTRACT_TIMESTAMP] DATETIME2(7),
    [CURRENT_EXTRACT_TIMESTAMP] DATETIME2(7)
);

-- =====================================================================
-- TABLE 4: EPS.EMAIL
-- =====================================================================
CREATE TABLE [EPS].[EMAIL] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [LAST_UPDATE] DATETIME,
    [NHIN_ID] BIGINT,
    [EMAIL_ADDRESS] VARCHAR(120),
    [IN_ACTIVE] CHAR(1),
    [LOCATION_TYPE] CHAR(1),
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [SERVICE_VENDOR] NUMERIC(3,0),
    [AUTH_CODE] NUMERIC(5,0),
    [TERMS_OF_SERVICE_DATE] DATETIME2(6),
    CONSTRAINT [FK_EMAIL_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_EMAIL_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [FK_EMAIL_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 5: EPS.EMAIL_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[EMAIL_AUDIT] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [LAST_UPDATE] DATETIME,
    [NHIN_ID] BIGINT,
    [EMAIL_ADDRESS] VARCHAR(120),
    [IN_ACTIVE] CHAR(1),
    [LOCATION_TYPE] CHAR(1),
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [ID_AUDIT] BIGINT,
    [SERVICE_VENDOR] NUMERIC(3,0),
    [AUTH_CODE] NUMERIC(5,0),
    [TERMS_OF_SERVICE_DATE] DATETIME2(6),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- =====================================================================
-- TABLE 6: EPS.FDB_PATIENT_ALLERGY
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

-- =====================================================================
-- TABLE 7: EPS.FDB_PATIENT_ALLERGY_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[FDB_PATIENT_ALLERGY_AUDIT] (
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
    [ID_AUDIT] BIGINT,
    [ALLERGEN_DESCRIPTION] VARCHAR(255),
    [ADD_DATE] DATETIME2(6),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [PK_FDB_PATIENT_ALLERGY_AUDIT] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);

-- =====================================================================
-- TABLE 8: EPS.FDB_PATIENT_ALLERGY_REACTION
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

-- =====================================================================
-- TABLE 9: EPS.FOLLOW_UP_PRESCRIBER
-- =====================================================================
CREATE TABLE [EPS].[FOLLOW_UP_PRESCRIBER] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [ADDRESS] VARCHAR(255),
    [ADDRESS1] VARCHAR(255),
    [ARCHIVE_DATE] DATETIME2(6),
    [AREA_CODE] VARCHAR(3),
    [CITY] VARCHAR(35),
    [COUNTRY] VARCHAR(4),
    [CPM_IDENTIFIER] VARCHAR(7),
    [DEA] VARCHAR(35),
    [DELETED] VARCHAR(1),
    [FAX_AREA_CODE] VARCHAR(15),
    [FAX_PHONE] VARCHAR(7),
    [FIRST_NAME] VARCHAR(20),
    [HCID] VARCHAR(10),
    [HMS_IDENTIFIER] VARCHAR(10),
    [ID_AAL] BIGINT,
    [LAST_NAME] VARCHAR(25),
    [LAST_UPDATED] DATETIME2(6),
    [MIDDLE_NAME] VARCHAR(20),
    [NAME] VARCHAR(28),
    [NHIN_ID] BIGINT,
    [NPI_NUM] VARCHAR(10),
    [PHONE] VARCHAR(7),
    [STATE] VARCHAR(2),
    [STATE_IDENTIFIER] VARCHAR(25),
    [ZIP] VARCHAR(15),
    CONSTRAINT [PK_FOLLOW_UP_PRESCRIBER] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 10: EPS.FOLLOW_UP_PRESCRIBER_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[FOLLOW_UP_PRESCRIBER_AUDIT] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [ADDRESS] VARCHAR(255),
    [ADDRESS1] VARCHAR(255),
    [ARCHIVE_DATE] DATETIME2(6),
    [AREA_CODE] VARCHAR(3),
    [CITY] VARCHAR(35),
    [COUNTRY] VARCHAR(4),
    [CPM_IDENTIFIER] VARCHAR(7),
    [DEA] VARCHAR(35),
    [DELETED] VARCHAR(1),
    [FAX_AREA_CODE] VARCHAR(15),
    [FAX_PHONE] VARCHAR(7),
    [FIRST_NAME] VARCHAR(20),
    [HCID] VARCHAR(10),
    [HMS_IDENTIFIER] VARCHAR(10),
    [ID_AAL] BIGINT,
    [LAST_NAME] VARCHAR(25),
    [LAST_UPDATED] DATETIME2(6),
    [MIDDLE_NAME] VARCHAR(20),
    [NAME] VARCHAR(28),
    [NHIN_ID] BIGINT,
    [NPI_NUM] VARCHAR(10),
    [PHONE] VARCHAR(7),
    [STATE] VARCHAR(2),
    [STATE_IDENTIFIER] VARCHAR(25),
    [ZIP] VARCHAR(15),
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6),
    CONSTRAINT [PK_FOLLOW_UP_PRESCRIBER_AUDIT] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);

-- =====================================================================
-- All 10 tables created successfully
-- =====================================================================
-- Tables created:
--   1. [EPS].[DISEASE]
--   2. [EPS].[DISEASE_AUDIT]
--   3. [EPS].[DW_DATA_EXTRACT_TIMESTAMP]
--   4. [EPS].[EMAIL]
--   5. [EPS].[EMAIL_AUDIT]
--   6. [EPS].[FDB_PATIENT_ALLERGY]
--   7. [EPS].[FDB_PATIENT_ALLERGY_AUDIT]
--   8. [EPS].[FDB_PATIENT_ALLERGY_REACTION]
--   9. [EPS].[FOLLOW_UP_PRESCRIBER]
--  10. [EPS].[FOLLOW_UP_PRESCRIBER_AUDIT]
--
-- Note: Indexes and compression will be created in a separate script
-- =====================================================================
