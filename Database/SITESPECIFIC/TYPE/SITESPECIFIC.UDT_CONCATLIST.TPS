CREATE OR REPLACE TYPE SITESPECIFIC."UDT_CONCATLIST"                                          as object
(
  /*----------------------------------------------------------------------------
   * DESCRIPTION
   *   This type is used for the ConcatList and ConcatList2 aggregate functions.
   * Note that is contains two ODCIAggregateIterate functions, each taking a
   * different argument data type.  The one with the varchar2 argument is for
   * ConcatList and the one with the udt_AggrString argument is for ConcatList2.
   *--------------------------------------------------------------------------*/
  t_ReturnValue varchar2(4000),
  t_Separator varchar2(4000),

  /*---------------------------------------------------------------------------
   * ODCIAggregateInitialize()
   *-------------------------------------------------------------------------*/
  static function ODCIAggregateInitialize (
    sctx IN OUT udt_ConcatList
  ) return number,

  /*---------------------------------------------------------------------------
   * ODCIAggregateIterate()
   *   This is used for ConcatList2 which takes udt_AggrString as its argument.
   * ConcatList2 allows the separator to be specified as the second parameter
   * to the udt_AggrString object.
   *-------------------------------------------------------------------------*/
  member function ODCIAggregateIterate(
    self IN OUT udt_ConcatList,
    value IN udt_AggrString
  ) return number,

  /*---------------------------------------------------------------------------
   * ODCIAggregateIterate()
   *   This is used for ConcatList.  ConcatList uses ', ' as its separator.
   *-------------------------------------------------------------------------*/
  member function ODCIAggregateIterate(
    self IN OUT udt_ConcatList,
    value IN varchar2
  ) return number,

  /*---------------------------------------------------------------------------
   * ODCIAggregateTerminate()
   *-------------------------------------------------------------------------*/
  member function ODCIAggregateTerminate(
    self IN udt_ConcatList,
    returnValue OUT varchar2,
    flags IN number
  ) return number,

  /*---------------------------------------------------------------------------
   * ODCIAggregateMerge()
   *-------------------------------------------------------------------------*/
  member function ODCIAggregateMerge(
    self IN OUT udt_ConcatList,
    ctx2 IN udt_ConcatList
  ) return number
);

/
