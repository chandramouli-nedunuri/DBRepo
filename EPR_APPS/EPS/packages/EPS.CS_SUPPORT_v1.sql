-- Architected Azure SQL conversion scaffold of Oracle package EPS.CS_SUPPORT
-- Source: Packages/EPS.CS_SUPPORT.txt
-- Base target: Azure SQL/Packages/EPS.CS_SUPPORT.txt
-- File: Azure SQL/Packages/EPS.CS_SUPPORT_v1.txt
-- NOTE: getfile output for the Oracle source still truncates in-chat after ~1000 lines.
-- This v1 therefore focuses on production-oriented Azure SQL behavior, improved audit fidelity,
-- and explicit handling notes for Oracle-to-Azure semantic differences.

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'EPS')
BEGIN
    EXEC('CREATE SCHEMA [EPS]');
END;
GO

/*
Conversion strategy:
- package private function log_audit_dbu -> stored procedure with OUTPUT id
- Oracle sequence NEXTVAL + RETURNING INTO -> configurable identity/sequence fallback
- Oracle SYSTIMESTAMP -> SYSUTCDATETIME()
- Oracle SYS_CONTEXT('userenv','session_user') -> SUSER_SNAME()
- Oracle EXECUTE IMMEDIATE -> static parameterized DML where SQL shape is known
- Oracle SQL%ROWCOUNT -> @@ROWCOUNT captured immediately
- Oracle RAISE_APPLICATION_ERROR -> THROW
- Oracle DBMS_UTILITY formatting -> richer T-SQL error detail text
- O2SS0404 ROWID issues are neutralized by key-based DML only
- O2SS0356 NUMBER warnings are mitigated by BIGINT mappings pending schema validation

IMPORTANT LOGGING NOTE:
Oracle helper routines committed audit rows independently. Standard Azure SQL stored procedures do not
support true Oracle-style autonomous transactions. This v1 keeps log writes outside the main DML transaction
where possible and enriches audit detail, but exact autonomous-commit parity is not guaranteed.
*/

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_log_audit_dbu]
    @p_dbu_table NVARCHAR(4000),
    @p_dbu_parms NVARCHAR(MAX),
    @p_dbu_rows BIGINT,
    @p_sql_text NVARCHAR(MAX),
    @p_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @sequence_exists BIT = CASE WHEN EXISTS (
        SELECT 1
        FROM sys.sequences s
        INNER JOIN sys.schemas sc ON sc.schema_id = s.schema_id
        WHERE sc.name = N'dbo' AND s.name = N'audit_dbu_log_seq'
    ) THEN 1 ELSE 0 END;

    BEGIN TRY
        IF @sequence_exists = 1
        BEGIN
            DECLARE @next_id BIGINT = NEXT VALUE FOR dbo.audit_dbu_log_seq;

            INSERT INTO dbo.audit_dbu_log
            (
                id,
                exec_time_stamp,
                user_id,
                dbu_table,
                dbu_parms,
                dbu_rows,
                sql_text
            )
            VALUES
            (
                @next_id,
                SYSUTCDATETIME(),
                SUSER_SNAME(),
                UPPER(@p_dbu_table),
                @p_dbu_parms,
                @p_dbu_rows,
                @p_sql_text
            );

            SET @p_id = @next_id;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.audit_dbu_log
            (
                exec_time_stamp,
                user_id,
                dbu_table,
                dbu_parms,
                dbu_rows,
                sql_text
            )
            VALUES
            (
                SYSUTCDATETIME(),
                SUSER_SNAME(),
                UPPER(@p_dbu_table),
                @p_dbu_parms,
                @p_dbu_rows,
                @p_sql_text
            );

            SET @p_id = TRY_CAST(SCOPE_IDENTITY() AS BIGINT);
        END
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_log_error]
    @p_id BIGINT,
    @p_error NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE dbo.audit_dbu_log
       SET error_text = @p_error
     WHERE id = @p_id;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_build_error_text]
    @p_prefix NVARCHAR(4000),
    @p_error_text NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @p_error_text = @p_prefix + CHAR(10)
        + N'ERROR_NUMBER=' + CONVERT(NVARCHAR(20), ERROR_NUMBER()) + CHAR(10)
        + N'ERROR_MESSAGE=' + COALESCE(ERROR_MESSAGE(), N'<NULL>') + CHAR(10)
        + N'ERROR_PROCEDURE=' + COALESCE(ERROR_PROCEDURE(), N'<NULL>') + CHAR(10)
        + N'ERROR_LINE=' + CONVERT(NVARCHAR(20), ERROR_LINE());
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_address]
    @p_chainid BIGINT = NULL,
    @p_id BIGINT = NULL,
    @p_numrows BIGINT = NULL,
    @p_deleted NVARCHAR(1) = N'N'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @l_id BIGINT = NULL;
    DECLARE @v_rowsproc BIGINT;
    DECLARE @v_sql NVARCHAR(MAX);
    DECLARE @v_error NVARCHAR(MAX);

    IF @p_chainid IS NULL THROW 50000, 'DBU [ADDRESS] must contain a CHAIN_ID', 1;
    IF @p_id IS NULL THROW 50001, 'DBU [ADDRESS] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50002, 'DBU [ADDRESS] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50003, 'DBU [ADDRESS] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN (N'Y', N'N')
        THROW 50004, 'DBU [ADDRESS] deleted flag is invalid', 1;

    SET @v_sql = N'update address set deleted=''' + UPPER(@p_deleted) + N''' where chain_id=@p_chainid and id=@p_id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table = N'ADDRESS',
        @p_dbu_parms = N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>')
                     + N', id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>')
                     + N', flag = ' + COALESCE(CONVERT(NVARCHAR(10), @p_deleted), N'<NULL>'),
        @p_dbu_rows = @p_numrows,
        @p_sql_text = @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>'),
        @p_id = @l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.address
           SET deleted = UPPER(@p_deleted)
         WHERE chain_id = @p_chainid
           AND id = @p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
            THROW 50005, 'DBU [ADDRESS] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text]
                @p_prefix = N'DBU [ADDRESS] unhandled exception encountered:',
                @p_error_text = @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id = @l_id, @p_error = @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_address_full]
    @p_chainid BIGINT = NULL,
    @p_id BIGINT = NULL,
    @p_numrows BIGINT = NULL,
    @p_address_line1 NVARCHAR(4000) = NULL,
    @p_city NVARCHAR(4000) = NULL,
    @p_state NVARCHAR(4000) = NULL,
    @p_zip NVARCHAR(4000) = NULL,
    @p_home_area_code NVARCHAR(4000) = NULL,
    @p_phone BIGINT = NULL,
    @p_deleted NVARCHAR(1) = N'N'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @l_id BIGINT = NULL;
    DECLARE @v_rowsproc BIGINT;
    DECLARE @v_sql NVARCHAR(MAX) = N'update address set <static parameterized update> where chain_id=@p_chainid and id=@p_id';
    DECLARE @v_error NVARCHAR(MAX);

    IF @p_chainid IS NULL THROW 50010, 'DBU [Full ADDRESS] must contain a CHAIN_ID', 1;
    IF @p_id IS NULL THROW 50011, 'DBU [Full ADDRESS] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50012, 'DBU [Full ADDRESS] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50013, 'DBU [Full ADDRESS] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN (N'Y', N'N') THROW 50014, 'DBU [Full ADDRESS] deleted flag is invalid', 1;

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table = N'ADDRESS',
        @p_dbu_parms = N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>')
                     + N', id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>')
                     + N', flag = ' + COALESCE(CONVERT(NVARCHAR(10), @p_deleted), N'<NULL>')
                     + N', address_line1 = ' + COALESCE(@p_address_line1, N'<NULL>')
                     + N', state = ' + COALESCE(@p_state, N'<NULL>')
                     + N', city = ' + COALESCE(@p_city, N'<NULL>')
                     + N', zip = ' + COALESCE(@p_zip, N'<NULL>')
                     + N', home_area_code = ' + COALESCE(@p_home_area_code, N'<NULL>')
                     + N', phone = ' + COALESCE(CONVERT(NVARCHAR(50), @p_phone), N'<NULL>'),
        @p_dbu_rows = @p_numrows,
        @p_sql_text = @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>'),
        @p_id = @l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.address
           SET deleted = CASE WHEN @p_deleted IS NOT NULL THEN UPPER(@p_deleted) ELSE deleted END,
               address_line1 = COALESCE(@p_address_line1, address_line1),
               state = COALESCE(@p_state, state),
               city = COALESCE(@p_city, city),
               postal_code = COALESCE(@p_zip, postal_code),
               home_area_code = COALESCE(@p_home_area_code, home_area_code),
               home_phone = COALESCE(CONVERT(NVARCHAR(50), @p_phone), home_phone)
         WHERE chain_id = @p_chainid
           AND id = @p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
            THROW 50015, 'DBU [Full ADDRESS] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text]
                @p_prefix = N'DBU [Full ADDRESS] unhandled exception encountered:',
                @p_error_text = @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id = @l_id, @p_error = @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_allergy]
    @p_chainid BIGINT = NULL,
    @p_id BIGINT = NULL,
    @p_numrows BIGINT = NULL,
    @p_deleted NVARCHAR(1) = N'N'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update allergy set deleted=''' + UPPER(@p_deleted) + N''' where chain_id=@p_chainid and id=@p_id';
    IF @p_chainid IS NULL THROW 50020, 'DBU [ALLERGY] must contain a CHAIN_ID', 1;
    IF @p_id IS NULL THROW 50021, 'DBU [ALLERGY] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50022, 'DBU [ALLERGY] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50023, 'DBU [ALLERGY] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN (N'Y', N'N') THROW 50024, 'DBU [ALLERGY] deleted flag is invalid', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'ALLERGY',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>') + N', flag = ' + COALESCE(CONVERT(NVARCHAR(10), @p_deleted), N'<NULL>'),
        @p_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.allergy SET deleted = UPPER(@p_deleted) WHERE chain_id = @p_chainid AND id = @p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc THROW 50025, 'DBU [ALLERGY] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [ALLERGY] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_credit_card]
    @p_chainid BIGINT = NULL,
    @p_patientid BIGINT = NULL,
    @p_tokennbr NVARCHAR(4000) = NULL,
    @p_numrows BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'delete PATIENT_CREDIT_CARD where chain_id=@p_chainid and id_patient=@p_patientid and token_number=@p_tokennbr';
    IF @p_chainid IS NULL THROW 50030, 'DBU [CREDIT_CARD] must contain a CHAIN_ID', 1;
    IF @p_patientid IS NULL THROW 50031, 'DBU [CREDIT_CARD] must contain an ID_PATIENT', 1;
    IF @p_tokennbr IS NULL THROW 50032, 'DBU [CREDIT_CARD] must contain a TOKEN_NUMBER', 1;
    IF @p_numrows IS NULL THROW 50033, 'DBU [CREDIT_CARD] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50034, 'DBU [CREDIT_CARD] must be given a rowcount which is > 0', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'CREDIT_CARD',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', id_patient = ' + COALESCE(CONVERT(NVARCHAR(50), @p_patientid), N'<NULL>') + N', token_number = ' + COALESCE(@p_tokennbr, N'<NULL>'),
        @p_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_patientid), N'<NULL>') + N', ' + COALESCE(@p_tokennbr, N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM dbo.patient_credit_card WHERE chain_id = @p_chainid AND id_patient = @p_patientid AND token_number = @p_tokennbr;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc THROW 50035, 'DBU [CREDIT_CARD] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [CREDIT_CARD] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_disease]
    @p_chainid BIGINT = NULL,
    @p_id BIGINT = NULL,
    @p_numrows BIGINT = NULL,
    @p_deleted NVARCHAR(1) = N'N'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update disease set deleted=''' + UPPER(@p_deleted) + N''' where chain_id=@p_chainid and id=@p_id';
    IF @p_chainid IS NULL THROW 50040, 'DBU [DISEASE] must contain a CHAIN_ID', 1;
    IF @p_id IS NULL THROW 50041, 'DBU [DISEASE] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50042, 'DBU [DISEASE] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50043, 'DBU [DISEASE] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN (N'Y', N'N') THROW 50044, 'DBU [DISEASE] deleted flag is invalid', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'DISEASE',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>') + N', flag = ' + COALESCE(CONVERT(NVARCHAR(10), @p_deleted), N'<NULL>'),
        @p_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.disease SET deleted = UPPER(@p_deleted) WHERE chain_id = @p_chainid AND id = @p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc THROW 50045, 'DBU [DISEASE] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [DISEASE] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_medical_condition]
    @p_chainid BIGINT = NULL,
    @p_id BIGINT = NULL,
    @p_numrows BIGINT = NULL,
    @p_deleted NVARCHAR(1) = N'N'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update medical_condition set deleted=''' + UPPER(@p_deleted) + N''' where chain_id=@p_chainid and id=@p_id';
    IF @p_chainid IS NULL THROW 50050, 'DBU [MEDICAL_CONDITION] must contain a CHAIN_ID', 1;
    IF @p_id IS NULL THROW 50051, 'DBU [MEDICAL_CONDITION] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50052, 'DBU [MEDICAL_CONDITION] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50053, 'DBU [MEDICAL_CONDITION] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN (N'Y', N'N') THROW 50054, 'DBU [MEDICAL_CONDITION] deleted flag is invalid', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'MEDICAL_CONDITION',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>') + N', flag = ' + COALESCE(CONVERT(NVARCHAR(10), @p_deleted), N'<NULL>'),
        @p_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.medical_condition SET deleted = UPPER(@p_deleted) WHERE chain_id = @p_chainid AND id = @p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc THROW 50055, 'DBU [MEDICAL_CONDITION] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [MEDICAL_CONDITION] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_patient]
    @p_chainid BIGINT = NULL,
    @p_rxcomid BIGINT = NULL,
    @p_numrows BIGINT = NULL,
    @p_deleted NVARCHAR(1) = N'N'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update patient set multibirth=''' + UPPER(@p_deleted) + N''' where chain_id=@p_chainid and rx_com_id=@p_rxcomid';
    IF @p_chainid IS NULL THROW 50060, 'DBU [PATIENT] must contain a CHAIN_ID', 1;
    IF @p_rxcomid IS NULL THROW 50061, 'DBU [PATIENT] must contain an RX_COM_ID', 1;
    IF @p_numrows IS NULL THROW 50062, 'DBU [PATIENT] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50063, 'DBU [PATIENT] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN (N'Y', N'N') THROW 50064, 'DBU [PATIENT] deleted flag is invalid', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'PATIENT',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', rx_com_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_rxcomid), N'<NULL>') + N', flag = ' + COALESCE(CONVERT(NVARCHAR(10), @p_deleted), N'<NULL>'),
        @p_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_rxcomid), N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.patient SET multibirth = UPPER(@p_deleted) WHERE chain_id = @p_chainid AND rx_com_id = @p_rxcomid;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc THROW 50065, 'DBU [PATIENT] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [PATIENT] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_patient_dls]
    @p_chainid BIGINT = NULL,
    @p_id BIGINT = NULL,
    @p_rxcomid BIGINT = NULL,
    @p_state NVARCHAR(2) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_numrows BIGINT = 1, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update patient set driver_license_state=' + COALESCE(N'''' + UPPER(@p_state) + N'''', N'NULL') + N' where chain_id=@p_chainid and id=@p_id and rx_com_id=@p_rxcomid';
    IF @p_chainid IS NULL THROW 50070, 'DBU [PATIENT_DLS] must contain a CHAIN_ID', 1;
    IF @p_id IS NULL THROW 50071, 'DBU [PATIENT_DLS] must contain an ID', 1;
    IF @p_rxcomid IS NULL THROW 50072, 'DBU [PATIENT_DLS] must contain an RX_COM_ID', 1;
    IF @p_state IS NOT NULL AND LEN(@p_state) <> 2 THROW 50073, 'DBU [PATIENT_DLS] must be give a two character state', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'PATIENT',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>') + N', rx_com_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_rxcomid), N'<NULL>') + N', state = ' + COALESCE(@p_state, N'<NULL>'),
        1,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_rxcomid), N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.patient SET driver_license_state = CASE WHEN @p_state IS NULL THEN NULL ELSE UPPER(@p_state) END WHERE chain_id = @p_chainid AND id = @p_id AND rx_com_id = @p_rxcomid;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @v_numrows <> @v_rowsproc THROW 50074, 'DBU [PATIENT_DLS] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [PATIENT_DLS] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_patient_emergency_contact]
    @p_chainid BIGINT = NULL,
    @p_id BIGINT = NULL,
    @p_numrows BIGINT = NULL,
    @p_phone NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update patient_emergency_contact set phone_number=''' + COALESCE(@p_phone, N'<NULL>') + N''' where chain_id=@p_chainid and id=@p_id';
    IF @p_chainid IS NULL THROW 50080, 'DBU [PATIENT_EMERGENCY_CONTACT] must contain a CHAIN_ID', 1;
    IF @p_id IS NULL THROW 50081, 'DBU [PATIENT_EMERGENCY_CONTACT] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50082, 'DBU [PATIENT_EMERGENCY_CONTACT] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50083, 'DBU [PATIENT_EMERGENCY_CONTACT] must be given a rowcount which is > 0', 1;
    IF @p_phone IS NULL THROW 50084, 'DBU [PATIENT_EMERGENCY_CONTACT] must contain a PHONE_NUMBER', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'PATIENT_EMERGENCY_CONTACT',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>') + N', phone = ' + COALESCE(@p_phone, N'<NULL>'),
        @p_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.patient_emergency_contact SET phone_number = @p_phone WHERE chain_id = @p_chainid AND id = @p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc THROW 50085, 'DBU [PATIENT_EMERGENCY_CONTACT] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [PATIENT_EMERGENCY_CONTACT] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_patient_no_cf]
    @p_chainid BIGINT = NULL,
    @p_nhinid BIGINT = NULL,
    @p_no_cf_flag NCHAR(1) = NULL,
    @p_numrows BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update patient set no_cf_flag=@p_no_cf_flag where chain_id=@p_chainid and nhin_id=@p_nhinid';
    IF @p_chainid IS NULL THROW 50100, 'DBU [PATIENT_NO_CF] must contain a CHAIN_ID', 1;
    IF @p_nhinid IS NULL THROW 50101, 'DBU [PATIENT_NO_CF] must contain an NHIN_ID', 1;
    IF @p_no_cf_flag IS NULL THROW 50102, 'DBU [PATIENT_NO_CF] must contain a NO_CF_FLAG', 1;
    IF UPPER(@p_no_cf_flag) NOT IN (N'Y', N'N') THROW 50103, 'DBU [PATIENT_NO_CF] no_cf_flag is invalid', 1;
    IF @p_numrows IS NULL THROW 50104, 'DBU [PATIENT_NO_CF] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50105, 'DBU [PATIENT_NO_CF] must be given a rowcount which is > 0', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'PATIENT',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', nhin_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_nhinid), N'<NULL>') + N', no_cf_flag = ' + COALESCE(CONVERT(NVARCHAR(10), @p_no_cf_flag), N'<NULL>'),
        @p_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_nhinid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(10), @p_no_cf_flag), N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.patient SET no_cf_flag = UPPER(@p_no_cf_flag) WHERE chain_id = @p_chainid AND nhin_id = @p_nhinid;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc THROW 50106, 'DBU [PATIENT_NO_CF] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [PATIENT_NO_CF] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_prior_adverse_reaction]
    @p_chainid BIGINT = NULL,
    @p_id BIGINT = NULL,
    @p_numrows BIGINT = NULL,
    @p_deleted NVARCHAR(1) = N'N'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update prior_adverse_reaction set deleted=@p_deleted where chain_id=@p_chainid and id=@p_id';
    IF @p_chainid IS NULL THROW 50110, 'DBU [PRIOR_ADVERSE_REACTION] must contain a CHAIN_ID', 1;
    IF @p_id IS NULL THROW 50111, 'DBU [PRIOR_ADVERSE_REACTION] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50112, 'DBU [PRIOR_ADVERSE_REACTION] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50113, 'DBU [PRIOR_ADVERSE_REACTION] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN (N'Y', N'N') THROW 50114, 'DBU [PRIOR_ADVERSE_REACTION] deleted flag is invalid', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'PRIOR_ADVERSE_REACTION',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>') + N', flag = ' + COALESCE(CONVERT(NVARCHAR(10), @p_deleted), N'<NULL>'),
        @p_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_id), N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.prior_adverse_reaction SET deleted = UPPER(@p_deleted) WHERE chain_id = @p_chainid AND id = @p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc THROW 50115, 'DBU [PRIOR_ADVERSE_REACTION] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [PRIOR_ADVERSE_REACTION] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_rxtx]
    @p_chainid BIGINT = NULL,
    @p_nhinid BIGINT = NULL,
    @p_idpatient BIGINT = NULL,
    @p_txnumber BIGINT = NULL,
    @p_numrows BIGINT = NULL,
    @p_deleted NVARCHAR(1) = N'N'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update rxtx set deleted=''' + UPPER(@p_deleted) + N''' where chain_id=@p_chainid and nhin_id=@p_nhinid and id_patient=@p_idpatient and tx_number=@p_txnumber';
    IF @p_chainid IS NULL THROW 50090, 'DBU [RXTX] must contain a CHAIN_ID', 1;
    IF @p_nhinid IS NULL THROW 50091, 'DBU [RXTX] must contain an NHIN_ID', 1;
    IF @p_idpatient IS NULL THROW 50092, 'DBU [RXTX] must contain an ID_PATIENT', 1;
    IF @p_txnumber IS NULL THROW 50093, 'DBU [RXTX] must contain a TX_NUMBER', 1;
    IF @p_numrows IS NULL THROW 50094, 'DBU [RXTX] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0 THROW 50095, 'DBU [RXTX] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN (N'Y', N'N') THROW 50096, 'DBU [RXTX] deleted flag is invalid', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'RXTX',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', nhin_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_nhinid), N'<NULL>') + N', id_patient = ' + COALESCE(CONVERT(NVARCHAR(50), @p_idpatient), N'<NULL>') + N', tx_number = ' + COALESCE(CONVERT(NVARCHAR(50), @p_txnumber), N'<NULL>') + N', flag = ' + COALESCE(CONVERT(NVARCHAR(10), @p_deleted), N'<NULL>'),
        @p_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_nhinid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_idpatient), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_txnumber), N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.rxtx SET deleted = UPPER(@p_deleted) WHERE chain_id = @p_chainid AND nhin_id = @p_nhinid AND id_patient = @p_idpatient AND tx_number = @p_txnumber;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc THROW 50097, 'DBU [RXTX] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [RXTX] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_tplink_levelof]
    @p_chainid BIGINT = NULL,
    @p_tplinkid BIGINT = NULL,
    @p_levelof NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @l_id BIGINT = NULL, @v_rowsproc BIGINT, @v_numrows BIGINT = 1, @v_error NVARCHAR(MAX);
    DECLARE @v_sql NVARCHAR(MAX) = N'update tplink set level_of=@p_levelof where chain_id=@p_chainid and id=@p_tplinkid';
    IF @p_chainid IS NULL THROW 50120, 'DBU [TPLINK_LEVELOF] must contain a CHAIN_ID', 1;
    IF @p_tplinkid IS NULL THROW 50121, 'DBU [TPLINK_LEVELOF] must contain a TPLINK_ID', 1;
    IF @p_levelof IS NULL THROW 50122, 'DBU [TPLINK_LEVELOF] must contain a LEVEL_OF value', 1;
    EXEC [EPS].[CS_SUPPORT_log_audit_dbu] N'TPLINK',
        N'chain_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', tplink_id = ' + COALESCE(CONVERT(NVARCHAR(50), @p_tplinkid), N'<NULL>') + N', level_of = ' + COALESCE(@p_levelof, N'<NULL>'),
        @v_numrows,
        @v_sql + CHAR(10) + N'Using: ' + COALESCE(CONVERT(NVARCHAR(50), @p_chainid), N'<NULL>') + N', ' + COALESCE(CONVERT(NVARCHAR(50), @p_tplinkid), N'<NULL>') + N', ' + COALESCE(@p_levelof, N'<NULL>'),
        @l_id OUTPUT;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.tplink SET level_of = @p_levelof WHERE chain_id = @p_chainid AND id = @p_tplinkid;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @v_numrows <> @v_rowsproc THROW 50123, 'DBU [TPLINK_LEVELOF] processed unexpected row count', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @l_id IS NOT NULL
        BEGIN
            EXEC [EPS].[CS_SUPPORT_build_error_text] N'DBU [TPLINK_LEVELOF] unhandled exception encountered:', @v_error OUTPUT;
            EXEC [EPS].[CS_SUPPORT_log_error] @l_id, @v_error;
        END
        THROW;
    END CATCH;
END;
GO

-- Final production readiness still depends on target schema/type verification and logging durability expectations.
