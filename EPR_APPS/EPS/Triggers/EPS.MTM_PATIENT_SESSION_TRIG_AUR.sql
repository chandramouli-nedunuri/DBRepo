-- TRIGGER: [EPS].[MTM_PATIENT_SESSION_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[MTM_PATIENT_SESSION_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[MTM_PATIENT_SESSION_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[MTM_PATIENT_SESSION_TRIG_AUR]
ON [EPS].[MTM_PATIENT_SESSION]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[MTM_PATIENT_SESSION_AUDIT] (
        [CHAIN_ID],
        [ID],
        [RUN_DATE],
        [SCORE],
        [SCORE_TEXT],
        [STATUS],
        [ID_SIGNATURE],
        [ID_AAL],
        [LAST_UPDATED],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [RUN_DATE],
        [SCORE],
        [SCORE_TEXT],
        [STATUS],
        [ID_SIGNATURE],
        [ID_AAL],
        [LAST_UPDATED],
        NEXT VALUE FOR [EPS].[MTM_PATIENT_SESSION_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
