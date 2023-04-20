CREATE OR REPLACE package SITESPECIFIC.pkg_David as

  -- Public type declarations
  subtype udt_Id is api.pkg_Definition.udt_Id;

  ----------------------------------------------------------------------------------------------------
  -- * CopyPriorityLicDetailsToApp() -- PUBLIC
  -- Copy details and relationsihps from license to an transfer application.
  -- Depending on application type, this can include:
  -- Licensees, License Types, Hold, Mail Address, DBA, Base File Office
  -- Input is the application objId
  -- Runs on Post Verify of Application Job.
  ----------------------------------------------------------------------------------------------------
  procedure CopyPriorityLicDetailsToApp(a_AppObjectId udt_Id, a_AsOfDate date);

end pkg_David;

 
/
