CREATE OR REPLACE FORCE VIEW ABCREPORTS.V_USER_SEARCH
(USERID, USER_NAME, EMAILADDRESS, ORACLELOGONID, OFFICEOBJECTID, 
 OFFICENAME, DIVISION, ISDISTRICT, USER_ROLE_IND)
BEQUEATH DEFINER
AS 
SELECT "user".objectid userid,
          api.pkg_columnquery.VALUE ("user".objectid, 'FormattedUserName') User_Name,
          api.pkg_columnquery.VALUE("user".objectid, 'eMailAddress') emailaddress,
          api.pkg_columnquery.VALUE ("user".objectid, 'OracleLogonId') oraclelogonid,
          api.pkg_columnquery.VALUE ("user".objectid, 'OfficeObjectId') officeobjectid,
          api.pkg_columnquery.VALUE ("user".objectid, 'Officename') Officename,
          (SELECT UPPER(NVL (v.VALUE, d.attributevalue))
             FROM possedata.ObjectColumnData d
             LEFT OUTER JOIN objmodelphys.alldomainlistofvalues v
                  ON v.listvalueid = d.attributevalueid
            WHERE d.objectid = office.objectid
              AND d.columndefid = 318834
           ) Division,
          api.pkg_columnquery.VALUE (office.objectid, 'IsActiveAndDistrict') IsDistrict,
          ur.user_role_ind
     FROM possedata.ReadableObjects "user"
     JOIN admin.users adm ON (adm.userid = "user".objectid AND adm.active = 'Y')
     LEFT OUTER JOIN rqs_user_role ur ON "user".objectid = ur.user_id
     JOIN possedata.ReadableObjects office
          ON (office.objectdefid = 294278
             AND api.pkg_columnquery.numericvalue ("user".objectid, 'OfficeObjectId') = office.objectid
             )
    WHERE "user".objectdefid = api.pkg_configquery.objectdefidforname ('Users');
