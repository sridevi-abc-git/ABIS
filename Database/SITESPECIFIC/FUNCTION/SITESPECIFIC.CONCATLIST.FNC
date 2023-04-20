CREATE OR REPLACE FUNCTION SITESPECIFIC.concatlist(/* ConcatList is an aggregate function that will concatenate a list of values
                                                     into a single comma separated value. It will ignore null values. Example:

                                                     select ConcatList(some_value)
                                                     from some_table;

                                                     This will return something like 'value1, value2, value3'.
                                                   */
                                                   input VARCHAR2)
    RETURN VARCHAR2
    -- **************************************************************************
    -- File:        CONCATLIST.FNC
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


CREATE OR REPLACE PUBLIC SYNONYM CONCATLIST FOR SITESPECIFIC.CONCATLIST;


GRANT EXECUTE ON SITESPECIFIC.CONCATLIST TO PUBLIC;
