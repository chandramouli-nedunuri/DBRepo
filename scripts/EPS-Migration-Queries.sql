-- ============================================================================
-- EPS Database Migration - Diagnostic Queries
-- Purpose: Collection of useful queries for monitoring Azure SQL migration
-- Server: sql-epr-qa-eastus2.database.windows.net
-- Database: sqldb-epr-qa
-- ============================================================================

-- ============================================================================
-- Query 1: Test Database Connectivity and Get SQL Version
-- Purpose: Verify connection to Azure SQL Server and display SQL Server version
-- ============================================================================
SELECT @@VERSION AS [SQL Server Version];


-- ============================================================================
-- Query 2: Count Total Foreign Keys in EPS Schema
-- Purpose: Check total number of foreign key constraints defined in EPS schema
-- ============================================================================
SELECT COUNT(*) AS FK_Count 
FROM sys.foreign_keys 
WHERE SCHEMA_NAME(schema_id) = 'EPS';


-- ============================================================================
-- Query 3: List Foreign Keys on EPS.ADDRESS Table
-- Purpose: Retrieve all foreign key constraints on the ADDRESS table
-- ============================================================================
SELECT 
    name AS FK_Name, 
    OBJECT_NAME(parent_object_id) AS Table_Name, 
    OBJECT_NAME(referenced_object_id) AS Referenced_Table
FROM sys.foreign_keys 
WHERE OBJECT_NAME(parent_object_id) = 'ADDRESS' 
  AND SCHEMA_NAME(schema_id) = 'EPS' 
ORDER BY name;


-- ============================================================================
-- Query 4: Count Total Tables in EPS Schema
-- Purpose: Get total number of base tables in the EPS schema
-- ============================================================================
SELECT COUNT(*) AS Total_Tables 
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'EPS' 
  AND TABLE_TYPE = 'BASE TABLE';


-- ============================================================================
-- Query 5: List All Tables in EPS Schema
-- Purpose: Display all table names in the EPS schema with row counts
-- ============================================================================
SELECT 
    t.TABLE_NAME,
    p.rows AS Row_Count
FROM information_schema.TABLES t
LEFT JOIN sys.partitions p ON t.TABLE_NAME = OBJECT_NAME(p.object_id) AND p.index_id <= 1
WHERE t.TABLE_SCHEMA = 'EPS' 
  AND t.TABLE_TYPE = 'BASE TABLE'
ORDER BY t.TABLE_NAME;


-- ============================================================================
-- Query 6: List All Sequences in EPS Schema
-- Purpose: Display all sequence objects in EPS schema
-- ============================================================================
SELECT 
    name AS Sequence_Name,
    SCHEMA_NAME(schema_id) AS Schema_Name,
    current_value AS Current_Value,
    start_value AS Start_Value,
    increment AS Increment_Value,
    is_cycling AS Is_Cycling
FROM sys.sequences
WHERE SCHEMA_NAME(schema_id) = 'EPS'
ORDER BY name;


-- ============================================================================
-- Query 7: List All Foreign Key Constraints in EPS Schema
-- Purpose: Get detailed information about all FK constraints
-- ============================================================================
SELECT 
    fk.name AS FK_Name,
    OBJECT_NAME(fk.parent_object_id) AS Parent_Table,
    OBJECT_NAME(fk.referenced_object_id) AS Referenced_Table,
    fk.delete_referential_action_desc AS Delete_Action,
    fk.update_referential_action_desc AS Update_Action
FROM sys.foreign_keys fk
WHERE SCHEMA_NAME(fk.schema_id) = 'EPS'
ORDER BY Parent_Table, FK_Name;


-- ============================================================================
-- Query 8: Check for Duplicate Foreign Key Constraints
-- Purpose: Identify duplicate FKs that may need resolution
-- ============================================================================
SELECT 
    OBJECT_NAME(parent_object_id) AS Table_Name,
    name AS FK_Name,
    COUNT(*) AS Count
FROM sys.foreign_keys
WHERE SCHEMA_NAME(schema_id) = 'EPS'
GROUP BY parent_object_id, name
HAVING COUNT(*) > 1;


-- ============================================================================
-- Query 9: Get Table Creation Scripts for EPS Schema
-- Purpose: Display table definitions and creation details
-- ============================================================================
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    COUNT(*) AS Column_Count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'EPS'
GROUP BY TABLE_SCHEMA, TABLE_NAME
ORDER BY TABLE_NAME;


-- ============================================================================
-- Query 10: Check for Missing Tables (Prerequisite Check)
-- Purpose: Verify that all required tables exist before FK creation
-- ============================================================================
SELECT 
    TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA IN ('EPS', 'SEC_ADMIN')
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
