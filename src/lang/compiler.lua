--[=[
Copyright (C) 2013-2014 Richard Hundt and contributors.
See Copyright Notice in nyanga
]=]

local parser      = require('nyanga.lang.parser')
local transformer = require('nyanga.lang.transformer')
local generator   = require('nyanga.lang.generator')
local util        = require('nyanga.lang.util')

local function compile(src, name, opts)
   local srctree = parser.parse(src, name)

   if opts and opts['-p'] then
      print("AST:", util.dump(srctree))
   end

   local dsttree = transformer.transform(srctree, src, name, opts)

   if opts and opts['-t'] then
      print("DST:", util.dump(dsttree))
   end

   local luacode = generator.generate(dsttree, '@'..name, opts)

   if opts and opts['-o'] then
      local outfile = assert(io.open(opts['-o'], "w+"))
      outfile:write(luacode)
      outfile:close()
   end

   if opts and opts['-b'] then
      local jbc = require("jit.bc")
      local fn = assert(loadstring(luacode))
      jbc.dump(fn, nil, true)
   end

   return loadstring(luacode, "@"..name)
end

return {
   compile = compile;
}

