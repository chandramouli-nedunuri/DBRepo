-- =====================================================================
-- BATCH TABLE CREATION SCRIPT - BATCH 4
-- =====================================================================
-- Combined tables for single execution
-- Execution Date: 2026-06-08
-- Tables: 6 total (CREATE TABLE only)
-- Schema: EPS, SEC_ADMIN
-- Note: Indexes and compression handled in separate script
-- Compatible with: DBeaver, SQL Server, Azure SQL
-- 
-- MISSING TABLES (not found in project):
--   - LINK_TOKENS (file not found)
--   - MATCH_KEY (file not found - only AUDIT available)
--   - MEDICAL_CONDITION (file not found - only AUDIT available)
--   - MEDICAL_CONDITION_AUDIT_CSD_23800 (file not found)
-- =====================================================================

-- =====================================================================
-- TABLE 1: EPS.MATCH_KEY_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[MATCH_KEY_AUDIT] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [MATCH_TYPE] BIGINT,
    [MATCH_VALUE] VARCHAR(16),
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- =====================================================================
-- TABLE 2: EPS.MEDICAL_CONDITION_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[MEDICAL_CONDITION_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [NHIN_ID] BIGINT,
    [LAST_UPDATED] DATETIME2(6),
    [MEDICAL_CONDITION_CODE] BIGINT,
    [ICD10] VARCHAR(15),
    [LAST] DATETIME2(6),
    [STOP] DATETIME2(6),
    [DELETED] VARCHAR(1),
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [ID_AAL] BIGINT,
    [DURATION] VARCHAR(1)
);

-- =====================================================================
-- TABLE 3: EPS.MOD_PCM
-- =====================================================================
CREATE TABLE [EPS].[MOD_PCM] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1) NULL,
    [LAST_UPDATED] DATETIME NULL,
    [NHIN_ID] BIGINT NULL,
    [LABEL1A] VARCHAR(25) NULL,
    [LABEL2A] VARCHAR(25) NULL,
    [LABEL3A] VARCHAR(25) NULL,
    [LABEL4A] VARCHAR(25) NULL,
    [LABEL5A] VARCHAR(25) NULL,
    [LABEL6A] VARCHAR(25) NULL,
    [LABEL7A] VARCHAR(25) NULL,
    [LABEL8A] VARCHAR(25) NULL,
    [LABEL1B] VARCHAR(25) NULL,
    [LABEL2B] VARCHAR(25) NULL,
    [LABEL3B] VARCHAR(25) NULL,
    [LABEL4B] VARCHAR(25) NULL,
    [LABEL5B] VARCHAR(25) NULL,
    [LABEL6B] VARCHAR(25) NULL,
    [LABEL7B] VARCHAR(25) NULL,
    [LABEL8B] VARCHAR(25) NULL,
    [ID_AAL] INT NULL,
    [ARCHIVE_DATE] DATETIME NULL,
    CONSTRAINT [MOD_PCM_FK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [MOD_PCM_FK_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [PK_MOD_PCM] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 4: EPS.MOD_PCM_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[MOD_PCM_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1) NULL,
    [LAST_UPDATED] DATETIME NULL,
    [NHIN_ID] BIGINT NULL,
    [LABEL1A] VARCHAR(25) NULL,
    [LABEL2A] VARCHAR(25) NULL,
    [LABEL3A] VARCHAR(25) NULL,
    [LABEL4A] VARCHAR(25) NULL,
    [LABEL5A] VARCHAR(25) NULL,
    [LABEL6A] VARCHAR(25) NULL,
    [LABEL7A] VARCHAR(25) NULL,
    [LABEL8A] VARCHAR(25) NULL,
    [LABEL1B] VARCHAR(25) NULL,
    [LABEL2B] VARCHAR(25) NULL,
    [LABEL3B] VARCHAR(25) NULL,
    [LABEL4B] VARCHAR(25) NULL,
    [LABEL5B] VARCHAR(25) NULL,
    [LABEL6B] VARCHAR(25) NULL,
    [LABEL7B] VARCHAR(25) NULL,
    [LABEL8B] VARCHAR(25) NULL,
    [ID_AAL] INT NULL,
    [ID_AUDIT] INT NULL,
    [ARCHIVE_DATE] DATETIME NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- =====================================================================
-- TABLE 5: EPS.MRN
-- =====================================================================
CREATE TABLE [EPS].[MRN] (
    [CHAIN_ID] BIGINT NOT NULL,
    [LOCATION_CODE] VARCHAR(20) NOT NULL,
    [ID] VARCHAR(40) NOT NULL,
    [ID_PATIENT] BIGINT NULL,
    [ID_AAL] BIGINT NULL,
    [ROOT_ID] BIGINT NULL,
    [HOME] CHAR(1) NULL,
    [LAST_UPDATED] DATETIME NULL,
    [BAD] CHAR(1) NULL,
    CONSTRAINT [MRN_PK] PRIMARY KEY ([CHAIN_ID], [LOCATION_CODE], [ID])
);

-- =====================================================================
-- TABLE 6: EPS.MRN_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[MRN_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [LOCATION_CODE] VARCHAR(20) NOT NULL,
    [ID] VARCHAR(40) NOT NULL,
    [ID_PATIENT] BIGINT NULL,
    [ID_AAL] BIGINT NULL,
    [ROOT_ID] BIGINT NULL,
    [HOME] CHAR(1) NULL,
    [LAST_UPDATED] DATETIME NULL,
    [ID_AUDIT] INT NULL,
    [BAD] CHAR(1) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- =====================================================================
-- All 6 tables created successfully
-- =====================================================================
-- Tables created:
--   1. [EPS].[MATCH_KEY_AUDIT]
--   2. [EPS].[MEDICAL_CONDITION_AUDIT]
--   3. [EPS].[MOD_PCM]
--   4. [EPS].[MOD_PCM_AUDIT]
--   5. [EPS].[MRN]
--   6. [EPS].[MRN_AUDIT]
--
-- Note: Indexes and compression will be created in a separate script
-- =====================================================================
