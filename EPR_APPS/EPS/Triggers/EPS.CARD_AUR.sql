-- TRIGGER: [EPS].[CARD_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[CARD_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[CARD_AUR];
GO

CREATE TRIGGER [EPS].[CARD_AUR]
ON [EPS].[CARD]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[CARD_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [BEGINNING_COVERAGE_DATE],
        [BENEFIT],
        [CARD_NUMBER],
        [CARD_NUMBER_QUALIFIER],
        [COVERAGE_CODE],
        [ELIGIBLE],
        [ENDING_COVERAGE_DATE],
        [ID_PATIENT],
        [ID_AAL],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [BEGINNING_COVERAGE_DATE],
        [BENEFIT],
        [CARD_NUMBER],
        [CARD_NUMBER_QUALIFIER],
        [COVERAGE_CODE],
        [ELIGIBLE],
        [ENDING_COVERAGE_DATE],
        [ID_PATIENT],
        [ID_AAL],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ], SYSDATETIME()
    FROM deleted;
END;
GO
