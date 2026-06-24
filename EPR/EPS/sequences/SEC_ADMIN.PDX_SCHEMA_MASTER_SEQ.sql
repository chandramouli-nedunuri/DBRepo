-- Converted from Oracle to Azure SQL
-- Original Oracle Sequence Definition converted to Azure SQL T-SQL
-- Oracle-specific parameters (CACHE, NOCACHE, NOORDER, NOCYCLE, NOKEEP, NOSCALE, GLOBAL) removed as they are not supported in Azure SQL

CREATE SEQUENCE SEC_ADMIN.PDX_SCHEMA_MASTER_SEQ
    AS BIGINT
    START WITH 1495
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    NO CYCLE;
GO
