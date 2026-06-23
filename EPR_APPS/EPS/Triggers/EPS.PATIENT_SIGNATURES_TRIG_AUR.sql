-- TRIGGER: [EPS].[PATIENT_SIGNATURES_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[PATIENT_SIGNATURES_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PATIENT_SIGNATURES_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[PATIENT_SIGNATURES_TRIG_AUR]
ON [EPS].[PATIENT_SIGNATURES]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[PATIENT_SIGNATURES_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [ID_AAL],
        [LAST_UPDATED],
        [NHIN_ID],
        [DOC_SPEED_CODE],
        [DOC_NAME],
        [DOC_VERSION],
        [DOC_STATE],
        [DOC_LANG],
        [IMMUTABLE],
        [DELETED],
        [STATUS],
        [STATUS_UPDATE_DATE],
        [SIGNATURE_HASH],
        [SIGNATURE_CAPTURE_MODE],
        [ACQUIRED_BY_USER],
        [ACQUIRED_AT_STORE_NHIN_ID],
        [ACQUIRED_DATE],
        [REVOKED_BY_USER],
        [REVOKED_AT_STORE_NHIN_ID],
        [REVOKED_DATE],
        [REFUSED_DATE],
        [EXPIRY_DATE],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [ID_AAL],
        [LAST_UPDATED],
        [NHIN_ID],
        [DOC_SPEED_CODE],
        [DOC_NAME],
        [DOC_VERSION],
        [DOC_STATE],
        [DOC_LANG],
        [IMMUTABLE],
        [DELETED],
        [STATUS],
        [STATUS_UPDATE_DATE],
        [SIGNATURE_HASH],
        [SIGNATURE_CAPTURE_MODE],
        [ACQUIRED_BY_USER],
        [ACQUIRED_AT_STORE_NHIN_ID],
        [ACQUIRED_DATE],
        [REVOKED_BY_USER],
        [REVOKED_AT_STORE_NHIN_ID],
        [REVOKED_DATE],
        [REFUSED_DATE],
        [EXPIRY_DATE],
        NEXT VALUE FOR [EPS].[PATIENT_SIGNATURES_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
