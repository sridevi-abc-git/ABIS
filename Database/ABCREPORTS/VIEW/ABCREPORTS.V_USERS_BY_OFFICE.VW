CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_USERS_BY_OFFICE
(USERID, USERNAME, ORACLELOGONID, OFFICE_ID)
BEQUEATH DEFINER
AS 
SELECT b.ObjectId userid,
           api.pkg_ColumnQuery.VALUE (b.ObjectId, 'FormattedUserName') UserName,
           api.pkg_ColumnQuery.VALUE (b.ObjectId, 'OracleLogonId') oraclelogonid,
           api.pkg_ColumnQuery.NumericValue (b.ObjectId, 'OfficeObjectId') office_id
     FROM possedata.ReadableObjects b
          JOIN admin.users e ON e.UserId = b.ObjectId
    WHERE b.ObjectDefId = 4
      AND E.ACTIVE = 'Y'
    ORDER BY e.name;
