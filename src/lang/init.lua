if not package.loaded['lpeg'] then
   -- try to pull it out of "nyanga.so"
   local pckg = assert(package.searchpath("nyanga", package.cpath))
   local lpeg = assert(package.loadlib(pckg, "luaopen_lpeg"))()
   package.loaded["lpeg"] = lpeg
end

