/**
 *  Copyright (C) 2022 Masatoshi Fukunaga
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to
 *  deal in the Software without restriction, including without limitation the
 *  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 *  sell copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 *  IN THE SOFTWARE.
 */

#include <lauxlib.h>
#include <lua.h>

#if LUA_VERSION_NUM >= 502
# define rawlen(L, idx) lua_rawlen(L, idx)
#else
# define rawlen(L, idx) lua_objlen(L, idx)
#endif

static inline void tostring(lua_State *L, int idx)
{
    int type = 0;

    if (luaL_callmeta(L, idx, "__tostring")) {
        lua_replace(L, idx);
    }

    type = lua_type(L, idx);
    switch (type) {
    case LUA_TSTRING:
        break;

    case LUA_TNIL:
        lua_pushliteral(L, "nil");
        lua_replace(L, idx);
        break;

    case LUA_TNUMBER:
        lua_tostring(L, idx);
        break;

    case LUA_TBOOLEAN:
        if (lua_toboolean(L, idx)) {
            lua_pushliteral(L, "true");
        } else {
            lua_pushliteral(L, "false");
        }
        lua_replace(L, idx);
        break;

    // case LUA_TTABLE:
    // case LUA_TFUNCTION:
    // case LUA_TTHREAD:
    // case LUA_TUSERDATA:
    // case LUA_TLIGHTUSERDATA:
    default:
        lua_pushfstring(L, "%s: %p", lua_typename(L, type),
                        lua_topointer(L, idx));
        lua_replace(L, idx);
        break;
    }
}

static int concat_lua(lua_State *L)
{
    luaL_Buffer b;
    size_t last = 0;

    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 1);
    last = (size_t)rawlen(L, 1);
    luaL_buffinit(L, &b);

    for (size_t i = 1; i <= last; i++) {
        lua_rawgeti(L, 1, i);
        tostring(L, 3);
        luaL_addvalue(&b);
    }
    luaL_pushresult(&b);
    return 1;
}

LUALIB_API int luaopen_rez_concat(lua_State *L)
{
    lua_pushcfunction(L, concat_lua);
    return 1;
}
