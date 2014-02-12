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

package.path  = ';;./lib/?.raw;./lib/?.lua;'..package.path
package.path  = './?.nga;./lib/?.nga;/usr/local/lib/nyanga/?.nga;'..package.path
package.cpath = ';;./lib/?.so;'..package.cpath

require("nyanga.lang")

local usage = "usage: %s [options]... [script [args]...].\
Available options are:\
  -e chunk\tExecute string 'chunk'.\
  -c ...  \tCompile or list bytecode.\
  --      \tStop handling options."

local function runopt(args)
   local loader = require("nyanga.lang.loader")

   if #args == 0 then
      print(string.format(usage, arg[0]))
      os.exit()
   end

   local args = { unpack(args) }
   local opts = { }
   repeat
      local a = table.remove(args, 1)
      if a == "-e" then
         opts['-e'] = table.remove(args, 1)
      elseif a == "-c" then
         opts['-c'] = true
         -- pass remaining args to compiler
         break
      elseif a == "-h" or a == "-?" then
         print(string.format(usage, arg[0]))
         os.exit()
      elseif string.sub(a, 1, 1) == '-' then
         opts[a] = true
      elseif #opts == 0 and not opts['-e'] then
         -- the file to run
         opts[#opts + 1] = a
      else
         -- pass remaining args to script
         break
      end
   until #args == 0

   local code, name
   if opts['-e'] then
      code = opts['-e']
      name = code
   elseif opts['--'] then
      code = io.stdin:read('*a')
   elseif opts['-c'] then
      require("nyangac").start(unpack(args))
      os.exit(0)
   else
      if not opts[1] then
         error("no chunk or script file provided")
      end
      name = opts[1]
      local file = assert(io.open(opts[1], 'r'))
      code = file:read('*a')
      file:close()
   end

   local main
   if string.sub(name, -4) == '.lua' then
      main = loadstring(code, '@'..name)
   else
      main = assert(loader.loadchunk(code, name))
   end
   main(name, unpack(args))
end

runopt(arg)

