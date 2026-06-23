-- ============================================================================
-- Converted: Oracle Package EPS.AUDIT_IU2 -> Azure SQL Stored Procedures
-- Conversion Date: 2026-05-25
-- ============================================================================

-- Procedure 1: aal_insert
CREATE PROCEDURE [EPS].[AUDIT_IU2_aal_insert]
    @p_chain_id                   NUMERIC,
    @p_aal_id                     NUMERIC,
    @p_incoming_timestamp         DATETIME2,
    @p_before_appserver_timestamp DATETIME2,
    @p_pdx_message_id             VARCHAR(MAX),
    @p_client_ip                  VARCHAR(MAX),
    @p_client_id_type             VARCHAR(MAX),
    @p_nhin_id                    NUMERIC,
    @p_service                    VARCHAR(MAX),
    @p_audit_mode                 VARCHAR(MAX),
    @p_code                        VARCHAR(MAX),
    @p_first_name                 VARCHAR(MAX),
    @p_middle_name                VARCHAR(MAX),
    @p_last_name                  VARCHAR(MAX),
    @p_initials                   VARCHAR(MAX),
    @p_user_id                    VARCHAR(MAX),
    @p_license_number             VARCHAR(MAX),
    @p_software_version_number    VARCHAR(MAX),
    @p_message_version_number     VARCHAR(MAX),
    @p_request_content_size       NUMERIC,
    @p_request_xml                VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO audit_access_log (
        chain_id, id, incoming_timestamp,
        before_appserver_timestamp, pdx_message_id,
        client_ip, client_id_type, nhin_id, [service],
        audit_mode, code, first_name, middle_name,
        last_name, initials, user_id, license_number,
        software_version_number,
        message_version_number, request_content_size
    )
    VALUES (
        @p_chain_id, @p_aal_id, @p_incoming_timestamp,
        @p_before_appserver_timestamp, @p_pdx_message_id, @p_client_ip,
        @p_client_id_type, @p_nhin_id, @p_service, @p_audit_mode, @p_code,
        @p_first_name, @p_middle_name, @p_last_name, @p_initials, @p_user_id,
        @p_license_number, @p_software_version_number,
        @p_message_version_number, @p_request_content_size
    );

    IF @p_request_xml IS NOT NULL
    BEGIN
        INSERT INTO audit_message_content (
            chain_id, id, message_content, [type], id_aal
        )
        VALUES (
            @p_chain_id, (@p_aal_id + 1), @p_request_xml, 'request', @p_aal_id
        );
    END
END;
GO

-- Procedure 2: aal_update (First Overload)
CREATE PROCEDURE [EPS].[AUDIT_IU2_aal_update]
    @p_chain_id                  NUMERIC,
    @p_aal_id                    NUMERIC,
    @p_status                    VARCHAR(MAX),
    @p_after_appserver_timestamp DATETIME2,
    @p_outgoing_timestamp        DATETIME2,
    @p_response_content_size     NUMERIC,
    @p_response_xml              VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE audit_access_log
    SET [status] = @p_status,
        response_content_size = @p_response_content_size,
        after_appserver_timestamp = @p_after_appserver_timestamp,
        outgoing_timestamp = @p_outgoing_timestamp
    WHERE chain_id = @p_chain_id
      AND id = @p_aal_id;

    IF @p_response_xml IS NOT NULL
    BEGIN
        INSERT INTO audit_message_content (
            chain_id, id, message_content, [type], id_aal
        )
        VALUES (
            @p_chain_id, (@p_aal_id + 2), @p_response_xml, 'response', @p_aal_id
        );
    END
END;
GO

-- Procedure 3: aal_update (Second Overload - with request_content_size and request_xml)
CREATE PROCEDURE [EPS].[AUDIT_IU2_aal_update_v2]
    @p_chain_id                  NUMERIC,
    @p_aal_id                    NUMERIC,
    @p_status                    VARCHAR(MAX),
    @p_after_appserver_timestamp DATETIME2,
    @p_outgoing_timestamp        DATETIME2,
    @p_response_content_size     NUMERIC,
    @p_response_xml              VARBINARY(MAX),
    @p_request_content_size      NUMERIC,
    @p_request_xml               VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE audit_access_log
    SET [status] = @p_status,
        response_content_size = @p_response_content_size,
        after_appserver_timestamp = @p_after_appserver_timestamp,
        outgoing_timestamp = @p_outgoing_timestamp,
        request_content_size = @p_request_content_size
    WHERE chain_id = @p_chain_id
      AND id = @p_aal_id;

    IF @p_request_xml IS NOT NULL
    BEGIN
        INSERT INTO audit_message_content (
            chain_id, id, message_content, [type], id_aal
        )
        VALUES (
            @p_chain_id, (@p_aal_id + 1), @p_request_xml, 'request', @p_aal_id
        );
    END

    IF @p_response_xml IS NOT NULL
    BEGIN
        INSERT INTO audit_message_content (
            chain_id, id, message_content, [type], id_aal
        )
        VALUES (
            @p_chain_id, (@p_aal_id + 2), @p_response_xml, 'response', @p_aal_id
        );
    END
END;
GO

-- Procedure 4: aal_insert2
CREATE PROCEDURE [EPS].[AUDIT_IU2_aal_insert2]
    @p_chain_id                   NUMERIC,
    @p_aal_id                     NUMERIC,
    @p_hash_value                 NUMERIC,
    @p_incoming_timestamp         DATETIME2,
    @p_before_appserver_timestamp DATETIME2,
    @p_pdx_message_id             VARCHAR(MAX),
    @p_client_ip                  VARCHAR(MAX),
    @p_client_id_type             VARCHAR(MAX),
    @p_nhin_id                    NUMERIC,
    @p_service                    VARCHAR(MAX),
    @p_audit_mode                 VARCHAR(MAX),
    @p_code                        VARCHAR(MAX),
    @p_first_name                 VARCHAR(MAX),
    @p_middle_name                VARCHAR(MAX),
    @p_last_name                  VARCHAR(MAX),
    @p_initials                   VARCHAR(MAX),
    @p_user_id                    VARCHAR(MAX),
    @p_license_number             VARCHAR(MAX),
    @p_software_version_number    VARCHAR(MAX),
    @p_message_version_number     VARCHAR(MAX),
    @p_status                     VARCHAR(MAX),
    @p_after_appserver_timestamp  DATETIME2,
    @p_outgoing_timestamp         DATETIME2,
    @p_request_id                 NUMERIC,
    @p_request_content_size       NUMERIC,
    @p_request_xml                VARBINARY(MAX),
    @p_response_id                NUMERIC,
    @p_response_content_size      NUMERIC,
    @p_response_xml               VARBINARY(MAX),
    @p_server_name                VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO audit_access_log (
        chain_id, id, incoming_timestamp,
        before_appserver_timestamp, pdx_message_id,
        client_ip, client_id_type, nhin_id, [service],
        audit_mode, code, first_name, middle_name,
        last_name, initials, user_id, license_number,
        software_version_number,
        message_version_number, [status],
        after_appserver_timestamp, outgoing_timestamp,
        request_content_size, response_content_size,
        hash_value, server_name
    )
    VALUES (
        @p_chain_id, @p_aal_id, @p_incoming_timestamp,
        @p_before_appserver_timestamp, @p_pdx_message_id, @p_client_ip,
        @p_client_id_type, @p_nhin_id, @p_service, @p_audit_mode, @p_code,
        @p_first_name, @p_middle_name, @p_last_name, @p_initials, @p_user_id,
        @p_license_number, @p_software_version_number,
        @p_message_version_number, @p_status, @p_after_appserver_timestamp,
        @p_outgoing_timestamp, @p_request_content_size,
        @p_response_content_size, @p_hash_value, @p_server_name
    );

    IF @p_request_xml IS NOT NULL
    BEGIN
        INSERT INTO audit_message_content (
            chain_id, id, message_content, [type], id_aal
        )
        VALUES (
            @p_chain_id, @p_request_id, @p_request_xml, 'request', @p_aal_id
        );
    END

    IF @p_response_xml IS NOT NULL
    BEGIN
        INSERT INTO audit_message_content (
            chain_id, id, message_content, [type], id_aal
        )
        VALUES (
            @p_chain_id, @p_response_id, @p_response_xml, 'response', @p_aal_id
        );
    END
END;
GO

-- Procedure 5: aal_insert3
CREATE PROCEDURE [EPS].[AUDIT_IU2_aal_insert3]
    @p_chain_id                   NUMERIC,
    @p_aal_id                     NUMERIC,
    @p_hash_value                 NUMERIC,
    @p_incoming_timestamp         DATETIME2,
    @p_before_appserver_timestamp DATETIME2,
    @p_pdx_message_id             VARCHAR(MAX),
    @p_client_ip                  VARCHAR(MAX),
    @p_client_id_type             VARCHAR(MAX),
    @p_nhin_id                    NUMERIC,
    @p_service                    VARCHAR(MAX),
    @p_audit_mode                 VARCHAR(MAX),
    @p_code                        VARCHAR(MAX),
    @p_first_name                 VARCHAR(MAX),
    @p_middle_name                VARCHAR(MAX),
    @p_last_name                  VARCHAR(MAX),
    @p_initials                   VARCHAR(MAX),
    @p_user_id                    VARCHAR(MAX),
    @p_license_number             VARCHAR(MAX),
    @p_software_version_number    VARCHAR(MAX),
    @p_message_version_number     VARCHAR(MAX),
    @p_status                     VARCHAR(MAX),
    @p_after_appserver_timestamp  DATETIME2,
    @p_outgoing_timestamp         DATETIME2,
    @p_request_id                 NUMERIC,
    @p_request_content_size       NUMERIC,
    @p_request_xml                VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO audit_access_log (
        chain_id, id, incoming_timestamp,
        before_appserver_timestamp, pdx_message_id,
        client_ip, client_id_type, nhin_id, [service],
        audit_mode, code, first_name, middle_name,
        last_name, initials, user_id, license_number,
        software_version_number,
        message_version_number, [status],
        after_appserver_timestamp, outgoing_timestamp,
        request_content_size, response_content_size
    )
    VALUES (
        @p_chain_id, @p_aal_id, @p_incoming_timestamp,
        @p_before_appserver_timestamp, @p_pdx_message_id, @p_client_ip,
        @p_client_id_type, @p_nhin_id, @p_service, @p_audit_mode, @p_code,
        @p_first_name, @p_middle_name, @p_last_name, @p_initials, @p_user_id,
        @p_license_number, @p_software_version_number,
        @p_message_version_number, @p_status, @p_after_appserver_timestamp,
        @p_outgoing_timestamp, @p_request_content_size, 0
    );

    INSERT INTO audit_message_content (
        chain_id, id, message_content, [type], id_aal
    )
    VALUES (
        @p_chain_id, @p_request_id, @p_request_xml, 'request', @p_aal_id
    );
END;
GO

-- Procedure 6: aal_update3
CREATE PROCEDURE [EPS].[AUDIT_IU2_aal_update3]
    @p_chain_id                  NUMERIC,
    @p_aal_id                    NUMERIC,
    @p_status                    VARCHAR(MAX),
    @p_after_appserver_timestamp DATETIME2,
    @p_outgoing_timestamp        DATETIME2,
    @p_response_id               NUMERIC,
    @p_response_content_size     NUMERIC,
    @p_response_xml              VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE audit_access_log
    SET [status] = @p_status,
        response_content_size = @p_response_content_size,
        after_appserver_timestamp = @p_after_appserver_timestamp,
        outgoing_timestamp = @p_outgoing_timestamp
    WHERE chain_id = @p_chain_id
      AND id = @p_aal_id;

    INSERT INTO audit_message_content (
        chain_id, id, message_content, [type], id_aal
    )
    VALUES (
        @p_chain_id, @p_response_id, @p_response_xml, 'response', @p_aal_id
    );
END;
GO

-- Procedure 7: aal_message
CREATE PROCEDURE [EPS].[AUDIT_IU2_aal_message]
    @p_chain_id   NUMERIC,
    @p_id         NUMERIC,
    @p_request_xml VARBINARY(MAX),
    @p_type       VARCHAR(MAX),
    @p_aal_id     NUMERIC
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO audit_message_content (
        chain_id, id, message_content, [type], id_aal
    )
    VALUES (
        @p_chain_id, @p_id, @p_request_xml, @p_type, @p_aal_id
    );
END;
GO
