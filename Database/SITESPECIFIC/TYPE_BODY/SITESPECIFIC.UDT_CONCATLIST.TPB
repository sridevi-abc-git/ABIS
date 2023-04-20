CREATE OR REPLACE TYPE BODY SITESPECIFIC."UDT_CONCATLIST" as

  /*---------------------------------------------------------------------------
   * ODCIAggregateInitialize()
   *-------------------------------------------------------------------------*/
  static function ODCIAggregateInitialize (
    sctx IN OUT udt_ConcatList
  ) return number is
  begin
    sctx := udt_ConcatList(null,null);
    return ODCIConst.Success;
  end;

  /*---------------------------------------------------------------------------
   * ODCIAggregateInitialize()
   *-------------------------------------------------------------------------*/
  member function ODCIAggregateIterate (
    self IN OUT udt_ConcatList,
    value IN udt_AggrString
  ) return number is
  begin
    if value is not null then
      if self.t_Separator is null then
        self.t_Separator := value.Separator;
      end if;
      if self.t_ReturnValue is null then
        self.t_ReturnValue := value.value;
      else
        self.t_ReturnValue := self.t_ReturnValue || substr(self.t_Separator ||
            value.value, 1, 4000 - length(self.t_ReturnValue));
      end if;
    end if;

    return ODCIConst.Success;
  end;

  /*---------------------------------------------------------------------------
   * ODCIAggregateInitialize()
   *-------------------------------------------------------------------------*/
  member function ODCIAggregateIterate (
    self IN OUT udt_ConcatList,
    value IN varchar2
  ) return number is
  begin
    return self.ODCIAggregateIterate(udt_AggrString(value, ', '));
  end;

  /*---------------------------------------------------------------------------
   * ODCIAggregateInitialize()
   *-------------------------------------------------------------------------*/
  member function ODCIAggregateTerminate (
    self IN udt_ConcatList,
    returnValue OUT varchar2,
    flags IN number
  ) return number is
  begin
    returnValue := self.t_ReturnValue;
    return ODCIConst.Success;
  end;

  /*---------------------------------------------------------------------------
   * ODCIAggregateInitialize()
   *-------------------------------------------------------------------------*/
  member function ODCIAggregateMerge(
    self IN OUT udt_ConcatList,
    ctx2 IN udt_ConcatList
  ) return number is
  begin
    self.t_ReturnValue := self.t_ReturnValue || substr(self.t_Separator ||
        ctx2.t_ReturnValue, 1, 4000 - length(self.t_ReturnValue));
    return ODCIConst.Success;
  end;
end;

/
