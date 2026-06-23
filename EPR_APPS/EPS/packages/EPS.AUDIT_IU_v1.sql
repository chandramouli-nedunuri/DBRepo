-- Production-oriented Azure SQL conversion of Oracle package EPS.AUDIT_IU
-- Variant: SESSION_CONTEXT-based chain_id handling
-- Source: Packages/EPS.AUDIT_IU.txt
-- Target: Azure SQL / T-SQL
-- File: Azure SQL/Packages/EPS.AUDIT_IU_v1.sql

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'EPS')
BEGIN
    EXEC('CREATE SCHEMA [EPS]');
END;
GO

/*
Expected calling pattern for procedures that depend on Oracle-style session chain context:
    EXEC sys.sp_set_session_context @key = N'chain_id', @value = <chain_id>;

This file uses SESSION_CONTEXT('chain_id') as the Azure SQL replacement for Oracle:
    vpdadm.set_chain_id;
*/

CREATE OR ALTER PROCEDURE [EPS].[AUDIT_IU_aal_insert]
    @p_aal_id BIGINT,
    @p_incoming_timestamp DATETIME2(7),
    @p_before_appserver_timestamp DATETIME2(7),
    @p_pdx_message_id NVARCHAR(4000),
    @p_client_ip NVARCHAR(4000),
    @p_client_id_type NVARCHAR(4000),
    @p_nhin_id BIGINT,
    @p_service NVARCHAR(4000),
    @p_audit_mode NVARCHAR(4000),
    @p_code NVARCHAR(4000),
    @p_first_name NVARCHAR(4000),
    @p_middle_name NVARCHAR(4000),
    @p_last_name NVARCHAR(4000),
    @p_initials NVARCHAR(4000),
    @p_user_id NVARCHAR(4000),
    @p_license_number NVARCHAR(4000),
    @p_software_version_number NVARCHAR(4000),
    @p_message_version_number NVARCHAR(4000),
    @p_request_content_size BIGINT,
    @p_request_xml VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @session_chain_id BIGINT = TRY_CAST(SESSION_CONTEXT(N'chain_id') AS BIGINT);

    IF @session_chain_id IS NULL
        THROW 50001, 'SESSION_CONTEXT chain_id is not set.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.audit_access_log
        (
            chain_id,
            id,
            incoming_timestamp,
            before_appserver_timestamp,
            pdx_message_id,
            client_ip,
            client_id_type,
            nhin_id,
            service,
            audit_mode,
            code,
            first_name,
            middle_name,
            last_name,
            initials,
            user_id,
            license_number,
            software_version_number,
            message_version_number,
            request_content_size
        )
        VALUES
        (
            @session_chain_id,
            @p_aal_id,
            @p_incoming_timestamp,
            @p_before_appserver_timestamp,
            @p_pdx_message_id,
            @p_client_ip,
            @p_client_id_type,
            @p_nhin_id,
            @p_service,
            @p_audit_mode,
            @p_code,
            @p_first_name,
            @p_middle_name,
            @p_last_name,
            @p_initials,
            @p_user_id,
            @p_license_number,
            @p_software_version_number,
            @p_message_version_number,
            @p_request_content_size
        );

        IF @p_request_xml IS NOT NULL
        BEGIN
            INSERT INTO dbo.audit_message_content
            (
                chain_id,
                id,
                message_content,
                type,
                id_aal
            )
            VALUES
            (
                @session_chain_id,
                @p_aal_id + 1,
                @p_request_xml,
                N'request',
                @p_aal_id
            );
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[AUDIT_IU_aal_update]
    @p_chain_id BIGINT,
    @p_aal_id BIGINT,
    @p_status NVARCHAR(4000),
    @p_after_appserver_timestamp DATETIME2(7),
    @p_outgoing_timestamp DATETIME2(7),
    @p_response_content_size BIGINT,
    @p_response_xml VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @session_chain_id BIGINT = TRY_CAST(SESSION_CONTEXT(N'chain_id') AS BIGINT);

    IF @session_chain_id IS NULL
        THROW 50002, 'SESSION_CONTEXT chain_id is not set.', 1;

    IF @session_chain_id <> @p_chain_id
        THROW 50003, 'Procedure chain_id does not match SESSION_CONTEXT chain_id.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.audit_access_log
           SET status = @p_status,
               response_content_size = @p_response_content_size,
               after_appserver_timestamp = @p_after_appserver_timestamp,
               outgoing_timestamp = @p_outgoing_timestamp
         WHERE chain_id = @p_chain_id
           AND id = @p_aal_id;

        IF @@ROWCOUNT <> 1
            THROW 50007, 'Expected exactly one row to be updated in audit_access_log.', 1;

        IF @p_response_xml IS NOT NULL
        BEGIN
            INSERT INTO dbo.audit_message_content
            (
                chain_id,
                id,
                message_content,
                type,
                id_aal
            )
            VALUES
            (
                @p_chain_id,
                @p_aal_id + 2,
                @p_response_xml,
                N'response',
                @p_aal_id
            );
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[AUDIT_IU_aal_update_with_request]
    @p_chain_id BIGINT,
    @p_aal_id BIGINT,
    @p_status NVARCHAR(4000),
    @p_after_appserver_timestamp DATETIME2(7),
    @p_outgoing_timestamp DATETIME2(7),
    @p_response_content_size BIGINT,
    @p_response_xml VARBINARY(MAX),
    @p_request_content_size BIGINT,
    @p_request_xml VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @session_chain_id BIGINT = TRY_CAST(SESSION_CONTEXT(N'chain_id') AS BIGINT);

    IF @session_chain_id IS NULL
        THROW 50004, 'SESSION_CONTEXT chain_id is not set.', 1;

    IF @session_chain_id <> @p_chain_id
        THROW 50005, 'Procedure chain_id does not match SESSION_CONTEXT chain_id.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.audit_access_log
           SET status = @p_status,
               response_content_size = @p_response_content_size,
               after_appserver_timestamp = @p_after_appserver_timestamp,
               outgoing_timestamp = @p_outgoing_timestamp,
               request_content_size = @p_request_content_size
         WHERE chain_id = @p_chain_id
           AND id = @p_aal_id;

        IF @@ROWCOUNT <> 1
            THROW 50008, 'Expected exactly one row to be updated in audit_access_log.', 1;

        IF @p_request_xml IS NOT NULL
        BEGIN
            INSERT INTO dbo.audit_message_content
            (
                chain_id,
                id,
                message_content,
                type,
                id_aal
            )
            VALUES
            (
                @p_chain_id,
                @p_aal_id + 1,
                @p_request_xml,
                N'request',
                @p_aal_id
            );
        END

        IF @p_response_xml IS NOT NULL
        BEGIN
            INSERT INTO dbo.audit_message_content
            (
                chain_id,
                id,
                message_content,
                type,
                id_aal
            )
            VALUES
            (
                @p_chain_id,
                @p_aal_id + 2,
                @p_response_xml,
                N'response',
                @p_aal_id
            );
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[AUDIT_IU_aal_insert2]
    @p_aal_id BIGINT,
    @p_hash_value BIGINT,
    @p_incoming_timestamp DATETIME2(7),
    @p_before_appserver_timestamp DATETIME2(7),
    @p_pdx_message_id NVARCHAR(4000),
    @p_client_ip NVARCHAR(4000),
    @p_client_id_type NVARCHAR(4000),
    @p_nhin_id BIGINT,
    @p_service NVARCHAR(4000),
    @p_audit_mode NVARCHAR(4000),
    @p_code NVARCHAR(4000),
    @p_first_name NVARCHAR(4000),
    @p_middle_name NVARCHAR(4000),
    @p_last_name NVARCHAR(4000),
    @p_initials NVARCHAR(4000),
    @p_user_id NVARCHAR(4000),
    @p_license_number NVARCHAR(4000),
    @p_software_version_number NVARCHAR(4000),
    @p_message_version_number NVARCHAR(4000),
    @p_status NVARCHAR(4000),
    @p_after_appserver_timestamp DATETIME2(7),
    @p_outgoing_timestamp DATETIME2(7),
    @p_request_content_size BIGINT,
    @p_request_xml VARBINARY(MAX),
    @p_response_content_size BIGINT,
    @p_response_xml VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @session_chain_id BIGINT = TRY_CAST(SESSION_CONTEXT(N'chain_id') AS BIGINT);

    IF @session_chain_id IS NULL
        THROW 50006, 'SESSION_CONTEXT chain_id is not set.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.audit_access_log
        (
            chain_id,
            id,
            incoming_timestamp,
            before_appserver_timestamp,
            pdx_message_id,
            client_ip,
            client_id_type,
            nhin_id,
            service,
            audit_mode,
            code,
            first_name,
            middle_name,
            last_name,
            initials,
            user_id,
            license_number,
            software_version_number,
            message_version_number,
            status,
            after_appserver_timestamp,
            outgoing_timestamp,
            request_content_size,
            response_content_size,
            hash_value
        )
        VALUES
        (
            @session_chain_id,
            @p_aal_id,
            @p_incoming_timestamp,
            @p_before_appserver_timestamp,
            @p_pdx_message_id,
            @p_client_ip,
            @p_client_id_type,
            @p_nhin_id,
            @p_service,
            @p_audit_mode,
            @p_code,
            @p_first_name,
            @p_middle_name,
            @p_last_name,
            @p_initials,
            @p_user_id,
            @p_license_number,
            @p_software_version_number,
            @p_message_version_number,
            @p_status,
            @p_after_appserver_timestamp,
            @p_outgoing_timestamp,
            @p_request_content_size,
            @p_response_content_size,
            @p_hash_value
        );

        IF @p_request_xml IS NOT NULL
        BEGIN
            INSERT INTO dbo.audit_message_content
            (
                chain_id,
                id,
                message_content,
                type,
                id_aal
            )
            VALUES
            (
                @session_chain_id,
                @p_aal_id + 1,
                @p_request_xml,
                N'request',
                @p_aal_id
            );
        END

        IF @p_response_xml IS NOT NULL
        BEGIN
            INSERT INTO dbo.audit_message_content
            (
                chain_id,
                id,
                message_content,
                type,
                id_aal
            )
            VALUES
            (
                @session_chain_id,
                @p_aal_id + 2,
                @p_response_xml,
                N'response',
                @p_aal_id
            );
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
