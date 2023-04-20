CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_USER_INFO
(USERID, USERNAME, EMAILADDRESS, ORACLELOGONID, OFFICEOBJECTID, 
 OFFICENAME, USER_ROLE_IND)
BEQUEATH DEFINER
AS 
SELECT ObjectId userid,
           api.pkg_ColumnQuery.VALUE (ObjectId, 'FormattedUserName') UserName,
           api.pkg_ColumnQuery.VALUE (ObjectId, 'eMailAddress') eMailAddress,
           api.pkg_ColumnQuery.VALUE (ObjectId, 'OracleLogonId') OracleLogonId,
           api.pkg_ColumnQuery.VALUE (ObjectId, 'OfficeObjectId') OfficeObjectId,
           api.pkg_ColumnQuery.VALUE (ObjectId, 'Officename') Officename,
           ur.user_role_ind
      FROM
           possedata.ReadableObjects
     INNER JOIN
           admin.users e
        ON
           e.userid = objectid
     INNER JOIN
           abcreports.rqs_user_role ur
        ON
           e.userid = ur.user_id
     WHERE
           ObjectDefId = api.pkg_ConfigQuery.ObjectDefIdForName('Users');
