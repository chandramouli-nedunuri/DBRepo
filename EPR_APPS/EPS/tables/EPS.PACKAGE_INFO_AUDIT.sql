-- ============================================================
-- Azure SQL Schema Conversion for EPS.PACKAGE_INFO_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PACKAGE_INFO_AUDIT
-- Type: Composite Partitioned Audit Table (Shipping/Fulfillment)
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Audit trail for medication package shipment details

CREATE TABLE [EPS].[PACKAGE_INFO_AUDIT] (
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
    [ID_AUDIT] [int] NULL,
    [SHIP_TO_CARE_OF] [varchar](100) NULL,
    [SPLIT_ORDERS] [char](1) NULL,
    [MESSAGE_TO_PATIENT] [varchar](2000) NULL,
    [DELIVERY_MESSAGE_FOR_SHIPPER] [varchar](2000) NULL,
    [SIGNATURE_REQUIRED] [char](1) NULL,
    [SHIPMENT_ID] [numeric](38, 0) NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL,
    [SHIP_TO_NAME] [varchar](50) NULL,
    [SHIPPING_METHOD] [varchar](100) NULL,
    [TRACKING_URL] [varchar](200) NULL,
    [SHIPMENT_PROMISED_DATE] [datetime2](6) NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Audit Timestamp Range (monthly window queries)
CREATE NONCLUSTERED INDEX [IX_PACKAGE_INFO_AUDIT_TIMESTAMP] 
ON [EPS].[PACKAGE_INFO_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_RX_TX], [TRACKING_NUMBER])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Tracking Number Lookup (fulfillment inquiry)
CREATE NONCLUSTERED INDEX [IX_PACKAGE_INFO_AUDIT_TRACKING] 
ON [EPS].[PACKAGE_INFO_AUDIT] ([TRACKING_NUMBER], [CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [SHIP_DATE], [SHIPMENT_ID])
WHERE [TRACKING_NUMBER] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- RX_TX Reference (link to rx/transaction)
CREATE NONCLUSTERED INDEX [IX_PACKAGE_INFO_AUDIT_RXTX] 
ON [EPS].[PACKAGE_INFO_AUDIT] ([ID_RX_TX], [CHAIN_ID])
INCLUDE ([ID], [SHIP_DATE], [TRACKING_NUMBER])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table
ALTER TABLE [EPS].[PACKAGE_INFO_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
  
  RECOMMENDATION: Post-migration monthly RANGE partitioning:
  
  CREATE PARTITION FUNCTION [PF_PACKAGE_INFO_AUDIT_MONTHLY](datetime2)
  AS RANGE RIGHT FOR VALUES ('2024-07-01', '2024-08-01', ... '2026-09-01');
  
  Enables: Fast quarterly fulfillment analysis, archive old shipment records

[FULFILLMENT_OPERATIONS] PACKAGE_INFO critical for mail-order pharmacy:
  Tracks medication shipment from pharmacy warehouse to patient home
  
  Key fields:
  - SHIP_DATE: When medication left warehouse
  - TRACKING_NUMBER: Carrier tracking identifier (UPS, FedEx, USPS)
  - SHIPMENT_ID: Internal fulfillment/warehouse system tracking
  - SIGNATURE_REQUIRED: Flag if signature required on delivery
  - SHIPMENT_PROMISED_DATE: Expected delivery window (from carrier)
  
  Patient workflow:
  1. Rx filled, fulfillment ordered
  2. Package picked, packed by PACKER with MANIFEST
  3. Shipped via SHIPPING_METHOD (carrier), TRACKING_NUMBER generated
  4. Patient receives with optional SIGNATURE_REQUIRED validation

[SHIPMENT_COST_TRACKING]
  [ACTUAL_SHIP_COST]: Carrier charge for this specific shipment
  [AVERAGE_SHIPPING_COST]: Calculate moving average for pricing analysis
  
  High-value analysis:
  SELECT SUM([ACTUAL_SHIP_COST]) as [TotalCost],
         AVG([ACTUAL_SHIP_COST]) as [AvgCost],
         AVG([AVERAGE_SHIPPING_COST]) as [TrendingAvg]
  FROM [EPS].[PACKAGE_INFO_AUDIT];
  
  Identify cost outliers (negotiation opportunities with carriers)

[SHIP_TO_ADDRESS] Complete mailing address captured:
  - SHIP_TO_ADDRESS_LINE_1, SHIP_TO_ADDRESS_LINE_2
  - SHIP_TO_CITY, SHIP_TO_STATE, SHIP_TO_POSTAL_CODE
  - SHIP_TO_NAME, SHIP_TO_CARE_OF (optional alternate recipient)
  
  Verify address validation during migration:
  NULL postal codes indicate address quality issues

[FULFILLMENT_QUALITY] Optional message fields:
  - MESSAGE_TO_PATIENT: Pharmacy-level instructions (special handling, contact info)
  - DELIVERY_MESSAGE_FOR_SHIPPER: Carrier-level instructions (signature, delivery attempt)
  
  Identifies complex fulfillment scenarios (restricted delivery, special notes)

[SIZE_ESTIMATE] ~800-1.2 GB (mail-order volume, 13 chains × 3 months rolling, high shipment throughput)

[ID_RX_TX_DEPENDENCY] Foreign key relationship to RX_TX (prescription-transaction)
  VALIDATION: Ensure all PACKAGE_INFO records have matching RX_TX parents

[SIGNATURE_REQUIREMENT_ANALYSIS]
  SELECT [SIGNATURE_REQUIRED], COUNT(*) as [ShipmentCount]
  FROM [EPS].[PACKAGE_INFO_AUDIT]
  WHERE [SIGNATURE_REQUIRED] IS NOT NULL
  GROUP BY [SIGNATURE_REQUIRED];
  
  Optional signatures increase delivery cost (carrier fees) and delays

[SPLIT_ORDERS_FLAG] Indicates original Rx split across multiple shipments
  Occurs when:
  - Partial fills (quantity limitation per supplier)
  - Multi-day supply split into separate deliveries (controlled substance rules)
  - Back-order recovery (delayed items shipped separately)
  
  Business impact: Duplicate shipping costs, patient confusion
  Correlate with WEIGHT and TOTAL_QUANTITY for pattern analysis
*/
