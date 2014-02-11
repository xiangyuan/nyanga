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

package.path  = ';;./lib/?.luac;./lib/?.lua;'..package.path
package.cpath = ';;./lib/?.so;'..package.cpath

require("nyanga.lang")

do
   local paths = {
      ".",
      "./lib",
      "./src",
      os.getenv('HOME').."/.nyanga",
      "/usr/local/lib/nyanga",
      "/usr/lib/nyanga",
   }
   local buf = { }
   for i, frag in ipairs(paths) do
      buf[#buf + 1] = frag.."/?.ngac"
      buf[#buf + 1] = frag.."/?/init.ngac"
      buf[#buf + 1] = frag.."/?.nga"
      buf[#buf + 1] = frag.."/?/init.nga"
      buf[#buf + 1] = frag.."/?"
   end
   NYANGA_PATH = table.concat(buf, ';')..';'
end


local usage = "usage: %s [options]... [script [args]...].\
Available options are:\
  -e chunk\tExecute string 'chunk'.\
  -o file \tSave bytecode to 'file'.\
  -b      \tDump formatted bytecode.\
  -p      \tPrint the parse tree.\
  -t      \tPrint the transformed tree.\
  --      \tStop handling options."
local function runopt(args)
   local compiler = require("nyanga.lang.compiler")

   if #args == 0 then
      print(string.format(usage, arg[0]))
      os.exit()
   end

   local opts = { }
   local i = 0
   repeat
      i = i + 1
      local a = args[i]
      if a == "-e" then
         i = i + 1
         opts['-e'] = args[i]
      elseif a == "-o" then
         i = i + 1
         opts['-o'] = args[i]
      elseif a == "-h" or a == "-?" then
         print(string.format(usage, arg[0]))
         os.exit()
      elseif string.sub(a, 1, 1) == '-' then
         opts[a] = true
      else
         opts[#opts + 1] = a
      end
   until i == #args

   args = { [0] = args[0], unpack(opts, 2) }
   local code, name
   if opts['-e'] then
      code = opts['-e']
      name = code
   elseif opts['--'] then
      code = io.stdin:read('*a')
   else
      if not opts[1] then
         error("no chunk or script file provided")
      end
      name = opts[1]
      local file = assert(io.open(opts[1], 'r'))
      code = file:read('*a')
      file:close()
   end
   local main = compiler.compile(code, name, opts)
   if not (opts['-b'] or opts['-o']) then
      main(name, unpack(args))
   end
end

runopt(arg)

