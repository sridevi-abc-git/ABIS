CREATE OR REPLACE FUNCTION BIZMOD_API.STATUSMATRIX(a_status IN VARCHAR2)
RETURN VARCHAR2
IS
-- ****************************************************************************
-- File: STATUSMATRIX.SQL
-- Author: Timothy J. Lord
--
-- Purpose : This function is called to convert a status description to
-- a status code. If status description is not found then the
-- status discription is retuned as the status code.
--
-- History:
-------------------------------------------------------------------------------
-- Date Ticket Comment
-- 04/13/2022 TJL BIZ-5919 Initial Function Created
-- 04/22/2022 TJL Converted status description to upper case before
-- transalating to status code. Description can be
-- stored in mix case or upper case.
-- ****************************************************************************
BEGIN
RETURN CASE UPPER(a_status)
WHEN 'ACTIVE' THEN 'ACTIVE'
WHEN 'AUTO REVOKED' THEN 'AUTREV'
WHEN 'CANCELED' THEN 'CANCEL'
WHEN 'DENIED' THEN 'DENIED'
WHEN 'DEPARTMENT REVOKED' THEN 'DEPREV'
WHEN 'NON-RENEWED' THEN 'NREN'
WHEN 'PENDING' THEN 'PEND'
WHEN 'REV PENDING' THEN 'REVPEN'
WHEN 'RULE 64B' THEN 'R64B'
WHEN 'SLMS REVOKED' THEN 'SLMSRV'
WHEN 'SURRENDERED' THEN 'SUREND'
WHEN 'SUSPENDED' THEN 'SUSPEN'
WHEN 'VOIDED' THEN 'VOIDED'
WHEN 'WITHDRAWN' THEN 'WTHDRN'
ELSE UPPER(a_status)
END;
END;
/
