// Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
// Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

#include "Culture.h"


void Culture::Init()
{
  static bool isInitiated = false;
  if (isInitiated)
    return;
  isInitiated = true;

  lua_State *l = luaL_newstate();

  // Code for reading in cultures

  // following is just a copy-pase from ShipTypes 20141011:

   LUA_DEBUG_START(l);

  //  luaL_requiref(l, "_G", &luaopen_base, 1);
  //  luaL_requiref(l, LUA_DBLIBNAME, &luaopen_debug, 1);
  //  luaL_requiref(l, LUA_MATHLIBNAME, &luaopen_math, 1);
  //  lua_pop(l, 3);

  //  LuaConstants::Register(l);
  //  LuaVector::Register(l);
  //  LUA_DEBUG_CHECK(l, 0);

  //  // provide shortcut vector constructor: v = vector.new
  //  lua_getglobal(l, LuaVector::LibName);
  //  lua_getfield(l, -1, "new");
  //  assert(lua_iscfunction(l, -1));
  //  lua_setglobal(l, "v");
  //  lua_pop(l, 1); // pop the vector library table

  //  LUA_DEBUG_CHECK(l, 0);

  //  // register ship definition functions
  //  lua_register(l, "define_ship", define_ship);
  //  lua_register(l, "define_static_ship", define_static_ship);  // define_static_ship is an int in the class
  //  lua_register(l, "define_missile", define_missile);

  //  LUA_DEBUG_CHECK(l, 0);

  //  // load all ship definitions
  //  namespace fs = FileSystem;
  //  for (fs::FileEnumerator files(fs::gameDataFiles, "ships", fs::FileEnumerator::Recurse);
  //        !files.Finished(); files.Next()) {
  //     const fs::FileInfo &info = files.Current();
  //     if (ends_with_ci(info.GetPath(), ".lua")) {
  //        const std::string name = info.GetName();
  //        s_currentShipFile = name.substr(0, name.size()-4);
  //        pi_lua_dofile(l, info.GetPath());
  //        s_currentShipFile.clear();
  //     }
  //  }

   LUA_DEBUG_END(l, 0);

   lua_close(l);

   // // hittar på att jag har någon slags "cultures" objekt/vektor?
   // if (Culture::cultures.empty())
   //    Error("No cultures found!");
}
