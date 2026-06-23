-- TRIGGER: [EPS].[PAYMENT_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[PAYMENT_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PAYMENT_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[PAYMENT_TRIG_AUR]
ON [EPS].[PAYMENT]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[PAYMENT_AUDIT] (
        [CHAIN_ID],
        [ID],
        [NHIN_ID],
        [PAYMENT_ID],
        [ID_AAL],
        [PAYMENT_AMOUNT],
        [PAYMENT_TYPE],
        [AUTHORIZED_AMOUNT],
        [PRE_AUTH_DATE],
        [SETTLE_DATE],
        [CHECK_NUMBER],
        [CARD_TYPE],
        [CARD_EXPIRES],
        [RESPONSE_CODE],
        [RESPONSE_MESSAGE],
        [SETTLE_RESPONSE_CODE],
        [SETTLE_RESPONSE_MESSAGE],
        [SETTLE_REQUEST_TO_POS_DATE],
        [MAX_AMOUNT],
        [CANCEL_AUTHORIZATION_DATE],
        [LAST_FOUR_DIGITS],
        [LAST_UPDATED],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [NHIN_ID],
        [PAYMENT_ID],
        [ID_AAL],
        [PAYMENT_AMOUNT],
        [PAYMENT_TYPE],
        [AUTHORIZED_AMOUNT],
        [PRE_AUTH_DATE],
        [SETTLE_DATE],
        [CHECK_NUMBER],
        [CARD_TYPE],
        [CARD_EXPIRES],
        [RESPONSE_CODE],
        [RESPONSE_MESSAGE],
        [SETTLE_RESPONSE_CODE],
        [SETTLE_RESPONSE_MESSAGE],
        [SETTLE_REQUEST_TO_POS_DATE],
        [MAX_AMOUNT],
        [CANCEL_AUTHORIZATION_DATE],
        [LAST_FOUR_DIGITS],
        [LAST_UPDATED],
        NEXT VALUE FOR [EPS].[PAYMENT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
