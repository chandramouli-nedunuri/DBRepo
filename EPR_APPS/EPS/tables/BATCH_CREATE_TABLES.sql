-- =====================================================================
-- BATCH TABLE CREATION SCRIPT
-- =====================================================================
-- Combined tables for single execution
-- Execution Date: 2026-06-08
-- Tables: 10 total (CREATE TABLE only)
-- Schema: EPS, SEC_ADMIN
-- Note: Indexes and compression handled in separate script
-- Compatible with: DBeaver, SQL Server, Azure SQL
-- =====================================================================

-- =====================================================================
-- TABLE 1: EPS.CARRIER_ID_TEMP
-- =====================================================================
CREATE TABLE [EPS].[CARRIER_ID_TEMP] (
    [CARRIER_ID] VARCHAR(10),
    [TEMP_ID] BIGINT,
    [CREATED_DATE] DATETIME DEFAULT GETDATE()
);

-- =====================================================================
-- TABLE 2: EPS.CHAIN_RX_TX_SHARING_LINK
-- =====================================================================
CREATE TABLE [EPS].[CHAIN_RX_TX_SHARING_LINK] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1),
    [ADDED] DATETIME,
    [LAST_UPDATED] DATETIME,
    [LINKED_CHAIN_ID] BIGINT NOT NULL,
    [USER_CODE] VARCHAR(20),
    CONSTRAINT [PK_CHAIN_RX_TX_SHARING_LINK] PRIMARY KEY ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_CHAIN_RX_TX_LINK_CHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_CHAIN_RX_TX_LINK_LINKED] FOREIGN KEY ([LINKED_CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
);

-- =====================================================================
-- TABLE 3: EPS.CHAIN_RX_TX_SHARING_LINK_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[CHAIN_RX_TX_SHARING_LINK_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1),
    [ADDED] DATETIME,
    [LAST_UPDATED] DATETIME,
    [LINKED_CHAIN_ID] BIGINT NOT NULL,
    [USER_CODE] VARCHAR(20),
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- =====================================================================
-- TABLE 4: EPS.COMPOUND_INGREDIENTS
-- =====================================================================
CREATE TABLE [EPS].[COMPOUND_INGREDIENTS] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME NOT NULL,
    [ID_RX_TX] BIGINT NOT NULL,
    [NDC] VARCHAR(11) NOT NULL,
    [INGREDIENT_NAME] VARCHAR(28),
    [QUANTITY] DECIMAL(15,6),
    [BASE_COST] DECIMAL(13,2),
    [ACQUISITION_COST] DECIMAL(13,2),
    [IS_DELETED] VARCHAR(1),
    [DISPENSABLE_IDENTIFIER] BIGINT,
    CONSTRAINT [PK_COMPOUND_INGREDIENTS] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 5: EPS.COMPOUND_INGREDIENTS_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[COMPOUND_INGREDIENTS_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME NOT NULL,
    [ID_RX_TX] BIGINT NOT NULL,
    [NDC] VARCHAR(11) NOT NULL,
    [INGREDIENT_NAME] VARCHAR(28),
    [QUANTITY] DECIMAL(15,6),
    [BASE_COST] DECIMAL(13,2),
    [ACQUISITION_COST] DECIMAL(13,2),
    [IS_DELETED] VARCHAR(1),
    [ID_AUDIT] BIGINT,
    [DISPENSABLE_IDENTIFIER] NUMERIC(10,0),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- =====================================================================
-- TABLE 6: EPS.COMPOUND_INGREDIENT_LOT
-- =====================================================================
CREATE TABLE [EPS].[COMPOUND_INGREDIENT_LOT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME,
    [ID_RX_TX] BIGINT,
    [NDC] VARCHAR(11),
    [INGREDIENT_NAME] VARCHAR(28),
    [QUANTITY] DECIMAL(15,6),
    [BASE_COST] DECIMAL(13,2),
    [ACQUISITION_COST] DECIMAL(13,2),
    [IS_DELETED] VARCHAR(1),
    [DISPENSABLE_IDENTIFIER] BIGINT,
    [LOT_NUMBER] VARCHAR(20),
    CONSTRAINT [PK_COMPOUND_INGREDIENT_LOT] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- =====================================================================
-- TABLE 7: EPS.COUNSELING_NOTES
-- =====================================================================
CREATE TABLE [EPS].[COUNSELING_NOTES] (
    [ID] BIGINT,
    [CHAIN_ID] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [NHIN_ID] BIGINT NOT NULL,
    [STORE_NOTE_CREATED_DATE] DATETIME2(6) NOT NULL,
    [CREATED_BY_USER_IDENTIFIER] VARCHAR(255) NOT NULL,
    [NOTE] VARCHAR(2000),
    [LAST_UPDATED] DATETIME2(6),
    [RX_TX_ID] BIGINT NOT NULL,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [PK_COUNSELING_NOTES] PRIMARY KEY ([ID])
);

-- =====================================================================
-- TABLE 8: EPS.COUNSELING_NOTES_AUDIT
-- =====================================================================
CREATE TABLE [EPS].[COUNSELING_NOTES_AUDIT] (
    [ID] BIGINT,
    [CHAIN_ID] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [NHIN_ID] BIGINT NOT NULL,
    [STORE_NOTE_CREATED_DATE] DATETIME2(6) NOT NULL,
    [CREATED_BY_USER_IDENTIFIER] VARCHAR(255) NOT NULL,
    [NOTE] VARCHAR(2000),
    [LAST_UPDATED] DATETIME2(6),
    [RX_TX_ID] BIGINT NOT NULL,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [PK_COUNSELING_NOTES_AUDIT] PRIMARY KEY ([ID])
);

-- =====================================================================
-- TABLE 9: EPS.CROSS_CHAIN_LAST_SELECTED
-- =====================================================================
CREATE TABLE [EPS].[CROSS_CHAIN_LAST_SELECTED] (
    [ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [NHIN_ID] BIGINT,
    [LAST_SELECTED_DATE] DATETIME2(6),
    CONSTRAINT [PK_CROSS_CHAIN_LAST_SELECTED] PRIMARY KEY ([ID], [CHAIN_ID]),
    CONSTRAINT [FK_CCHN_LAST_SELECTED_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_CCHN_LAST_SELECTED_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_CCHN_LAST_SELECTED_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID])
);

-- =====================================================================
-- TABLE 10: EPS.CROSS_CHAIN_LINK
-- =====================================================================
CREATE TABLE [EPS].[CROSS_CHAIN_LINK] (
    [ID] BIGINT,
    [EHR_ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [LAST_RX_UPDATE_DATE] DATETIME2(6),
    [DELETED] VARCHAR(1),
    CONSTRAINT [UQ_CROSS_CHAIN_LINK] UNIQUE ([CHAIN_ID], [ID_PATIENT], [EHR_ID]),
    CONSTRAINT [PK_CROSS_CHAIN_LINK] PRIMARY KEY ([ID]),
    CONSTRAINT [FK_CROSS_CHAIN_LINK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_CROSS_CHAIN_LINK_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [FK_CROSS_CHAIN_LINK_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
);

-- =====================================================================
-- All 10 tables created successfully
-- =====================================================================
-- Tables created:
--   1. [EPS].[CARRIER_ID_TEMP]
--   2. [EPS].[CHAIN_RX_TX_SHARING_LINK]
--   3. [EPS].[CHAIN_RX_TX_SHARING_LINK_AUDIT]
--   4. [EPS].[COMPOUND_INGREDIENTS]
--   5. [EPS].[COMPOUND_INGREDIENTS_AUDIT]
--   6. [EPS].[COMPOUND_INGREDIENT_LOT]
--   7. [EPS].[COUNSELING_NOTES]
--   8. [EPS].[COUNSELING_NOTES_AUDIT]
--   9. [EPS].[CROSS_CHAIN_LAST_SELECTED]
--  10. [EPS].[CROSS_CHAIN_LINK]
--
-- Note: Indexes and compression will be created in a separate script
-- =====================================================================
