-- Converted from Oracle to Azure SQL
-- Original Oracle Sequence Definition converted to Azure SQL T-SQL
-- Oracle-specific parameters (CACHE, NOORDER, NOCYCLE, NOKEEP, NOSCALE, GLOBAL) removed as they are not supported in Azure SQL

CREATE SEQUENCE SEC_ADMIN.ESL_SEQ
    AS BIGINT
    START WITH 6236294
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    CACHE 20
    NO CYCLE;
GO
