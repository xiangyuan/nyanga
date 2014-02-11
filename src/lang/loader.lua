local parser      = require('nyanga.lang.parser')
local transformer = require('nyanga.lang.transformer')
local generator   = require('nyanga.lang.generator')
local gensource   = require('nyanga.lang.gensource')

local magic = string.char(0x1b, 0x4c, 0x4a, 0x01)

local function loadchunk(code, name, opts)
   if string.sub(code, 1, #magic) ~= magic then
      local srctree = parser.parse(code, name, opts)
      local dsttree = transformer.transform(srctree, code, name, opts)
      code = generator.generate(dsttree, '@'..name, opts)
   end
   return loadstring(code, '@'..name)
end

local function loader(modname, opts)
   local filename, havepath
   if string.find(modname, '/') or string.sub(modname, -4) == '.nga' then
      filename = modname
   else
      filename = package.searchpath(modname, package.path)
   end
   if filename then
      local file = io.open(filename)
      if file then
         local code = file:read('*a')
         file:close()
         if string.sub(filename, -4) == '.nga' then
            return assert(loadchunk(code, filename, opts))
         end
      else
         -- die?
      end
   end
end

return {
   loader = loader;
   loadchunk = loadchunk;
}

