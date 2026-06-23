-- =====================================================================
-- BATCH TABLE CREATION SCRIPT - BATCH 3
-- =====================================================================
-- Combined tables for single execution
-- Execution Date: 2026-06-08
-- Tables: 8 total (CREATE TABLE only)
-- Schema: EPS, SEC_ADMIN
-- Note: Indexes and compression handled in separate script
-- Compatible with: DBeaver, SQL Server, Azure SQL
-- 
-- MISSING TABLES (not found in project):
--   - KP_RXNUM_REF (only KP_RXNUM_REF_AUDIT available)
--   - LINK_TOKENS (file not found)
-- =====================================================================

-- =====================================================================
-- TABLE 1: EPS.FOLLOW_UP_PRESCRIBER_AUDIT
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
-- TABLE 2: EPS.FREE_FORM_ALLERGY
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

-- =====================================================================
-- TABLE 3: EPS.FREE_FORM_ALLERGY_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[FREE_FORM_ALLERGY_AUDIT] (
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
    [ID_AUDIT] BIGINT,
    [ADD_DATE] DATETIME2(6),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [PK_FREE_FORM_ALLERGY_AUDIT] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);

-- =====================================================================
-- TABLE 4: EPS.IDGEN
-- =====================================================================
CREATE TABLE [EPS].[IDGEN] (
    [CHAIN_ID] BIGINT,
    [NAME] VARCHAR(100),
    [NEXT_ID] BIGINT,
    CONSTRAINT [FK_IDGEN_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
);

-- =====================================================================
-- TABLE 5: EPS.IDGEN_TEMP
-- =====================================================================
CREATE TABLE [EPS].[IDGEN_TEMP] (
    [CHAIN_ID] BIGINT,
    [NAME] VARCHAR(100),
    [NEXT_ID] BIGINT
);

-- =====================================================================
-- TABLE 6: EPS.INTAKE_SOURCES
-- =====================================================================
CREATE TABLE [EPS].[INTAKE_SOURCES] (
    [ID] BIGINT,
    [CHAIN_ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [SOURCE_TYPE] VARCHAR(50),
    [SOURCE_FILE_NAME] VARCHAR(255),
    [SOURCE_EXECUTION_TIME] DATETIME2(6),
    [ACTION_TYPE] VARCHAR(50),
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME2(6),
    CONSTRAINT [PK_INTAKE_SOURCES] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 7: EPS.KP_RXNUM_REF_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[KP_RXNUM_REF_AUDIT] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [LAST_UPDATED] DATETIME,
    [ID_AAL] BIGINT,
    [OLD_KP_RX_NUM] VARCHAR(35),
    [KP_RX_NUM] VARCHAR(35),
    [ACTIVE_RX_RX_NUMBER] BIGINT,
    [ACTIVE_RX_NHIN_ID] BIGINT,
    [ACTIVE_RX_FILLED] DATETIME,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- =====================================================================
-- TABLE 8: EPS.LINE_ITEM
-- =====================================================================
CREATE TABLE [EPS].[LINE_ITEM] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [TASK_ID] BIGINT,
    [NHIN_ID] BIGINT,
    [MRN_REGION_CODE] VARCHAR(20),
    [MRN_ID] VARCHAR(40),
    [RX_STATE] VARCHAR(2),
    [KP_RX_NUM] VARCHAR(35),
    [RX_NUMBER] BIGINT,
    [LAST_UPDATED] DATETIME,
    [ID_AAL] BIGINT,
    [PRESCRIBER_SENDING_APPLICATION] VARCHAR(13),
    [PRESCRIBER_ORDER_NUMBER] VARCHAR(35),
    [THERAPEUTIC_CONVERSION] VARCHAR(1),
    [NON_KP_PRESCRIBER_ORDER_NUMBER] VARCHAR(35),
    [LAST_MESSAGE_SOURCE] VARCHAR(35),
    CONSTRAINT [PK_LINE_ITEM] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- All 8 tables created successfully
-- =====================================================================
-- Tables created:
--   1. [EPS].[FOLLOW_UP_PRESCRIBER_AUDIT]
--   2. [EPS].[FREE_FORM_ALLERGY]
--   3. [EPS].[FREE_FORM_ALLERGY_AUDIT]
--   4. [EPS].[IDGEN]
--   5. [EPS].[IDGEN_TEMP]
--   6. [EPS].[INTAKE_SOURCES]
--   7. [EPS].[KP_RXNUM_REF_AUDIT]
--   8. [EPS].[LINE_ITEM]
--
-- Note: Indexes and compression will be created in a separate script
-- =====================================================================
