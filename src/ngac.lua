--[=[
Nyanga -- Modifiable OO Lua Dialect. http://github.com/richardhundt/nyanga

Copyright (C) 2013-2014 Richard Hundt and contributors. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

[ MIT license: http://www.opensource.org/licenses/mit-license.php ]
]=]

local bcsave = require("jit.bcsave")

local usage = "usage: %s [options]... input output.\
Available options are:\
  -t type \tOutput file format.\
  -b      \tList formatted bytecode.\
  -n name \tProvide a chunk name.\
  -p      \tPrint the parse tree.\
  -l      \tPrint the lua tree.\
"

local function runopt(args)
   local util        = require('nyanga.lang.util')
   local parser      = require('nyanga.lang.parser')
   local transformer = require('nyanga.lang.transformer')
   local generator   = require('nyanga.lang.generator')
   local gensource   = require('nyanga.lang.gensource')

   if #args == 0 then
      print(string.format(usage, arg[0]))
      os.exit()
   end

   local opts = { }
   local i = 0
   repeat
      i = i + 1
      local a = args[i]
      if a == "-t" then
         i = i + 1
         opts['-t'] = args[i]
      elseif a == "-h" or a == "-?" then
         print(string.format(usage, arg[0]))
         os.exit(0)
      elseif a == "-n" then
         i = i + 1
	 opts['-n'] = args[i]
      elseif string.sub(a, 1, 1) == '-' then
         opts[a] = true
      else
         opts[#opts + 1] = a
      end
   until i == #args

   local code, name, dest
   if opts['-e'] then
      code = opts['-e']
      name = code
      dest = opts[1]
   elseif opts['--'] then
      code = io.stdin:read('*a')
      name = "stdin"
      dest = opts[1]
   else
      name = opts[1]
      dest = opts[2]
      local file = assert(io.open(opts[1], 'r'))
      code = file:read('*a')
      file:close()
   end

   local srctree = parser.parse(code, name, opts)

   if opts['-p'] then
      io.stdout:write("Nyanga parse tree:\n")
      io.stdout:write(util.dump(srctree))
      os.exit(0)
   end

   local dsttree = transformer.transform(srctree, code, name, opts)

   if opts['-l'] then
      io.stdout:write("Nyanga transform tree:\n")
      io.stdout:write(util.dump(dsttree))
      os.exit(0)
   end

   if #opts ~= 2 then
      io.stderr:write(string.format(usage, arg[0]))
      os.exit(1)
   end

   local luacode
   if opts['-t'] == 'lua' or string.sub(dest, -4) == '.lua' then
      luacode = gensource.generate(dsttree, '@'..name, opts)
      local file = io.open(dest, 'w+')
      file:write(luacode)
      file:close()
      os.exit(0)
   else
      luacode = generator.generate(dsttree, '@'..name, opts)
   end

   if opts['-b'] then
      bcsave.start('-l', '-e', luacode)
      os.exit(0)
   end

   args = { }
   if opts['-n'] then
      args[#args + 1] = '-n'
      args[#args + 1] = opts['-n']
   end
   if opts['-t'] then
      args[#args + 1] = '-t'
      args[#args + 1] = opts['-t']
   end
   args[#args + 1] = '-e'
   args[#args + 1] = luacode
   args[#args + 1] = dest

   bcsave.start(unpack(args))
end

runopt(arg)

