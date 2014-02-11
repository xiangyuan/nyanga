local pckg = assert(package.searchpath("nyanga", package.cpath))
local lpeg = assert(package.loadlib(pckg, "luaopen_lpeg"))()
package.loaded["lpeg"]	      = lpeg
package.loaded["nyanga.lpeg"] = lpeg
return lpeg

