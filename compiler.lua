--[=[
Copyright (C) 2013-2014 Richard Hundt and contributors.
See Copyright Notice in nyanga
]=]

local parser      = require('parser')
local transformer = require('transformer')
local generator   = require('generator')
local util        = require('util')

local function compile(src, name, opts)
   local srctree = parser.parse(src, name)

   if opts and opts['-p'] then
      print("AST:", util.dump(srctree))
   end

   local dsttree = transformer.transform(srctree, src)

   if opts and opts['-t'] then
      print("DST:", util.dump(dsttree))
   end

   local luacode
   if opts and opts['-s'] then
      luacode = generator.source(dsttree, name)
      print(luacode)
   else
      luacode = generator.bytecode(dsttree, name)
   end

   if opts and opts['-o'] then
      local outfile = io.open(opts['-o'], "w+")
      outfile:write(luacode)
      outfile:close()
   end

   if opts and opts['-b'] then
      local jbc = require("jit.bc")
      local fn = assert(loadstring(luacode))
      jbc.dump(fn, nil, true)
   end

   return luacode
end

return {
   compile = compile
}
