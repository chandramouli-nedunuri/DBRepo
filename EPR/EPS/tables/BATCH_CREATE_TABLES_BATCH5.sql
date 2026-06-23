-- =====================================================================
-- BATCH TABLE CREATION SCRIPT - BATCH 5
-- =====================================================================
-- Combined tables for single execution
-- Execution Date: 2026-06-08
-- Tables: 7 total (CREATE TABLE only)
-- Schema: EPS, SEC_ADMIN
-- Note: Indexes and compression handled in separate script
-- Compatible with: DBeaver, SQL Server, Azure SQL
-- 
-- PREREQUISITE TABLES (must exist before executing):
--   - [SEC_ADMIN].[EPS_SEC_CHAIN]  (referenced by all tables)
--   - [EPS].[SIGNATURE]             (referenced by MTM_PATIENT_SESSION, FK removed - add via ALTER TABLE after SIGNATURE exists)
-- =====================================================================

-- =====================================================================
-- TABLE 1: EPS.MTM_PATIENT_SESSION (REORDERED - must exist before MTM_PATIENT_ANSWERS)
-- =====================================================================
CREATE TABLE [EPS].[MTM_PATIENT_SESSION] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [RUN_DATE] DATETIME NULL,
    [SCORE] NUMERIC(13, 4) NULL,
    [SCORE_TEXT] VARCHAR(2000) NULL,
    [STATUS] NUMERIC(1, 0) NULL,
    [ID_SIGNATURE] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME NULL,
    CONSTRAINT [MTM_PATIENT_SESSION_FK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    -- NOTE: FK to EPS.SIGNATURE([CHAIN_ID], [ID]) removed - SIGNATURE table must be created first as separate prerequisite
    -- To add this FK after SIGNATURE exists, execute: ALTER TABLE [EPS].[MTM_PATIENT_SESSION] 
    --   ADD CONSTRAINT [MTM_PATIENT_SESSION_FK_SIGN] FOREIGN KEY ([CHAIN_ID], [ID_SIGNATURE]) 
    --   REFERENCES [EPS].[SIGNATURE] ([CHAIN_ID], [ID]);
    CONSTRAINT [PK_MTM_PATIENT_SESSION] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 2: EPS.MTM_PATIENT_SESSION_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[MTM_PATIENT_SESSION_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [RUN_DATE] DATETIME NULL,
    [SCORE] NUMERIC(13, 4) NULL,
    [SCORE_TEXT] VARCHAR(2000) NULL,
    [STATUS] NUMERIC(1, 0) NULL,
    [ID_SIGNATURE] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME NULL,
    [ID_AUDIT] BIGINT NOT NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- =====================================================================
-- TABLE 3: EPS.MTM_PATIENT_ANSWERS (REORDERED - now references existing MTM_PATIENT_SESSION)
-- =====================================================================
CREATE TABLE [EPS].[MTM_PATIENT_ANSWERS] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ANSWER_SEQUENCE] NUMERIC(3, 0) NULL,
    [QUESTION_VERSION] NUMERIC(10, 0) NULL,
    [RX_COM_QUESTION_NUMBER] NUMERIC(10, 0) NULL,
    [ID_MTM_PATIENT_SESSION] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME NULL,
    CONSTRAINT [MTM_PATIENT_ANSWERS_FK_SESS] FOREIGN KEY ([CHAIN_ID], [ID_MTM_PATIENT_SESSION])
        REFERENCES [EPS].[MTM_PATIENT_SESSION] ([CHAIN_ID], [ID]),
    CONSTRAINT [MTM_PATIENT_ANSWERS_FK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [PK_MTM_PATIENT_ANSWERS] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 4: EPS.MTM_PATIENT_ANSWERS_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[MTM_PATIENT_ANSWERS_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ANSWER_SEQUENCE] NUMERIC(3, 0) NULL,
    [QUESTION_VERSION] NUMERIC(10, 0) NULL,
    [RX_COM_QUESTION_NUMBER] NUMERIC(10, 0) NULL,
    [ID_MTM_PATIENT_SESSION] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME NULL,
    [ID_AUDIT] BIGINT NOT NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- =====================================================================
-- TABLE 5: EPS.MTM_PATIENT_ELIGIBILITY
-- =====================================================================
CREATE TABLE [EPS].[MTM_PATIENT_ELIGIBILITY] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [RX_COM_ID] BIGINT NOT NULL,
    [DELIVERY_OF_SERVICE_DATE] DATETIME2(6) NULL,
    [ID_AAL] BIGINT NULL,
    [LAST_UPDATED] DATETIME NULL,
    [VENDOR_IDENTIFIER] VARCHAR(10) NOT NULL,
    [ELIGIBILITY_URL] VARCHAR(2000) NULL,
    CONSTRAINT [MTM_PATIENT_ELIGIBILITY_PK] PRIMARY KEY ([CHAIN_ID], [ID]),
    CONSTRAINT [MTM_PATIENT_ELIGIBILITY_FK1] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
);

-- =====================================================================
-- TABLE 6: EPS.PACKAGE_INFO
-- =====================================================================
CREATE TABLE [EPS].[PACKAGE_INFO] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [SHIP_DATE] DATETIME NULL,
    [PACKER_INITIALS] VARCHAR(3) NULL,
    [PACKER_NUM] VARCHAR(38) NULL,
    [MANIFEST_INITIALS] VARCHAR(3) NULL,
    [MANIFEST_NUM] VARCHAR(10) NULL,
    [TRACKING_NUMBER] VARCHAR(28) NULL,
    [WEIGHT] NUMERIC(13, 4) NULL,
    [SHIPPER_NAME] VARCHAR(64) NULL,
    [ACTUAL_SHIP_COST] NUMERIC(13, 2) NULL,
    [CF_SYSTEM_PACKAGE_NUMBER] VARCHAR(24) NULL,
    [AVERAGE_SHIPPING_COST] NUMERIC(13, 2) NULL,
    [CF_FACILITY_NAME] VARCHAR(28) NULL,
    [CF_SYSTEM_ORDER_NUMBER] NUMERIC(38, 0) NULL,
    [SHIP_TO_ADDRESS_LINE_1] VARCHAR(255) NULL,
    [SHIP_TO_CITY] VARCHAR(35) NULL,
    [SHIP_TO_POSTAL_CODE] VARCHAR(15) NULL,
    [SHIP_TO_STATE] VARCHAR(2) NULL,
    [ID_AAL] BIGINT NULL,
    [LAST_UPDATED] DATETIME NULL,
    [ID_RX_TX] BIGINT NOT NULL,
    [SHIP_TO_ADDRESS_LINE_2] VARCHAR(255) NULL,
    [SHIP_TO_CARE_OF] VARCHAR(100) NULL,
    [SPLIT_ORDERS] CHAR(1) NULL,
    [MESSAGE_TO_PATIENT] VARCHAR(2000) NULL,
    [DELIVERY_MESSAGE_FOR_SHIPPER] VARCHAR(2000) NULL,
    [SIGNATURE_REQUIRED] CHAR(1) NULL,
    [SHIPMENT_ID] NUMERIC(38, 0) NULL,
    [SHIP_TO_NAME] VARCHAR(50) NULL,
    [SHIPPING_METHOD] VARCHAR(100) NULL,
    [TRACKING_URL] VARCHAR(200) NULL,
    [SHIPMENT_PROMISED_DATE] DATETIME2(6) NULL,
    CONSTRAINT [PACKAGE_INFO_PK] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 7: EPS.PACKAGE_INFO_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[PACKAGE_INFO_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [SHIP_DATE] DATETIME NULL,
    [PACKER_INITIALS] VARCHAR(3) NULL,
    [PACKER_NUM] VARCHAR(38) NULL,
    [MANIFEST_INITIALS] VARCHAR(3) NULL,
    [MANIFEST_NUM] VARCHAR(10) NULL,
    [TRACKING_NUMBER] VARCHAR(28) NULL,
    [WEIGHT] NUMERIC(13, 4) NULL,
    [SHIPPER_NAME] VARCHAR(64) NULL,
    [ACTUAL_SHIP_COST] NUMERIC(13, 2) NULL,
    [CF_SYSTEM_PACKAGE_NUMBER] VARCHAR(24) NULL,
    [AVERAGE_SHIPPING_COST] NUMERIC(13, 2) NULL,
    [CF_FACILITY_NAME] VARCHAR(28) NULL,
    [CF_SYSTEM_ORDER_NUMBER] NUMERIC(38, 0) NULL,
    [SHIP_TO_ADDRESS_LINE_1] VARCHAR(255) NULL,
    [SHIP_TO_CITY] VARCHAR(35) NULL,
    [SHIP_TO_POSTAL_CODE] VARCHAR(15) NULL,
    [SHIP_TO_STATE] VARCHAR(2) NULL,
    [ID_AAL] BIGINT NULL,
    [LAST_UPDATED] DATETIME NULL,
    [ID_RX_TX] BIGINT NOT NULL,
    [SHIP_TO_ADDRESS_LINE_2] VARCHAR(255) NULL,
    [ID_AUDIT] BIGINT NULL,
    [SHIP_TO_CARE_OF] VARCHAR(100) NULL,
    [SPLIT_ORDERS] CHAR(1) NULL,
    [MESSAGE_TO_PATIENT] VARCHAR(2000) NULL,
    [DELIVERY_MESSAGE_FOR_SHIPPER] VARCHAR(2000) NULL,
    [SIGNATURE_REQUIRED] CHAR(1) NULL,
    [SHIPMENT_ID] NUMERIC(38, 0) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [SHIP_TO_NAME] VARCHAR(50) NULL,
    [SHIPPING_METHOD] VARCHAR(100) NULL,
    [TRACKING_URL] VARCHAR(200) NULL,
    [SHIPMENT_PROMISED_DATE] DATETIME2(6) NULL
);

-- =====================================================================
-- All 7 tables created successfully (REORDERED FOR FK DEPENDENCIES)
-- =====================================================================
-- Tables created (in correct dependency order):
--   1. [EPS].[MTM_PATIENT_SESSION]
--   2. [EPS].[MTM_PATIENT_SESSION_AUDIT]
--   3. [EPS].[MTM_PATIENT_ANSWERS]
--   4. [EPS].[MTM_PATIENT_ANSWERS_AUDIT]
--   5. [EPS].[MTM_PATIENT_ELIGIBILITY]
--   6. [EPS].[PACKAGE_INFO]
--   7. [EPS].[PACKAGE_INFO_AUDIT]
--
-- Note: Tables reordered so FK-referenced tables are created BEFORE dependent tables
-- Note: Indexes and compression will be created in a separate script
-- =====================================================================
