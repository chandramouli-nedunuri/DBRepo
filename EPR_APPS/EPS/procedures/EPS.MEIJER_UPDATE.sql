CREATE OR ALTER PROCEDURE EPS.MEIJER_UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /*
       Set-based Azure SQL rewrite of the Oracle rowid/bulk-collect/FORALL update.
       If you need batch processing, use a numeric key (for example, p.id) instead of ROWID.
    */

    UPDATE p
    SET
        p.CONTACT_PHONE = 'H',
        p.CONTACT_SMS   = 'D',
        p.CONTACT_EMAIL = 'D'
    FROM EPS.PATIENT AS p
    WHERE p.chain_id = 128
      AND p.DECEASED_DATE IS NULL
      AND p.DEACTIVATE_DATE IS NULL
      AND (p.CONTACT_PHONE NOT IN ('C', 'H', 'W') OR p.CONTACT_PHONE IS NULL)
      AND (p.CONTACT_SMS <> 'S' OR p.CONTACT_SMS IS NULL)
      AND (p.CONTACT_EMAIL NOT IN ('O', 'W', 'H') OR p.CONTACT_EMAIL IS NULL)
      AND p.NO_AUTOMATED_CALLS IS NULL
      AND EXISTS (
            SELECT 1
            FROM EPS.ADDRESS AS d
            WHERE d.chain_id = p.chain_id
              AND d.id_patient = p.id
              AND d.home_phone IS NOT NULL
      );
END;
GO