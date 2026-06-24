-- =====================================================================
-- BATCH TABLE CREATION SCRIPT - BATCH 13
-- =====================================================================
-- Combined tables for single execution
-- Execution Date: 2026-06-10
-- Tables: 26 total (final batch - covers ADDRESS and remaining core tables)
-- Schema: EPS, SEC_ADMIN
-- Note: FK constraints added in separate restoration script
-- Compatible with: DBeaver, SQL Server, Azure SQL
-- Prerequisites: None (can run independently)
-- =====================================================================

-- =====================================================================
-- TABLE 1: EPS.ADDRESS
-- =====================================================================
CREATE TABLE [EPS].[ADDRESS] (
    [CHAIN_ID] NUMERIC(18,0) NOT NULL,
    [ID] NUMERIC(18,0) NOT NULL,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [ADDED] DATETIME,
    [UPDATED] DATETIME,
    [NHIN_ID] NUMERIC(18,0),
    [ADDRESS_KEY] NUMERIC(18,0),
    [ADDRESS_LINE1] VARCHAR(255),
    [ADDRESS_LINE2] VARCHAR(255),
    [ADDRESS_TYPE] NUMERIC(18,0),
    [CITY] VARCHAR(35),
    [CLEAN] CHAR(1),
    [COUNTRY] VARCHAR(4),
    [DEACTIVATION_DATE] DATETIME,
    [ENDING_DATE] DATETIME,
    [VALID] CHAR(1),
    [NOTE1A] VARCHAR(35),
    [NOTE1B] VARCHAR(35),
    [PO_BOX] CHAR(1),
    [POSTAL_CODE] VARCHAR(15),
    [STARTING_DATE] DATETIME,
    [STATE] VARCHAR(2),
    [WORK_AREA_CODE] CHAR(3),
    [WORK_PHONE] VARCHAR(7),
    [HOME_AREA_CODE] CHAR(3),
    [HOME_PHONE] VARCHAR(7),
    [ID_PATIENT] NUMERIC(18,0),
    [ID_AAL] NUMERIC(18,0),
    [CARE_OF] VARCHAR(30),
    [COUNTY] VARCHAR(45),
    [MAIL_STOP] VARCHAR(25),
    [SHIPPING_ADDRESS] VARCHAR(1),
    [ADDRESS_IDENTIFIER] VARCHAR(10),
    [DEFAULT_DELIVERY_SITE] VARCHAR(4),
    [DEFAULT_ADDRESS] VARCHAR(1),
    [WORK_PHONE_UPDATED_DATE] DATETIME2(6),
    [HOME_PHONE_UPDATED_DATE] DATETIME2(6),
    CONSTRAINT [ADDRESS_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 2: EPS.ADDRESS_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[ADDRESS_AUDIT] (
    [CHAIN_ID] NUMERIC(18,0) NOT NULL,
    [ID] NUMERIC(18,0) NOT NULL,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [ADDED] DATETIME,
    [UPDATED] DATETIME,
    [NHIN_ID] NUMERIC(18,0),
    [ADDRESS_KEY] NUMERIC(18,0),
    [ADDRESS_LINE1] VARCHAR(255),
    [ADDRESS_LINE2] VARCHAR(255),
    [ADDRESS_TYPE] NUMERIC(18,0),
    [CITY] VARCHAR(35),
    [CLEAN] CHAR(1),
    [COUNTRY] VARCHAR(4),
    [DEACTIVATION_DATE] DATETIME,
    [ENDING_DATE] DATETIME,
    [VALID] CHAR(1),
    [NOTE1A] VARCHAR(35),
    [NOTE1B] VARCHAR(35),
    [PO_BOX] CHAR(1),
    [POSTAL_CODE] VARCHAR(15),
    [STARTING_DATE] DATETIME,
    [STATE] VARCHAR(2),
    [WORK_AREA_CODE] CHAR(3),
    [WORK_PHONE] VARCHAR(7),
    [HOME_AREA_CODE] CHAR(3),
    [HOME_PHONE] VARCHAR(7),
    [ID_PATIENT] NUMERIC(18,0),
    [ID_AAL] NUMERIC(18,0),
    [CARE_OF] VARCHAR(30),
    [COUNTY] VARCHAR(45),
    [MAIL_STOP] VARCHAR(25),
    [SHIPPING_ADDRESS] VARCHAR(1),
    [ADDRESS_IDENTIFIER] VARCHAR(10),
    [DEFAULT_DELIVERY_SITE] VARCHAR(4),
    [DEFAULT_ADDRESS] VARCHAR(1),
    [WORK_PHONE_UPDATED_DATE] DATETIME2(6),
    [HOME_PHONE_UPDATED_DATE] DATETIME2(6),
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [ADDRESS_AUDIT_PK] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);

-- =====================================================================
-- TABLE 3: EPS.ADMIN_UNLOCK_LOG
-- =====================================================================
CREATE TABLE [EPS].[ADMIN_UNLOCK_LOG] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [REQUESTED] DATETIME,
    [USER_ID] VARCHAR(30),
    [ID_PATIENT] BIGINT
);

-- =====================================================================
-- TABLE 4: EPS.AUDIT_ACCESS_LOG
-- =====================================================================
CREATE TABLE [EPS].[AUDIT_ACCESS_LOG] (
    [ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT NOT NULL,
    [NHIN_ID] BIGINT,
    [ACCESS_DATE] DATETIME NOT NULL,
    [USER_CODE] VARCHAR(30),
    [ACTION_CODE] VARCHAR(10),
    [RECORD_TYPE] VARCHAR(10),
    [RECORD_ID] BIGINT,
    [TABLE_NAME] VARCHAR(30),
    [SESSION_ID] VARCHAR(50),
    CONSTRAINT [AUDIT_ACCESS_LOG_PK] PRIMARY KEY ([ID])
);

-- =====================================================================
-- TABLE 5: EPS.AUDIT_DBU_LOG
-- =====================================================================
CREATE TABLE [EPS].[AUDIT_DBU_LOG] (
    [ID] BIGINT NOT NULL,
    [TIMESTAMP] DATETIME NOT NULL,
    [COMMAND] VARCHAR(MAX),
    [STATUS] VARCHAR(10),
    [USER_ID] VARCHAR(30),
    [SESSION_ID] VARCHAR(50),
    CONSTRAINT [AUDIT_DBU_LOG_PK] PRIMARY KEY ([ID])
);

-- =====================================================================
-- TABLE 6: EPS.AUDIT_MESSAGE_CONTENT
-- =====================================================================
CREATE TABLE [EPS].[AUDIT_MESSAGE_CONTENT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [MESSAGE_CONTENT] VARCHAR(MAX),
    [MESSAGE_TYPE] VARCHAR(50),
    [CREATED_DATE] DATETIME2(6),
    [CREATED_BY] VARCHAR(255),
    CONSTRAINT [AUDIT_MESSAGE_CONTENT_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 7: EPS.AUDIT_PHI_EVENT
-- =====================================================================
CREATE TABLE [EPS].[AUDIT_PHI_EVENT] (
    [ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT NOT NULL,
    [NHIN_ID] BIGINT,
    [ID_PATIENT] BIGINT,
    [EVENT_TYPE] VARCHAR(50),
    [EVENT_DATE] DATETIME2(6) NOT NULL,
    [USER_CODE] VARCHAR(30),
    [SOURCE_CODE] VARCHAR(10),
    [PHI_TYPE] VARCHAR(50),
    [ACTION_CODE] VARCHAR(10),
    CONSTRAINT [AUDIT_PHI_EVENT_PK] PRIMARY KEY ([ID])
);

-- =====================================================================
-- TABLE 8: EPS.AUDIT_USER_LOG
-- =====================================================================
CREATE TABLE [EPS].[AUDIT_USER_LOG] (
    [ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT NOT NULL,
    [USER_CODE] VARCHAR(30),
    [LOGIN_TIME] DATETIME2(6),
    [LOGOUT_TIME] DATETIME2(6),
    [SESSION_ID] VARCHAR(50),
    [IP_ADDRESS] VARCHAR(15),
    [ACTION_LOG] VARCHAR(MAX),
    CONSTRAINT [AUDIT_USER_LOG_PK] PRIMARY KEY ([ID])
);

-- =====================================================================
-- TABLE 9: EPS.ALLERGY
-- =====================================================================
CREATE TABLE [EPS].[ALLERGY] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ADDED] DATETIME,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [BLOOD] CHAR(1),
    [BREATH] CHAR(1),
    [GI_TRACT] CHAR(1),
    [RASH] CHAR(1),
    [REPORT_BY] VARCHAR(2),
    [SHOCK] CHAR(1),
    [START_DATE] DATETIME,
    [UNSPEC] CHAR(1),
    [AC_CODE] VARCHAR(30),
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [CONVERTED] VARCHAR(1),
    CONSTRAINT [ALLERGY_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 10: EPS.ALLERGY_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[ALLERGY_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ADDED] DATETIME,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [BLOOD] CHAR(1),
    [BREATH] CHAR(1),
    [GI_TRACT] CHAR(1),
    [RASH] CHAR(1),
    [REPORT_BY] VARCHAR(2),
    [SHOCK] CHAR(1),
    [START_DATE] DATETIME,
    [UNSPEC] CHAR(1),
    [AC_CODE] VARCHAR(30),
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [CONVERTED] VARCHAR(1),
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [ALLERGY_AUDIT_PK] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);

-- =====================================================================
-- TABLE 11: EPS.ALT_PRESCRIBER
-- =====================================================================
CREATE TABLE [EPS].[ALT_PRESCRIBER] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [PRESCRIBER_CODE] VARCHAR(10),
    [FIRST_NAME] VARCHAR(20),
    [LAST_NAME] VARCHAR(25),
    [DEA] VARCHAR(35),
    [NPI_NUM] VARCHAR(10),
    [STATE] VARCHAR(2),
    [CITY] VARCHAR(35),
    [ZIP] VARCHAR(15),
    [PHONE] VARCHAR(7),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    CONSTRAINT [ALT_PRESCRIBER_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 12: EPS.ALT_PRESCRIBER_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[ALT_PRESCRIBER_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [PRESCRIBER_CODE] VARCHAR(10),
    [FIRST_NAME] VARCHAR(20),
    [LAST_NAME] VARCHAR(25),
    [DEA] VARCHAR(35),
    [NPI_NUM] VARCHAR(10),
    [STATE] VARCHAR(2),
    [CITY] VARCHAR(35),
    [ZIP] VARCHAR(15),
    [PHONE] VARCHAR(7),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [ALT_PRESCRIBER_AUDIT_PK] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);

-- =====================================================================
-- TABLE 13: EPS.CARD
-- =====================================================================
CREATE TABLE [EPS].[CARD] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME,
    [CARD_NUMBER] VARCHAR(20),
    [CARD_TYPE] VARCHAR(10),
    [ISSUE_DATE] DATETIME,
    [EXPIRATION_DATE] DATETIME,
    [ID_AAL] BIGINT,
    [NHIN_ID] BIGINT,
    CONSTRAINT [CARD_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 14: EPS.CARD_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[CARD_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME,
    [CARD_NUMBER] VARCHAR(20),
    [CARD_TYPE] VARCHAR(10),
    [ISSUE_DATE] DATETIME,
    [EXPIRATION_DATE] DATETIME,
    [ID_AAL] BIGINT,
    [NHIN_ID] BIGINT,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [CARD_AUDIT_PK] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);

-- =====================================================================
-- TABLE 15: SEC_ADMIN.EPS_SEC_CHAIN
-- =====================================================================
CREATE TABLE [SEC_ADMIN].[EPS_SEC_CHAIN] (
    [CHAIN_NHIN_ID] BIGINT NOT NULL,
    [CHAIN_NAME] VARCHAR(100),
    [CHAIN_ACTIVE] CHAR(1),
    [CHAIN_TYPE] VARCHAR(10),
    [CREATED_DATE] DATETIME,
    [LAST_UPDATED] DATETIME,
    CONSTRAINT [EPS_SEC_CHAIN_PK] PRIMARY KEY ([CHAIN_NHIN_ID])
);

-- =====================================================================
-- TABLE 16: EPS.EPS_SEC_LOG
-- =====================================================================
CREATE TABLE [EPS].[EPS_SEC_LOG] (
    [ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT,
    [USER_ID] VARCHAR(30),
    [ACTION] VARCHAR(50),
    [TIMESTAMP] DATETIME2(6),
    [IP_ADDRESS] VARCHAR(15),
    [DETAILS] VARCHAR(MAX),
    CONSTRAINT [EPS_SEC_LOG_PK] PRIMARY KEY ([ID])
);

-- =====================================================================
-- TABLE 17: SEC_ADMIN.EPS_SEC_STORE
-- =====================================================================
CREATE TABLE [SEC_ADMIN].[EPS_SEC_STORE] (
    [CHAIN_NHIN_ID] BIGINT NOT NULL,
    [STORE_NHIN_ID] BIGINT NOT NULL,
    [STORE_NAME] VARCHAR(100),
    [STORE_CODE] VARCHAR(10),
    [STORE_ACTIVE] CHAR(1),
    [ADDRESS] VARCHAR(255),
    [CITY] VARCHAR(35),
    [STATE] VARCHAR(2),
    [ZIP] VARCHAR(15),
    [PHONE] VARCHAR(15),
    [CREATED_DATE] DATETIME,
    [LAST_UPDATED] DATETIME,
    CONSTRAINT [EPS_SEC_STORE_PK] PRIMARY KEY ([CHAIN_NHIN_ID], [STORE_NHIN_ID])
);

-- =====================================================================
-- TABLE 18: SEC_ADMIN.EPS_SEC_STORE_IP_ADDRESS
-- =====================================================================
CREATE TABLE [SEC_ADMIN].[EPS_SEC_STORE_IP_ADDRESS] (
    [CHAIN_NHIN_ID] BIGINT NOT NULL,
    [STORE_NHIN_ID] BIGINT NOT NULL,
    [IP_ADDRESS] VARCHAR(15) NOT NULL,
    [IP_ACTIVE] CHAR(1),
    [CREATED_DATE] DATETIME,
    [LAST_UPDATED] DATETIME,
    CONSTRAINT [EPS_SEC_STORE_IP_ADDRESS_PK] PRIMARY KEY ([CHAIN_NHIN_ID], [STORE_NHIN_ID], [IP_ADDRESS])
);

-- =====================================================================
-- TABLE 19: EPS.FDB_PAT_ALLERGY_REACTION_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[FDB_PAT_ALLERGY_REACTION_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT,
    [REACTION_CODE] VARCHAR(10),
    [REACTION_DESCRIPTION] VARCHAR(100),
    [SEVERITY] VARCHAR(20),
    [REACTION_DATE] DATETIME,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [FDB_PAT_ALLERGY_REACTION_AUDIT_PK] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);

-- =====================================================================
-- TABLE 20: EPS.KP_RXNUM_REF
-- =====================================================================
CREATE TABLE [EPS].[KP_RXNUM_REF] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME,
    [ID_AAL] BIGINT,
    [OLD_KP_RX_NUM] VARCHAR(35),
    [KP_RX_NUM] VARCHAR(35),
    [ACTIVE_RX_RX_NUMBER] BIGINT,
    [ACTIVE_RX_NHIN_ID] BIGINT,
    [ACTIVE_RX_FILLED] DATETIME,
    CONSTRAINT [KP_RXNUM_REF_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 21: EPS.LINK_TOKENS
-- =====================================================================
CREATE TABLE [EPS].[LINK_TOKENS] (
    [ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT NOT NULL,
    [TOKEN_VALUE] VARCHAR(500),
    [TOKEN_TYPE] VARCHAR(50),
    [CREATED_DATE] DATETIME2(6),
    [EXPIRES_DATE] DATETIME2(6),
    [USED] CHAR(1),
    [USED_DATE] DATETIME2(6),
    CONSTRAINT [LINK_TOKENS_PK] PRIMARY KEY ([ID])
);

-- =====================================================================
-- TABLE 22: EPS.MATCH_KEY
-- =====================================================================
CREATE TABLE [EPS].[MATCH_KEY] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT,
    [MATCH_KEY_VALUE] VARCHAR(100),
    [MATCH_TYPE] VARCHAR(20),
    [CREATED_DATE] DATETIME,
    [CONFIDENCE_LEVEL] NUMERIC(5,2),
    CONSTRAINT [MATCH_KEY_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 23: EPS.MEDICAL_CONDITION
-- =====================================================================
CREATE TABLE [EPS].[MEDICAL_CONDITION] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT,
    [CONDITION_CODE] VARCHAR(10),
    [CONDITION_NAME] VARCHAR(100),
    [START_DATE] DATETIME,
    [END_DATE] DATETIME,
    [SEVERITY] VARCHAR(20),
    [STATUS] VARCHAR(20),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    CONSTRAINT [MEDICAL_CONDITION_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 24: EPS.MEDICAL_CONDITION_AUDIT_CSD_23800
-- =====================================================================
CREATE TABLE [EPS].[MEDICAL_CONDITION_AUDIT_CSD_23800] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT,
    [CONDITION_CODE] VARCHAR(10),
    [CONDITION_NAME] VARCHAR(100),
    [START_DATE] DATETIME,
    [END_DATE] DATETIME,
    [SEVERITY] VARCHAR(20),
    [STATUS] VARCHAR(20),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [MEDICAL_CONDITION_AUDIT_CSD_PK] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);

-- =====================================================================
-- TABLE 25: EPS.PATIENT
-- =====================================================================
CREATE TABLE [EPS].[PATIENT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [RX_COM_ID] BIGINT,
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [ADDED] DATETIME,
    [LAST] DATETIME,
    [BIRTH_DATE] DATETIME,
    [CATEGORY] CHAR(1),
    [DAW] CHAR(1),
    [DEACTIVATE_DATE] DATETIME,
    [DECEASED_DATE] DATETIME,
    [DISCOUNT] VARCHAR(3),
    [DRIVER_LICENSE] VARCHAR(15),
    [FIRST_NAME] VARCHAR(20),
    [GROUP_NUMBER] CHAR(1),
    [HEIGHT] NUMERIC(8,4),
    [LABEL] VARCHAR(3),
    [LAST_NAME] VARCHAR(25),
    [MARITAL_STATUS] CHAR(1),
    [MEDICAL_RECORD_NUMBER] VARCHAR(35),
    [METRIC_WEIGHT] CHAR(1),
    [MIDDLE_NAME] VARCHAR(20),
    [NO_CF] CHAR(1),
    [NO_COMPLIANCE] CHAR(1),
    [NO_PREFILL] CHAR(1),
    [NO_REF_PREF] CHAR(1),
    [NO_TRANSFER] CHAR(1),
    [NSC] CHAR(1),
    [NUM_LABS] CHAR(1),
    [OMIT_DUR] CHAR(1),
    [PARTIAL_CII_FILL] CHAR(1),
    [PO_BOX] CHAR(1),
    [RACE] CHAR(1),
    [SEX] CHAR(1),
    [SSN] VARCHAR(15),
    [SUB_GROUP] CHAR(1),
    [WEIGHT] NUMERIC(8,4),
    [FOR_DAT] CHAR(1),
    [LANG] VARCHAR(3),
    [MAIL_TYPE] VARCHAR(6),
    [MAJORITY] DATETIME,
    [NO_PAYMENT_REQ] CHAR(1),
    [OTC_PRICE_CODE] VARCHAR(3),
    [PRICE_CODE] VARCHAR(3),
    [SHIP_TYPE] BIGINT,
    [TAXABLE] CHAR(1),
    [BIRTH_DATE_TEXT] VARCHAR(10),
    [RECORDTYPE] BIGINT,
    [ANIMALTYPE] VARCHAR(15),
    [MULTIBIRTH] CHAR(1),
    [PROFESSION] VARCHAR(6),
    [SUFFIX] VARCHAR(6),
    [ID_AAL] BIGINT,
    [SURVIVOR_ID] BIGINT,
    [OLD_CONTRIB_ID] BIGINT,
    [NEW_CONTRIB_ID] BIGINT,
    [MERGED_DATE] DATETIME,
    [UNMERGED_DATE] DATETIME,
    [STORE_CREATED_AT] BIGINT,
    [BOTTLE_COLOR] NUMERIC(2,0),
    [EHR_ID] NUMERIC(22,0),
    [EHR_ENABLED] CHAR(1),
    [IS_LINKED] CHAR(1),
    [LINK_FLAGS] NUMERIC(38,0) DEFAULT 0,
    [LAST_SYNC_TIME] DATETIME,
    [DRIVER_LICENSE_STATE] VARCHAR(6),
    [ALT_PATIENT_ID] VARCHAR(26),
    [ALT_PATIENT_ID_STATE] VARCHAR(6),
    [ALT_PATIENT_ID_TYPE] NUMERIC(5,0),
    [PUELA] VARCHAR(1),
    [DRIVER_LICENSE_ADDENDUM] VARCHAR(5),
    [TP_HIERARCHY_CHANGE] DATETIME,
    [VISUALLY_IMPAIRED] CHAR(1),
    [REQUIRE_DELIVERY_CONFIRMATION] CHAR(1),
    [ACTIVE_MEMBER] CHAR(1),
    [TALKING_VIAL] CHAR(1),
    [LANGUAGE_WRITTEN] CHAR(1),
    [INTERPRETER_REQUIRED] CHAR(1),
    [MEDIGAP_IDENTIFIER] VARCHAR(20),
    [MTM_OPT_OUT] VARCHAR(1),
    [DISPLAY_BOARD] VARCHAR(1),
    [CONTACT_SMS] VARCHAR(1),
    [CONTACT_PHONE] VARCHAR(1),
    [CONTACT_EMAIL] VARCHAR(1),
    [ADMIT_STATUS] VARCHAR(1),
    [ALLERGY_REVIEW_DATE] DATETIME2(6),
    [ALLERGY_REVIEW_EMPLOYEE_NUM] VARCHAR(255),
    [CLINICAL_TRACK_NAME] VARCHAR(80),
    [PASSPORT_IDENTIFICATION] VARCHAR(20),
    [PASSPORT_COUNTRY] VARCHAR(4),
    [MILITARY_IDENTIFICATION] VARCHAR(15),
    [STATE_IDENTIFICATION] VARCHAR(15),
    [STATE_IDENTIFICATION_STATE] VARCHAR(2),
    [DIRECT_MARKETING] VARCHAR(1),
    [DIRECT_MARKETING_UPDATE_DATE] DATETIME2(6),
    [DELIVERY_PREFERENCE] VARCHAR(1),
    [LOYALTY_CARD_NUMBER] VARCHAR(50),
    CONSTRAINT [PATIENT_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 26: EPS.VERSION_MAP
-- =====================================================================
CREATE TABLE [EPS].[VERSION_MAP] (
    [ID] BIGINT NOT NULL,
    [VERSION_NAME] VARCHAR(50),
    [VERSION_NUMBER] VARCHAR(20),
    [RELEASE_DATE] DATETIME,
    [DESCRIPTION] VARCHAR(MAX),
    CONSTRAINT [VERSION_MAP_PK] PRIMARY KEY ([ID])
);

-- =====================================================================
-- All 26 tables created successfully
-- =====================================================================
-- Tables created:
--   1. [EPS].[ADDRESS]
--   2. [EPS].[ADDRESS_AUDIT]
--   3. [EPS].[ADMIN_UNLOCK_LOG]
--   4. [EPS].[AUDIT_ACCESS_LOG]
--   5. [EPS].[AUDIT_DBU_LOG]
--   6. [EPS].[AUDIT_MESSAGE_CONTENT]
--   7. [EPS].[AUDIT_PHI_EVENT]
--   8. [EPS].[AUDIT_USER_LOG]
--   9. [EPS].[ALLERGY]
--  10. [EPS].[ALLERGY_AUDIT]
--  11. [EPS].[ALT_PRESCRIBER]
--  12. [EPS].[ALT_PRESCRIBER_AUDIT]
--  13. [EPS].[CARD]
--  14. [EPS].[CARD_AUDIT]
--  15. [SEC_ADMIN].[EPS_SEC_CHAIN]
--  16. [EPS].[EPS_SEC_LOG]
--  17. [SEC_ADMIN].[EPS_SEC_STORE]
--  18. [SEC_ADMIN].[EPS_SEC_STORE_IP_ADDRESS]
--  19. [EPS].[FDB_PAT_ALLERGY_REACTION_AUDIT]
--  20. [EPS].[KP_RXNUM_REF]
--  21. [EPS].[LINK_TOKENS]
--  22. [EPS].[MATCH_KEY]
--  23. [EPS].[MEDICAL_CONDITION]
--  24. [EPS].[MEDICAL_CONDITION_AUDIT_CSD_23800]
--  25. [EPS].[PATIENT]
--  26. [EPS].[VERSION_MAP]
--
-- Note: Indexes and compression will be created in a separate script
-- FK constraints will be created in BATCH_FK_RESTORATION_BATCH13.sql
-- =====================================================================
