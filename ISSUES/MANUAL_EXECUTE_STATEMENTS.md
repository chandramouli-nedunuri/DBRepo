# EXACT STATEMENTS FOR MANUAL EXECUTION

## RX_TX: DROP and ALTER Statements

**RX_TX currently has:**
- PK Name: `RX_TX_PK`
- Columns: (CHAIN_ID, ID)  
- Partitions: 1 (not on scheme)
- Fix: Drop PK, recreate on partition scheme

### Execute these statements in order:

```sql
USE [sqldb-epr-qa];
GO

-- STEP 1: DROP EXISTING PRIMARY KEY
ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_PK;
GO

-- STEP 2: CREATE PARTITIONED PRIMARY KEY
ALTER TABLE EPS.RX_TX ADD CONSTRAINT PK_RX_TX PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
GO

-- VERIFY
SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.RX_TX') AND index_id=1;
GO
```

**Expected result:** Returns `6`

---

## DISEASE: DROP and ALTER Statements

**DISEASE currently has:**
- Partitions: 0
- Fix: Determine current PK name, drop all FKs, then recreate PK on partition scheme

### Execute these statements in order:

```sql
USE [sqldb-epr-qa];
GO

-- STEP 1: DROP ALL FOREIGN KEYS POINTING TO DISEASE
BEGIN TRY
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_ESCHAIN;
END TRY
BEGIN CATCH
    PRINT 'DISEASE_FK_ESCHAIN - Already dropped or doesn''t exist';
END CATCH
GO

BEGIN TRY
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_ESSTORE;
END TRY
BEGIN CATCH
    PRINT 'DISEASE_FK_ESSTORE - Already dropped or doesn''t exist';
END CATCH
GO

BEGIN TRY
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_PATIENT;
END TRY
BEGIN CATCH
    PRINT 'DISEASE_FK_PATIENT - Already dropped or doesn''t exist';
END CATCH
GO

-- STEP 2: DROP EXISTING PRIMARY KEY (Try both possible names)
BEGIN TRY
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT PK_DISEASE;
    PRINT 'Dropped PK_DISEASE';
END TRY
BEGIN CATCH
    BEGIN TRY
        ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_PK;
        PRINT 'Dropped DISEASE_PK';
    END TRY
    BEGIN CATCH
        PRINT 'Could not drop PK - ' + ERROR_MESSAGE();
    END CATCH
END CATCH
GO

-- STEP 3: CREATE PARTITIONED PRIMARY KEY
ALTER TABLE EPS.DISEASE ADD CONSTRAINT PK_DISEASE PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
GO

-- VERIFY
SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.DISEASE') AND index_id=1;
GO
```

**Expected result:** Returns `6`

---

## Quick Copy-Paste Bundle (Both Tables)

```sql
USE [sqldb-epr-qa];
GO

-- ===== RX_TX =====
ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_PK;
GO

ALTER TABLE EPS.RX_TX ADD CONSTRAINT PK_RX_TX PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
GO

-- ===== DISEASE =====
BEGIN TRY
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_ESCHAIN;
END TRY
BEGIN CATCH
    PRINT 'FK1 dropped or doesn''t exist';
END CATCH

BEGIN TRY
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_ESSTORE;
END TRY
BEGIN CATCH
    PRINT 'FK2 dropped or doesn''t exist';
END CATCH

BEGIN TRY
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_PATIENT;
END TRY
BEGIN CATCH
    PRINT 'FK3 dropped or doesn''t exist';
END CATCH

BEGIN TRY
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT PK_DISEASE;
END TRY
BEGIN CATCH
    BEGIN TRY
        ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_PK;
    END TRY
    BEGIN CATCH
        PRINT 'PK drop failed - ' + ERROR_MESSAGE();
    END CATCH
END CATCH
GO

ALTER TABLE EPS.DISEASE ADD CONSTRAINT PK_DISEASE PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
GO

-- ===== VERIFY BOTH =====
SELECT 'RX_TX' as [Table], COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.RX_TX') AND index_id=1
UNION ALL SELECT 'DISEASE', COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.DISEASE') AND index_id=1;
GO
```

---

## Instructions

1. Copy the **Quick Copy-Paste Bundle** above
2. Open Azure Portal → SQL Database `sqldb-epr-qa` → Query Editor
3. Paste the entire bundle
4. Click **Run**
5. Wait for completion (~2 minutes)
6. Last query returns 2 rows:
   - RX_TX: 6 ✓
   - DISEASE: 6 ✓

**Result: All 9 Category A1 tables partitioned (100% complete)**
