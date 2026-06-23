-- TRIGGER: [EPS].[FREE_FORM_ALLERGY_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[FREE_FORM_ALLERGY_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[FREE_FORM_ALLERGY_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[FREE_FORM_ALLERGY_TRIG_AUR]
ON [EPS].[FREE_FORM_ALLERGY]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[FREE_FORM_ALLERGY_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [DESCRIPTION],
        [SEVERITY],
        [ALLERGY_CLASSIFICATION],
        [ALLERGY_COMMENT],
        [ADDED_BY],
        [NHIN_ID],
        [ID_AAL],
        [LAST_UPDATED],
        [DELETED],
        [ADD_DATE],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [DESCRIPTION],
        [SEVERITY],
        [ALLERGY_CLASSIFICATION],
        [ALLERGY_COMMENT],
        [ADDED_BY],
        [NHIN_ID],
        [ID_AAL],
        [LAST_UPDATED],
        [DELETED],
        [ADD_DATE],
        NEXT VALUE FOR [EPS].[FREE_FORM_ALLERGY_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
