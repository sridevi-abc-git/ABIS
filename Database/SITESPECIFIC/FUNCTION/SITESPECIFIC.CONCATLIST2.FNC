CREATE OR REPLACE FUNCTION SITESPECIFIC.concatlist2(/* ConcatList2 is a more flexible version of ConcatList.  It allows the
                                                      separator to be specified through the udt_AggrString type.  Example:

                                                      select ConcatList2(udt_AggrString(some_value, ';'))
                                                      from some_table;

                                                      This approach had to be taken because Oracle does not allow multi-argument
                                                      aggregate functions.  While it would have been ideal to be able to call:
                                                      "ConcatList(some_value, ';')", this isn't possible.  Instead, the aggregate
                                                      function takes udt_AggrString as the argument. */
                                                    input udt_aggrstring)
    RETURN VARCHAR2
    -- **************************************************************************
    -- File:        CONCATLIST2.FNC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************
    PARALLEL_ENABLE
    AGGREGATE USING udt_concatlist;
/


CREATE OR REPLACE PUBLIC SYNONYM CONCATLIST2 FOR SITESPECIFIC.CONCATLIST2;


GRANT EXECUTE ON SITESPECIFIC.CONCATLIST2 TO PUBLIC;
