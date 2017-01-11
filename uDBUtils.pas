unit uDBUtils;

interface
uses
  IB, Rtti, uModel, typinfo, SysUtils, StrUtils, uADStanIntf, uADStanOption, uADStanError,
  uADGUIxIntf, uADPhysIntf, uADStanDef, uADStanPool, uADStanAsync,
  uADPhysManager, uADCompClient, DB, uADPhysPG, uADPhysIB,Forms, DBClient,
  Provider, uAppUtils, cxGridDBTableView, Generics.Collections, Classes;

type
  TDBUtils = class(TObject)
  private
    class function GenerateSQLInsert(AObject : TAppObject): string;
    class function GenerateSQLUpdate(AObject : TAppObject): string;
  protected
  public
    class function ConnectDB(ADBEngine, AServer, ADatabase, AUser , APassword,
        APort : String): Boolean;
    class procedure DataSetToCxDBGrid(ADataset : TDataset; ACxDBGrid :
        TcxGridDBTableView; AutoCreateFields : Boolean = False);
    class function OpenDataset(ASQL : String): TClientDataSet; overload;
    class function GenerateSQL(AObject : TAppObject): string;
    class function GenerateSQLDelete(AObject : TAppObject; AID : String): string;
    class function GetNextID(AOBject : TAppObject): Integer;
    class function GetNextIDGUID: TGuid;
    class function GetNextIDGUIDToString: string;
    class procedure LoadFromDB(AOBject : TAppObject; AID : String);
    class function OpenMemTable(ASQL : String): TADMemTable;
    class function OpenQuery(ASQL : String): TADQuery;
  end;

var
  ADConnection: TADConnection;
  ADTransaction: TADTransaction;
  ADPhysIBDriverLink1: TADPhysIBDriverLink;

implementation

class function TDBUtils.ConnectDB(ADBEngine, AServer, ADatabase, AUser ,
    APassword, APort : String): Boolean;
begin
  Result := False;

  ADConnection := TADConnection.Create(Application);
  ADTransaction:= TADTransaction.Create(Application);

  ADConnection.Transaction := ADTransaction;

  ADConnection.DriverName := ADBEngine;
  ADConnection.LoginPrompt:= False;

  ADConnection.Params.Add('Server=' + AServer);
  ADConnection.Params.Add('Database=' + ADatabase);
  ADConnection.Params.Add('User_Name=' + AUser);
  ADConnection.Params.Add('Password=' + APassword);
  ADConnection.Params.Add('Port=' + APort);

  ADConnection.Connected := True;
  if ADConnection.Connected then
  begin
    TAppUtils.TulisRegistry('Engine', ADBEngine);
    TAppUtils.TulisRegistry('server', AServer);
    TAppUtils.TulisRegistry('Database', ADatabase);
    TAppUtils.TulisRegistry('User_Name', AUser);
    TAppUtils.TulisRegistry('Password', APassword);
    TAppUtils.TulisRegistry('Port', APort);

    Result := True;
  end;

end;

class procedure TDBUtils.DataSetToCxDBGrid(ADataset : TDataset; ACxDBGrid :
    TcxGridDBTableView; AutoCreateFields : Boolean = False);
var
//  i: Integer;
  lCDS: TClientDataSet;
  lDSP: TDataSetProvider;
begin
  lDSP := TDataSetProvider.Create(Application);
  lCDS := TClientDataSet.Create(Application);



  lDSP.DataSet := ADataset;
  lCDS.SetProvider(lDSP);
  lCDS.Open;

//  while not lCDS.Eof do
//  begin
//    showmessage(lCDS.Fields[4].AsString);
//    lCDS.Next;
//  end;


  if ACxDBGrid.DataController.DataSource = nil then
    ACxDBGrid.DataController.DataSource := TDataSource.Create(Application);

  ACxDBGrid.DataController.DataSource.DataSet := lCDS;

  if AutoCreateFields then
    ACxDBGrid.DataController.CreateAllItems(True);
end;

class function TDBUtils.OpenDataset(ASQL : String): TClientDataSet;
var
  LDSP: TDataSetProvider;
  LSQLQuery: TADQuery;
begin
  Result      := TClientDataSet.Create(Application);
  LDSP        := TDataSetProvider.Create(Result);
  LSQLQuery   := TADQuery.Create(LDSP);
  LSQLQuery.FetchOptions.Unidirectional := False;

  LSQLQuery.Connection := ADConnection;
  LSQLQuery.SQL.Append(ASQL);

  LDSP.DataSet            := LSQLQuery;
  Result.SetProvider(LDSP);
  Result.Open;

end;

class function TDBUtils.GenerateSQLInsert(AObject : TAppObject): string;
var
  ctx : TRttiContext;
  i: Integer;
  lValue: TValue;
  rt : TRttiType;
  prop : TRttiProperty;
  ResultObjectList: string;
  meth : TRttiMethod;
begin
  Result := '';
  ResultObjectList := '';

  ctx := TRttiContext.Create();
  try
      rt := ctx.GetType(AObject.ClassType);


      AObject.ID := TDBUtils.GetNextIDGUIDToString();

      Result := 'insert into ' + AObject.ClassName + '(';
      for prop in rt.GetProperties() do begin
          meth := prop.PropertyType.GetMethod('ToArray');
          if Assigned(meth) then
            Continue;

          if not prop.IsWritable then continue;

          if Result = 'insert into ' + AObject.ClassName + '(' then
            Result := Result + prop.Name
          else
            Result := Result + ',' + prop.Name;
      end;

      Result := Result + ') values(';


      for prop in rt.GetProperties() do begin
        if not prop.IsWritable then continue;

        case prop.PropertyType.TypeKind of
          tkClass   : begin
                        meth := prop.PropertyType.GetMethod('ToArray');
                        if Assigned(meth) then
                        begin
                          with meth.Invoke(prop.GetValue(AObject),[]) do
                          begin
                            for i := 0 to GetArrayLength - 1 do
                            begin
                              if i = 0 then
                              begin
                                ResultObjectList := 'delete from ' + GetArrayElement(i).AsObject.ClassName
                                                    + ' where ' + TAppObject(GetArrayElement(i).AsObject).GetHeaderField + ' = ' + QuotedStr(AObject.ID) + ';';

                              end;

                              ResultObjectList := ResultObjectList + GenerateSQLInsert(TAppObject(GetArrayElement(i).AsObject));
                            end;
                          end;
                        end else begin
                          Result := Result + QuotedStr(TAppObject(prop.GetValue(AObject).AsObject).ID) + ',';
                        end;


                      end;
          tkInteger : Result := Result + FloatToStr(prop.GetValue(AObject).AsExtended) + ',';
          
          tkFloat   : if CompareText('TDateTime',prop.PropertyType.Name)=0 then
                        Result := Result + QuotedStr(FormatDateTime('MM/dd/yyyy hh:mm:ss',prop.GetValue(AObject).AsExtended)) + ','
                      else
                        Result := Result + FloatToStr(prop.GetValue(AObject).AsExtended) + ',' ;
                        
          tkUString : Result := Result + QuotedStr(prop.GetValue(AObject).AsString) + ',';
        end;
      end;

      Result := LeftStr(Result, Length(Result)-1) + ');';
      if ResultObjectList <> '' then
      begin
        Result := Result + ResultObjectList;
      end;
  finally
      ctx.Free();
  end;
end;

class function TDBUtils.GenerateSQLUpdate(AObject : TAppObject): string;
var
  ctx : TRttiContext;
  i: Integer;
  rt : TRttiType;
  prop : TRttiProperty;
  meth : TRttiMethod;
  ResultObjectList: string;
begin

  Result := '';
  ctx := TRttiContext.Create();
  try
      rt := ctx.GetType(AObject.ClassType);
      Result := 'update ' + AObject.ClassName + ' set ';

      for prop in rt.GetProperties() do begin
        meth := prop.PropertyType.GetMethod('ToArray');
        if (not prop.IsWritable) or
           (UpperCase(prop.Name) = 'ID')  then continue;

        if not Assigned(meth) then
          Result := Result + prop.Name + ' = ';

        case prop.PropertyType.TypeKind of
//          tkArray     :
          tkClass     : begin
                          meth := prop.PropertyType.GetMethod('ToArray');
                          if Assigned(meth) then
                          begin
                            with meth.Invoke(prop.GetValue(AObject),[]) do
                            begin
                              for i := 0 to GetArrayLength - 1 do
                              begin
                                if i = 0 then
                                begin
                                  ResultObjectList := 'delete from ' + GetArrayElement(i).AsObject.ClassName
                                                      + ' where ' + TAppObject(GetArrayElement(i).AsObject).GetHeaderField + ' = ' + QuotedStr(AObject.ID) + ';';

                                end;

                                ResultObjectList := ResultObjectList + GenerateSQLInsert(TAppObject(GetArrayElement(i).AsObject));
                              end;
                            end;
                          end else begin
                            Result := Result + QuotedStr(TAppObject(prop.GetValue(AObject).AsObject).ID) + ',';
                          end;
                        end;
          tkInteger   : Result := Result + FloatToStr(prop.GetValue(AObject).AsExtended) + ',';
          
          tkFloat     : if CompareText('TDateTime',prop.PropertyType.Name)=0 then
                          Result := Result + QuotedStr(FormatDateTime('MM/dd/yyyy hh:mm:ss',prop.GetValue(AObject).AsExtended)) + ','
                        else
                          Result := Result + FloatToStr(prop.GetValue(AObject).AsExtended) + ',';
                          
          tkUString   : Result := Result + QuotedStr(prop.GetValue(AObject).AsString) + ',';
        end;
      end;

      Result := LeftStr(Result, Length(Result)-1) + ' where id = ' + QuotedStr(AObject.ID) + ';';
      if ResultObjectList <> '' then
      begin
        Result := Result + ResultObjectList;
      end;
  finally
      ctx.Free();
  end;   
end;

class function TDBUtils.GenerateSQL(AObject : TAppObject): string;
begin
  if AObject.ID = '' then
    Result := TDBUtils.GenerateSQLInsert(AObject)
  else
    Result := TDBUtils.GenerateSQLUpdate(AObject);

end;

class function TDBUtils.GenerateSQLDelete(AObject : TAppObject; AID : String):
    string;
var
  ctx : TRttiContext;
  i: Integer;
  lValue: TValue;
  rt : TRttiType;
  prop : TRttiProperty;
  ResultObjectList: string;
  meth : TRttiMethod;
begin
  Result := '';
  ResultObjectList := '';

  TDBUtils.LoadFromDB(AObject, AID);

  ctx := TRttiContext.Create();
  try
      rt := ctx.GetType(AObject.ClassType);

      Result := 'delete from ' + AObject.ClassName
            + ' where id =' + QuotedStr(AID) + ';';

      for prop in rt.GetProperties() do begin
        if (not prop.IsWritable) or
           (prop.PropertyType.TypeKind <> tkClass) then continue;

        meth := prop.PropertyType.GetMethod('ToArray');
        if Assigned(meth) then
        begin
          with meth.Invoke(prop.GetValue(AObject),[]) do
          begin
            for i := 0 to GetArrayLength - 1 do
            begin
//              if i = 0 then
//              begin
//                ResultObjectList := 'delete from ' + GetArrayElement(i).AsObject.ClassName
//                                    + ' where ' + TAppObject(GetArrayElement(i).AsObject).GetHeaderField + ' = ' + QuotedStr(AID) + ';';
//              end;

              ResultObjectList := ResultObjectList + GenerateSQLDelete(TAppObject(GetArrayElement(i).AsObject),TAppObject(GetArrayElement(i).AsObject).ID );
            end;
          end;
        end;
      end;

      if ResultObjectList <> '' then
      begin
        Result := Result + ResultObjectList;
      end;
  finally
      ctx.Free();
  end;
end;

class function TDBUtils.GetNextID(AOBject : TAppObject): Integer;
var
  Q: TADQuery;
  sSQL: string;
begin
  Result := 0;

  sSQL := 'select max(id) as ID from ' + AOBject.ClassName;

  Q := TDBUtils.OpenQuery(sSQL);
  try
    while not Q.Eof do
    begin
      Result := Q.FieldByName('ID').AsInteger;
      Q.Next;
    end;
  finally
    Q.Free;
  end;

  Result := Result + 1;
end;

class function TDBUtils.GetNextIDGUID: TGuid;
begin
  CreateGUID(Result);
end;

class function TDBUtils.GetNextIDGUIDToString: string;
var
  lGUID: TGuid;
begin
  CreateGUID(lGUID);
  Result := GUIDToString(lGUID);
end;

class procedure TDBUtils.LoadFromDB(AOBject : TAppObject; AID : String);
var
  Q: TADQuery;
  sSQL: string;

  ctx : TRttiContext;
  lAppObject: TAppObject;
  lAppObjectList: TObjectList<TAppObject>;
  lObjectList: TObject;
  rt : TRttiType;
  prop : TRttiProperty;
  meth : TRttiMethod;
  QQ: TClientDataSet;
  sGenericItemClassName: string;
  sX: string;
begin
  sSQL := 'select * from ' + AOBject.ClassName
          + ' where id = ' + QuotedStr(AID);

  ctx := TRttiContext.Create();
  Q := TDBUtils.OpenQuery(sSQL);
  try
    rt := ctx.GetType(AObject.ClassType);

    if not Q.IsEmpty then
    begin
      for prop in rt.GetProperties() do begin
        if (not prop.IsWritable) or
            (UpperCase(prop.Name)=UpperCase(AOBject.GetHeaderField)) then continue;


        case prop.PropertyType.TypeKind of
          tkInteger : prop.SetValue(AObject,Q.FieldByName(prop.Name).AsInteger );
          tkFloat   : prop.SetValue(AObject,Q.FieldByName(prop.Name).AsFloat );
          tkUString : prop.SetValue(AObject,Q.FieldByName(prop.Name).AsString );
          tkClass   : begin
                        meth := prop.PropertyType.GetMethod('ToArray');
                        if Assigned(meth) then
                        begin
                          lObjectList := prop.GetValue(AOBject).AsObject;
                          sGenericItemClassName :=  StringReplace(lObjectList.ClassName, 'TOBJECTLIST<','', [rfIgnoreCase]);
                          sGenericItemClassName :=  StringReplace(sGenericItemClassName, '>','', [rfIgnoreCase]);
//                          sGenericItemClassName :=  StringReplace(sGenericItemClassName, 'UMODEL.','', [rfIgnoreCase]);

                          lAppObject := TAppObject((ctx.FindType(sGenericItemClassName) as TRttiInstanceType).MetaClassType.Create);
                          meth := prop.PropertyType.GetMethod('Add');

                          if Assigned(meth) then
                          begin
                            sSQL := 'select id from ' + lAppObject.ClassName
                                    + ' where ' + lAppObject.GetHeaderField + ' = ' + QuotedStr(AID);

                            QQ := TDBUtils.OpenDataset(sSQL);
                            try
                              while not QQ.Eof do
                              begin
                                lAppObject.ID := QQ.FieldByName('ID').AsString;
                                lAppObject.SetHeaderProperty(AOBject);
                                LoadFromDB(lAppObject, lAppObject.ID);
                                meth.Invoke(lObjectList,[lAppObject]);

                                QQ.Next;
                                if not QQ.Eof then
                                  lAppObject := TAppObject((ctx.FindType(sGenericItemClassName) as TRttiInstanceType).MetaClassType.Create);



                              end;
                            finally
                              QQ.Free;
                            end;


                          end;
                        end else begin
                          meth          := prop.PropertyType.GetMethod('Create');
                          lAppObject    := TAppObject(meth.Invoke(prop.PropertyType.AsInstance.MetaclassType, []).AsObject);
                          lAppObject.ID := Q.FieldByName(prop.Name).AsString;

                          prop.SetValue(AOBject, lAppObject);
                        end;
                      end;
        end;
      end;
    end;
  finally
    Q.Free;
  end;
end;

class function TDBUtils.OpenMemTable(ASQL : String): TADMemTable;
var
  Q: TADQuery;
begin
  Result := TADMemTable.Create(nil);

  Q := TDBUtils.OpenQuery(ASQL);
  try
    Q.FetchAll;
    Result.Data := Q.Data;
    Result.First;
  finally
    Q.Free;
  end;
end;

class function TDBUtils.OpenQuery(ASQL : String): TADQuery;

begin
  Result := TADQuery.Create(nil);
  Result.Connection := ADConnection;
  Result.Open(ASQL);
end;



end.
