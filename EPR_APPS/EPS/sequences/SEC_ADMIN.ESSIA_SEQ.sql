-- Converted from Oracle to Azure SQL
-- Original Oracle Sequence Definition converted to Azure SQL T-SQL
-- Oracle-specific parameters (CACHE, NOORDER, NOCYCLE, NOKEEP, NOSCALE, GLOBAL) removed as they are not supported in Azure SQL

CREATE SEQUENCE SEC_ADMIN.ESSIA_SEQ
    AS BIGINT
    START WITH 3
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    CACHE 20
    NO CYCLE;
GO
