unit LuaDissectCode;

{$mode delphi}

interface

uses
  Classes, SysUtils, lua, lauxlib, lualib;

procedure initializeLuaDissectCode;

implementation

uses DissectCodeThread, luahandler, LuaClass, LuaObject, symbolhandler;

function getDissectCode(L: PLua_State): integer; cdecl;
begin
  if dissectcode=nil then
    dissectcode:=TDissectCodeThread.create(false);

  luaclass_newClass(L, dissectcode);
  result:=1;
end;

function dissectcode_dissect(L: PLua_State): integer; cdecl;
var dc: TDissectCodeThread;
  start: ptruint;
  size: integer;
  mi: TModuleInfo;
  modulename: string;
begin
  //2 versions, modulename and base,size
  //base can be a string too, so check paramcount

  result:=0;
  dc:=luaclass_getClassObject(L);
  dc.waitTillDone; //just in case...

  if lua_gettop(L)=1 then
  begin
    //modulename
    modulename:=Lua_ToString(L,1);
    if symhandler.getmodulebyname(modulename, mi) then
    begin
      start:=mi.baseaddress;
      size:=mi.basesize;
    end
    else
      raise exception.create('The module named '+modulename+' could not be found')

  end
  else
  if lua_gettop(L)=2 then
  begin
    if lua_type(L,1)=LUA_TSTRING then
      start:=symhandler.getAddressFromName(Lua_ToString(L,1))
    else
      start:=lua_tointeger(L,1);

    size:=lua_tointeger(L, 2);

  end
  else
    raise exception.create('Invalid parameters for dissect');


  //all date is here, setup a scan config
  setlength(dissectcode.memoryregion,1);
  dissectcode.memoryregion[0].BaseAddress:=start;
  dissectcode.memoryregion[0].MemorySize:=size;



  dc.dowork;
  dc.waitTillDone;
  result:=0;
end;


function dissectcode_clear(L: PLua_State): integer; cdecl;
var dc: TDissectCodeThread;
begin
  dc:=luaclass_getClassObject(L);
  dc.clear;
  result:=0;
end;

function dissectcode_addReference(L: PLua_State): integer; cdecl;
var dc: TDissectCodeThread;
    fromaddress, toaddress: ptruint;
    reftype: tjumptype;
    isstring: boolean;
begin
  dc:=luaclass_getClassObject(L);
  if lua_type(L,1)=LUA_TSTRING then
    fromaddress:=symhandler.getAddressFromName(Lua_ToString(L,1))
  else
    fromaddress:=lua_tointeger(L,1);

  if lua_type(L,2)=LUA_TSTRING then
    toaddress:=symhandler.getAddressFromName(Lua_ToString(L,2))
  else
    toaddress:=lua_tointeger(L,2);

  reftype:=tjumptype(lua_tointeger(L,3));

  if lua_gettop(L)=4 then
    isstring:=lua_toboolean(L, 4)
  else
    isstring:=false;


  dc.addReference(fromaddress, toaddress,reftype, isstring);
  result:=0;
end;

function dissectcode_deleteReference(L: PLua_State): integer; cdecl;
var dc: TDissectCodeThread;
    fromaddress, toaddress: ptruint;
begin
  dc:=luaclass_getClassObject(L);
  if lua_type(L,1)=LUA_TSTRING then
    fromaddress:=symhandler.getAddressFromName(Lua_ToString(L,1))
  else
    fromaddress:=lua_tointeger(L,1);

  if lua_type(L,2)=LUA_TSTRING then
    toaddress:=symhandler.getAddressFromName(Lua_ToString(L,2))
  else
    toaddress:=lua_tointeger(L,2);



  dc.removeReference(fromaddress, toaddress);
  result:=0;
end;

function dissectcode_getReferences(L: PLua_State): integer; cdecl;
var dc: TDissectCodeThread;
    address: ptruint;

    da: tdissectarray;
    i,t: integer;
begin
  dc:=luaclass_getClassObject(L);
  if lua_type(L,1)=LUA_TSTRING then
    address:=symhandler.getAddressFromName(Lua_ToString(L,1))
  else
    address:=lua_tointeger(L,1);


  setlength(da,0);

  if dc.CheckAddress(address, da) then
  begin
    lua_newtable(L);
    t:=lua_gettop(L);

    for i:=0 to length(da)-1 do
    begin
      lua_pushinteger(L, da[i].address);
      lua_pushinteger(L, integer(da[i].jumptype));
      lua_settable(L, t);
    end;

    result:=1;
  end
  else
    result:=0;

end;

function dissectcode_getReferencedStrings(L: PLua_State): integer; cdecl;
var dc: TDissectCodeThread;
    s: tstringlist;

    i,t: integer;

    sr: TStringReference;
begin
  result:=0;
  dc:=luaclass_getClassObject(L);

  s:=TStringList.create;
  dc.getstringlist(s);

  if s.count>0 then
  begin

    lua_newtable(L);
    t:=lua_gettop(L);

    for i:=0 to s.count-1 do
    begin
      sr:=s.Objects[i];
      lua_pushinteger(L, sr.address);
      lua_pushstring(L, sr.s);
      lua_settable(L, t);
      sr.free;
    end;

    result:=1;

  end;

  s.free;

end;



procedure dissectcode_addMetaData(L: PLua_state; metatable: integer; userdata: integer );
begin
  object_addMetaData(L, metatable, userdata);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'dissect', dissectcode_dissect);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'clear', dissectcode_clear);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'addReference', dissectcode_addReference);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'deleteReference', dissectcode_deleteReference);

  luaclass_addClassFunctionToTable(L, metatable, userdata, 'getReferences', dissectcode_getReferences);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'getReferencedStrings', dissectcode_getReferencedStrings);

end;

procedure initializeLuaDissectCode;
begin
  lua_register(LuaVM, 'getDissectCode', getDissectCode);
end;

initialization
  luaclass_register(TDissectCodeThread, dissectcode_addMetaData);

end.
