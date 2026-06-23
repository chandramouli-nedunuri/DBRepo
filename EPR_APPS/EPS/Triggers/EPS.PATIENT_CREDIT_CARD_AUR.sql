-- TRIGGER: [EPS].[PATIENT_CREDIT_CARD_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[PATIENT_CREDIT_CARD_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PATIENT_CREDIT_CARD_AUR];
GO

CREATE TRIGGER [EPS].[PATIENT_CREDIT_CARD_AUR]
ON [EPS].[PATIENT_CREDIT_CARD]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[PATIENT_CREDIT_CARD_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [SEQUENCE],
        [CARD_TYPE],
        [CARD_EXPIRE_DATE],
        [CARD_NAME],
        [CARD_ADDRESS],
        [CARD_POSTAL_CODE],
        [DISCONTINUE_DATE],
        [DEACTIVATE_DATE],
        [AUTOPAY_MONTHLY_DOLLAR_LIMIT],
        [LAST_FOUR_DIGITS],
        [TOKEN_NUMBER],
        [ID_AAL],
        [LAST_UPDATED],
        [PAYMENT_PROCESSOR_TYPE],
        [CARD_CITY],
        [CARD_STATE],
        [CARD_NICK_NAME],
        [FIRST_SIX_DIGITS],
        [CC_TOKEN_PROVIDER],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [SEQUENCE],
        [CARD_TYPE],
        [CARD_EXPIRE_DATE],
        [CARD_NAME],
        [CARD_ADDRESS],
        [CARD_POSTAL_CODE],
        [DISCONTINUE_DATE],
        [DEACTIVATE_DATE],
        [AUTOPAY_MONTHLY_DOLLAR_LIMIT],
        [LAST_FOUR_DIGITS],
        [TOKEN_NUMBER],
        [ID_AAL],
        [LAST_UPDATED],
        [PAYMENT_PROCESSOR_TYPE],
        [CARD_CITY],
        [CARD_STATE],
        [CARD_NICK_NAME],
        [FIRST_SIX_DIGITS],
        [CC_TOKEN_PROVIDER],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
