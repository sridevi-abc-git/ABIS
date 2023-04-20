CREATE OR REPLACE package body SITESPECIFIC.PKG_RYANL is

/*------------------------
--
*/------------------------
 procedure PVTest(a_ObjectId number,
                  a_AsOfDate date) is

 begin

   insert into t_PVTest(Id,
                        Externalfilenum,
                        AsOfDate,
                        SID)
          values (a_ObjectId,
                  api.pkg_ColumnQuery.Value(a_ObjectId, 'ExternalFileNum'),
                  sysdate,
                  sys_context('USERENV','SID'));

 end PVTest;
end PKG_RYANL;

/
