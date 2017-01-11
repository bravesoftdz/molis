unit uModel;

interface

uses
  DB, Classes, SysUtils,Generics.Collections;

type
  TBarangSatuanItem = class;

  TAppObject = class(TObject)
  private
    FID: string;
  protected
  public
    function GetHeaderField: string; virtual;
    procedure SetHeaderProperty(AHeaderProperty : TAppObject); virtual; abstract;
    property ID: string read FID write FID;
  end;

  TGroupBarang = class(TAppObject)
  private
    FKode: string;
    FNama: string;
  public
    property Kode: string read FKode write FKode;
    property Nama: string read FNama write FNama;
  end;

  TSupplier = class(TAppObject)
  private
    FAlamat: string;
    FKode: string;
    FNama: string;
  public
    property Alamat: string read FAlamat write FAlamat;
    property Kode: string read FKode write FKode;
    property Nama: string read FNama write FNama;
  end;

  TBarang = class(TAppObject)
  private
    FBarangSatuanItems: TObjectList<TBarangSatuanItem>;
    FGroupBarang: TGroupBarang;
    FNama: string;
    FSKU: string;
    function GetBarangSatuanItems: TObjectList<TBarangSatuanItem>;
  public
    property BarangSatuanItems: TObjectList<TBarangSatuanItem> read
        GetBarangSatuanItems write FBarangSatuanItems;
    property GroupBarang: TGroupBarang read FGroupBarang write FGroupBarang;
    property Nama: string read FNama write FNama;
    property SKU: string read FSKU write FSKU;
  end;

  TPenerimaanBarangItem = class(TAppObject)
  private
    FBarang: TBarang;
    FDiskon: Double;
    FHargaBeli: Double;
    FQty: Double;
  public
    property Barang: TBarang read FBarang write FBarang;
    property Diskon: Double read FDiskon write FDiskon;
    property HargaBeli: Double read FHargaBeli write FHargaBeli;
    property Qty: Double read FQty write FQty;
  end;

  TPenerimaanBarang = class(TAppObject)
  private
    FKeterangan: string;
    FNoBukti: string;
    FPenerimaanBarangItems: TObjectList<TPenerimaanBarangItem>;
    FSupplier: TSupplier;
    FTglBukti: TDatetime;
    function GetPenerimaanBarangItems: TObjectList<TPenerimaanBarangItem>;
    procedure SetKeterangan(const Value: string);
  public
    property Keterangan: string read FKeterangan write SetKeterangan;
    property NoBukti: string read FNoBukti write FNoBukti;
    property PenerimaanBarangItems: TObjectList<TPenerimaanBarangItem> read
        GetPenerimaanBarangItems write FPenerimaanBarangItems;
    property Supplier: TSupplier read FSupplier write FSupplier;
    property TglBukti: TDatetime read FTglBukti write FTglBukti;
  end;

  TUOM = class(TAppObject)
  private
    FKode: string;
  public
    property Kode: string read FKode write FKode;
  end;

  TBarangSatuanItem = class(TAppObject)
  private
    FBarang: TBarang;
    FHargaJual: Double;
    FKonversi: Double;
    FUOM: TUOM;
  protected
  public
    function GetHeaderField: string; override;
    procedure SetHeaderProperty(AHeaderProperty : TAppObject); override;
    property Barang: TBarang read FBarang write FBarang;
    property HargaJual: Double read FHargaJual write FHargaJual;
    property Konversi: Double read FKonversi write FKonversi;
    property UOM: TUOM read FUOM write FUOM;
  end;





implementation

function TPenerimaanBarang.GetPenerimaanBarangItems:
    TObjectList<TPenerimaanBarangItem>;
begin
  if FPenerimaanBarangItems =nil then
    FPenerimaanBarangItems := TObjectList<TPenerimaanBarangItem>.Create(True);

  Result := FPenerimaanBarangItems;
end;

procedure TPenerimaanBarang.SetKeterangan(const Value: string);
begin
  FKeterangan := Value;
end;

function TBarang.GetBarangSatuanItems: TObjectList<TBarangSatuanItem>;
begin
  if FBarangSatuanItems = nil then
    FBarangSatuanItems := TObjectList<TBarangSatuanItem>.Create(False);

  Result := FBarangSatuanItems;
end;

function TBarangSatuanItem.GetHeaderField: string;
begin
  Result := 'Barang';
end;

procedure TBarangSatuanItem.SetHeaderProperty(AHeaderProperty : TAppObject);
begin
  Barang := TBarang(AHeaderProperty);
end;

function TAppObject.GetHeaderField: string;
begin
  Result := '';
end;

//initialization
//  RegisterClass(TBarangSatuanItem);


end.
