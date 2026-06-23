-- ============================================================
-- Azure SQL Schema Conversion for EPS.PACKAGE_INFO
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PACKAGE_INFO
-- Type: Master Transaction Table (Current Shipments)
-- Oracle Partitions: LIST by CHAIN_ID (13 partitions)
-- Purpose: Active medication package shipment tracking

CREATE TABLE [EPS].[PACKAGE_INFO] (
    [CHAIN_ID] [numeric](22, 0) NOT NULL,
    [ID] [numeric](22, 0) NOT NULL,
    [SHIP_DATE] [datetime] NULL,
    [PACKER_INITIALS] [varchar](3) NULL,
    [PACKER_NUM] [varchar](38) NULL,
    [MANIFEST_INITIALS] [varchar](3) NULL,
    [MANIFEST_NUM] [varchar](10) NULL,
    [TRACKING_NUMBER] [varchar](28) NULL,
    [WEIGHT] [numeric](13, 4) NULL,
    [SHIPPER_NAME] [varchar](64) NULL,
    [ACTUAL_SHIP_COST] [numeric](13, 2) NULL,
    [CF_SYSTEM_PACKAGE_NUMBER] [varchar](24) NULL,
    [AVERAGE_SHIPPING_COST] [numeric](13, 2) NULL,
    [CF_FACILITY_NAME] [varchar](28) NULL,
    [CF_SYSTEM_ORDER_NUMBER] [numeric](38, 0) NULL,
    [SHIP_TO_ADDRESS_LINE_1] [varchar](255) NULL,
    [SHIP_TO_CITY] [varchar](35) NULL,
    [SHIP_TO_POSTAL_CODE] [varchar](15) NULL,
    [SHIP_TO_STATE] [varchar](2) NULL,
    [ID_AAL] [numeric](22, 0) NULL,
    [LAST_UPDATED] [datetime] NULL,
    [ID_RX_TX] [numeric](22, 0) NOT NULL,
    [SHIP_TO_ADDRESS_LINE_2] [varchar](255) NULL,
    [SHIP_TO_CARE_OF] [varchar](100) NULL,
    [SPLIT_ORDERS] [char](1) NULL,
    [MESSAGE_TO_PATIENT] [varchar](2000) NULL,
    [DELIVERY_MESSAGE_FOR_SHIPPER] [varchar](2000) NULL,
    [SIGNATURE_REQUIRED] [char](1) NULL,
    [SHIPMENT_ID] [numeric](38, 0) NULL,
    [SHIP_TO_NAME] [varchar](50) NULL,
    [SHIPPING_METHOD] [varchar](100) NULL,
    [TRACKING_URL] [varchar](200) NULL,
    [SHIPMENT_PROMISED_DATE] [datetime2](6) NULL,
    
    CONSTRAINT [PACKAGE_INFO_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Tracking Number Lookup (real-time shipment status)
CREATE NONCLUSTERED INDEX [IX_PACKAGE_INFO_TRACKING] 
ON [EPS].[PACKAGE_INFO] ([TRACKING_NUMBER], [CHAIN_ID])
INCLUDE ([ID], [SHIP_DATE], [SHIPMENT_ID], [SHIPMENT_PROMISED_DATE])
WHERE [TRACKING_NUMBER] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- RX_TX Reference (shipment linked to prescription)
CREATE NONCLUSTERED INDEX [IX_PACKAGE_INFO_RXTX] 
ON [EPS].[PACKAGE_INFO] ([ID_RX_TX], [CHAIN_ID])
INCLUDE ([ID], [SHIP_DATE], [TRACKING_NUMBER], [SHIPMENT_ID])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Shipment ID Reference (warehouse management system link)
CREATE NONCLUSTERED INDEX [IX_PACKAGE_INFO_SHIPMENT] 
ON [EPS].[PACKAGE_INFO] ([SHIPMENT_ID], [CHAIN_ID])
INCLUDE ([ID], [TRACKING_NUMBER], [SHIP_DATE])
WHERE [SHIPMENT_ID] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for active transaction table
ALTER TABLE [EPS].[PACKAGE_INFO] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[PRIMARY_KEY] Composite key: (CHAIN_ID, ID)
  Ensures one unique package record per chain per ID

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID (13 partitions) removed
  Replaced with clustered PK on (CHAIN_ID, ID)

[SHIPMENT_FULFILLMENT_WORKFLOW]
  1. Rx filled → Package ready for shipment
  2. Warehouse packs item (PACKER_INITIALS, MANIFEST recorded)
  3. Carrier picks up (SHIPPING_METHOD, TRACKING_NUMBER generated)
  4. Patient receives (SHIP_DATE, SHIP_TO_ADDRESS tracked)
  5. Delivery confirmed (SHIPMENT_PROMISED_DATE vs. actual)
  
  This table tracks entire lifecycle from warehouse to patient home

[ACTIVE_INVENTORY] PACKAGE_INFO contains CURRENT active shipments
  Parallel audit table (PACKAGE_INFO_AUDIT) maintains historical trail
  
  Expected queries:
  - In-transit packages (SHIP_DATE IS NOT NULL, DELIVERY within week)
  - Overdue shipments (SHIPMENT_PROMISED_DATE < TODAY())
  - By tracking number (patient customer service inquiry)
  - Volume analysis (ACTUAL_SHIP_COST benchmarking)

[SHIPMENT_PROMISED_DATE] Carrier-provided delivery estimate
  Calculated by carrier when label created
  Compare against actual receipt (requires separate delivery confirmation table)
  
  Missed delivery windows indicate:
  - Carrier performance issues (rate negotiation)
  - Address issues (invalid postal codes, rural locations)
  - Signature requirement delays
  
  Trend analysis:
  SELECT [SHIPPING_METHOD], 
         AVG(DATEDIFF(DAY, [SHIP_DATE], [SHIPMENT_PROMISED_DATE])) as [AvgTransitDays]
  FROM [EPS].[PACKAGE_INFO]
  WHERE [SHIP_DATE] IS NOT NULL
  GROUP BY [SHIPPING_METHOD];

[SIZE_ESTIMATE] ~100-200 MB (active shipments only, high churn as packages delivered and archived)

[DATA_QUALITY_VALIDATION]
  ✓ TRACKING_NUMBER not null and unique per SHIPMENT_ID
  ✓ SHIP_TO_STATE valid 2-letter US state codes
  ✓ SHIP_TO_POSTAL_CODE matches state (sample validation)
  ✓ SHIPMENT_PROMISED_DATE >= SHIP_DATE (future delivery promise)
  ✓ ACTUAL_SHIP_COST <= AVERAGE_SHIPPING_COST (within cost bounds)
  ✓ ID_RX_TX references valid RX_TX record

[SPECIAL_HANDLING_FLAGS]
  - SIGNATURE_REQUIRED: Controlled substance rule (DEA mandate), valuable medication
  - MESSAGE_TO_PATIENT: Special instructions (refrigeration, "Do Not Leave")
  - DELIVERY_MESSAGE_FOR_SHIPPER: Driver instructions (gate code, apartment access)
  - SPLIT_ORDERS: Multi-shipment fulfillment (cost implications)

[FULFILLMENT_CENTER_REFERENCE]
  CF_SYSTEM_PACKAGE_NUMBER, CF_SYSTEM_ORDER_NUMBER: External fulfillment center IDs
  CF_FACILITY_NAME: Facility identifier (warehouse location code)
  
  Link to external fulfillment system (non-pharmacy system)
  Data sync requirements during migration

[ORPHANED_PACKAGE_VALIDATION] Detect shipments missing RX_TX parent:
  SELECT COUNT(*) as [OrphanShipments]
  FROM [EPS].[PACKAGE_INFO] P
  LEFT JOIN [EPS].[RX_TX] R ON P.[ID_RX_TX] = R.[ID]
  WHERE R.[ID] IS NULL;  -- Should return 0
*/
