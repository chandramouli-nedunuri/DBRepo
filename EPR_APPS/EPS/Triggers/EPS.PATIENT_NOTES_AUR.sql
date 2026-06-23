-- TRIGGER: [EPS].[PATIENT_NOTES_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[PATIENT_NOTES_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PATIENT_NOTES_AUR];
GO

CREATE TRIGGER [EPS].[PATIENT_NOTES_AUR]
ON [EPS].[PATIENT_NOTES]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[PATIENT_NOTES_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ID_AAL],
        [LAST_UPDATED],
        [DEACTIVATE_DATE],
        [DEACTIVATE_USER],
        [ID_PATIENT],
        [GUID],
        [NOTE],
        [DISPLAY_DE],
        [DISPLAY_DE_QA],
        [DISPLAY_FILL],
        [DISPLAY_OE],
        [DISPLAY_QA],
        [DISPLAY_WC],
        [DISPLAY_NEW_RX],
        [DISPLAY_CALL],
        [CREATE_DATE],
        [USER_ID],
        [ELIGIBLE_TO_PRINT],
        [EXPIRATION_DATE],
        [CREATED_STORE_NHINID],
        [DISPLAY_PAE],
        [DISPLAY_RPH_PATIENT_NOTE_IN_DV],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ID_AAL],
        [LAST_UPDATED],
        [DEACTIVATE_DATE],
        [DEACTIVATE_USER],
        [ID_PATIENT],
        [GUID],
        [NOTE],
        [DISPLAY_DE],
        [DISPLAY_DE_QA],
        [DISPLAY_FILL],
        [DISPLAY_OE],
        [DISPLAY_QA],
        [DISPLAY_WC],
        [DISPLAY_NEW_RX],
        [DISPLAY_CALL],
        [CREATE_DATE],
        [USER_ID],
        [ELIGIBLE_TO_PRINT],
        [EXPIRATION_DATE],
        [CREATED_STORE_NHINID],
        [DISPLAY_PAE],
        [DISPLAY_RPH_PATIENT_NOTE_IN_DV],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
