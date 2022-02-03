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

#include "rez.h"

static int html_lua(lua_State *L)
{
    size_t len         = 0;
    unsigned char *str = NULL;
    luaL_Buffer b;

    if (lua_isnoneornil(L, 1)) {
        lua_pushnil(L);
        return 1;
    }
    lua_settop(L, 1);
    tostring(L, 1);

    str = (unsigned char *)lua_tolstring(L, 1, &len);
    luaL_buffinit(L, &b);
    for (size_t i = 0; i < len; i++) {
        switch (str[i]) {
        case 0:
            luaL_addstring(&b, "\uFFFD");
            break;
        case '"':
            luaL_addstring(&b, "&#34;");
            break;
        case '\'':
            luaL_addstring(&b, "&#39;");
            break;
        case '&':
            luaL_addstring(&b, "&amp;");
            break;
        case '<':
            luaL_addstring(&b, "&lt;");
            break;
        case '>':
            luaL_addstring(&b, "&gt;");
            break;

        default:
            luaL_addchar(&b, str[i]);
            break;
        }
    }
    luaL_pushresult(&b);
    return 1;
}

LUALIB_API int luaopen_rez_escape(lua_State *L)
{
    lua_createtable(L, 0, 1);
    lua_pushcfunction(L, html_lua);
    lua_setfield(L, -2, "html");

    return 1;
}
