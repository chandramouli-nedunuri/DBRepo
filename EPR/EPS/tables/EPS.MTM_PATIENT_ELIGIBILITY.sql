-- ============================================================
-- Azure SQL Schema Conversion for EPS.MTM_PATIENT_ELIGIBILITY
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.MTM_PATIENT_ELIGIBILITY
-- Type: Reference/Configuration Table
-- Purpose: MTM patient insurance eligibility and vendor tracking
-- Oracle: Single-partition table with PRIMARY KEY and 1 FK constraint

CREATE TABLE [EPS].[MTM_PATIENT_ELIGIBILITY] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [RX_COM_ID] [int] NOT NULL,
    [DELIVERY_OF_SERVICE_DATE] [datetime2](6) NULL,
    [ID_AAL] [int] NULL,
    [LAST_UPDATED] [datetime] NULL,
    [VENDOR_IDENTIFIER] [varchar](10) NOT NULL,
    [ELIGIBILITY_URL] [varchar](2000) NULL,
    
    CONSTRAINT [MTM_PATIENT_ELIGIBILITY_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    
    CONSTRAINT [MTM_PATIENT_ELIGIBILITY_FK1] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- RX_COM ID Lookup (external system mapping)
CREATE NONCLUSTERED INDEX [IX_MTM_ELIGIBILITY_RXCOM] 
ON [EPS].[MTM_PATIENT_ELIGIBILITY] ([RX_COM_ID])
INCLUDE ([CHAIN_ID], [ID], [VENDOR_IDENTIFIER])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Vendor-based Reporting
CREATE NONCLUSTERED INDEX [IX_MTM_ELIGIBILITY_VENDOR] 
ON [EPS].[MTM_PATIENT_ELIGIBILITY] ([VENDOR_IDENTIFIER], [CHAIN_ID])
INCLUDE ([ID], [DELIVERY_OF_SERVICE_DATE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Service Date Range (eligibility by date)
CREATE NONCLUSTERED INDEX [IX_MTM_ELIGIBILITY_DOS] 
ON [EPS].[MTM_PATIENT_ELIGIBILITY] ([DELIVERY_OF_SERVICE_DATE], [CHAIN_ID])
INCLUDE ([ID], [VENDOR_IDENTIFIER])
WHERE [DELIVERY_OF_SERVICE_DATE] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for configuration table
ALTER TABLE [EPS].[MTM_PATIENT_ELIGIBILITY] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[TABLE_PURPOSE] MTM (Medication Therapy Management) eligibility matrix:
  - MTM programs vary by insurance carrier (vendor)
  - Each patient may be eligible for one or more MTM programs
  - Eligibility tied to insurance plan and delivery date
  - RX_COM_ID: External system identifier for program enrollment
  
  Business Logic: Patient eligible for MTM if:
  1. Record exists in this table for (CHAIN_ID, ID)
  2. DELIVERY_OF_SERVICE_DATE <= TODAY()
  3. VENDOR_IDENTIFIER maps to active MTM program in external system

[VENDOR_IDENTIFIER] Values likely include:
  - Major insurers: Humana, Cigna, Aetna, BlueCross (abbreviated codes)
  - Pharmacy benefit managers: CVS, Express Scripts, Medco replacements
  - Medicare/Medicaid: CMS contractor identifiers
  
  Validate values against external referential system during migration:
  SELECT DISTINCT [VENDOR_IDENTIFIER] 
  FROM [EPS].[MTM_PATIENT_ELIGIBILITY] 
  ORDER BY [VENDOR_IDENTIFIER];

[ELIGIBILITY_URL] External portal/endpoint for eligibility verification
  Likely HTTPS endpoints for real-time eligibility checks (RESTful API, NCPDP, HL7)
  
  Consider parsing/validating HTTPS format:
  ALTER TABLE [EPS].[MTM_PATIENT_ELIGIBILITY]
  ADD CONSTRAINT [CK_ELIGIBILITY_URL_HTTPS]
  CHECK ([ELIGIBILITY_URL] IS NULL OR [ELIGIBILITY_URL] LIKE 'https://%');

[RX_COM_INTEGRATION] RX_COM_ID - likely external MTM program ID
  Ensure all RX_COM_ID values map to active programs:
  SELECT [RX_COM_ID], COUNT(*) 
  FROM [EPS].[MTM_PATIENT_ELIGIBILITY] 
  GROUP BY [RX_COM_ID]
  ORDER BY COUNT(*) DESC;

[FK_DEPENDENCY] Single FK to SEC_ADMIN.EPS_SEC_CHAIN
  No DEFERRABLE semantics - immediate constraint checking applies
  
  FK is NOT DEFERRABLE (no deferral annotation in Oracle source)

[DELIVERY_OF_SERVICE_DATE_INTERPRETATION] 
  Likely meanings:
  a) Program enrollment date (patient became eligible)
  b) Patient's insurance effective date
  c) Service start date for reporting
  
  NULL values imply either:
  - Pending eligibility (enrolled, not yet active)
  - Grandfathered/perpetual eligibility
  
  Validate business rules:
  SELECT 
    SUM(CASE WHEN [DELIVERY_OF_SERVICE_DATE] IS NULL THEN 1 ELSE 0 END) as [NullDOS],
    SUM(CASE WHEN [DELIVERY_OF_SERVICE_DATE] > GETDATE() THEN 1 ELSE 0 END) as [FutureDOS]
  FROM [EPS].[MTM_PATIENT_ELIGIBILITY];

[ID_AAL] Audit user ID (who created/last modified record)
  Consider adding LAST_UPDATED trigger if not present:
  CREATE TRIGGER [tr_MTM_ELIGIBILITY_UPDATE]
  ON [EPS].[MTM_PATIENT_ELIGIBILITY]
  AFTER UPDATE
  AS
  BEGIN
    UPDATE [EPS].[MTM_PATIENT_ELIGIBILITY]
    SET [LAST_UPDATED] = GETDATE()
    WHERE [CHAIN_ID] IN (SELECT [CHAIN_ID] FROM inserted);
  END;

[SIZE_ESTIMATE] ~50-100 MB (MTM-eligible patients per chain, relatively small reference table)

[EXPECTED_QUERIES]
  1. Check if patient eligible for MTM TODAY:
     SELECT 1 FROM [EPS].[MTM_PATIENT_ELIGIBILITY] 
     WHERE [CHAIN_ID] = @chainId 
     AND [ID] = @patientId 
     AND [DELIVERY_OF_SERVICE_DATE] <= GETDATE();
  
  2. Vendor-program distribution:
     SELECT [VENDOR_IDENTIFIER], [RX_COM_ID], COUNT(*) as [PatientCount]
     FROM [EPS].[MTM_PATIENT_ELIGIBILITY]
     GROUP BY [VENDOR_IDENTIFIER], [RX_COM_ID];
  
  3. Future activations:
     SELECT [VENDOR_IDENTIFIER], COUNT(*) as [PendingActivations]
     FROM [EPS].[MTM_PATIENT_ELIGIBILITY]
     WHERE [DELIVERY_OF_SERVICE_DATE] > GETDATE()
     GROUP BY [VENDOR_IDENTIFIER];
*/
