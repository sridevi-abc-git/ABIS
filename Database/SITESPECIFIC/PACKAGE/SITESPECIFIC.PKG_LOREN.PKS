CREATE OR REPLACE package SITESPECIFIC.PKG_LOREN is

--* 12.17.2008 create table from user_constraints view in order to see contents of search_condition
--* column, which is of type long on that view, and normally displays as <Long>.
--* idea from http://www.orafaq.com/maillist/oracle-l/2000/07/20/2341.htm
procedure create_user_constraints_t;

procedure LoadHold;

procedure LoadApplication;

procedure LoadLegalEntity;

procedure LoadUsers;

 procedure LoadAttorney;

--  procedure LoadLicenseType;  -- David is working on this procedure in his package 1/5/09
  procedure LoadProtestant;  -- 01.08 Lhea provided new load on 12.22. need to try it out.

--* http://www.oracle.com/technology/oramag/code/tips2003/052503.html
--* idea not implemented
FUNCTION LONG_TO_CHAR( in_rowid rowid,
                       in_owner varchar,
                       in_table_name varchar,
                       in_column varchar2)
RETURN varchar;




end PKG_LOREN;

 
/
