--[=[
Copyright (C) 2013-2014 Richard Hundt and contributors.
See Copyright Notice in nyanga
]=]

local ffi      = require('ffi')
local lpeg     = require('lpeg')
local compiler = require('nyanga.compiler')

local Range
local export = { }
package.loaded['nyanga.runtime'] = export

local function loader(filename)
   if string.match(filename, "%.nga") then
      local namelist = { }
      for path in string.gmatch(NYANGA_PATH, "([^;]+)") do
         if path ~= "" then
            local filepath = path .. "/" .. filename
            local file = io.open(filepath, "r")
            if file then
               local src = file:read("*a")
               local pth = { }
               local code = compiler.compile(src, filepath)
               return assert(loadstring(code, '@'..filepath))
            end
         end
      end
   end
end

table.insert(package.loaders, loader)

local function __is__(a, b)
   if type(a) == 'cdata' then
      return ffi.istype(a, b)
   else
      local m = getmetatable(a)
      while m do
         if m == b then return true end
         m = m.__base
      end
   end
   return false
end

local Module = { }
function Module.__tostring(self)
   return string.format("Module<%s>", self.__name)
end
function Module.__index(self, k)
   if self.__getters__[k] then
      return self.__getters__[k](self)
   end
   if self.__members__[k] then
      return self.__members__[k]
   end
   return nil
end
function Module.__newindex(self, k, v)
   if self.__setters__[k] then
      self.__setters__[k](self, v)
   else
      rawset(self, k, v)
   end
end
function Module.__tostring(self)
   if self.toString then
      return self:toString()
   else
      return string.format('<%s>:%p', self.__name, self)
   end
end

local function module(name, body)
   local module = { __name = name }
   module.__getters__ = { }
   module.__setters__ = { }
   module.__members__ = { }

   body(setmetatable(module, Module))
   return module
end

local Class = { }
function Class.__call(class, ...)
   local obj
   if class.__apply then
      obj = class:__apply(...)
   else
      obj = { }
      setmetatable(obj, class)
      if class.__members__.self then
         class.__members__.self(obj, ...)
      end
   end
   return obj
end
function Class.__tostring(class)
   return string.format("Class<%s>", class.__name)
end

local special = {
   __add__ = { mmname = '__add', method = function(a, b) return a:__add__(b) end };
   __sub__ = { mmname = '__sub', method = function(a, b) return a:__sub__(b) end };
   __mul__ = { mmname = '__mul', method = function(a, b) return a:__mul__(b) end };
   __div__ = { mmname = '__div', method = function(a, b) return a:__div__(b) end };
   __pow__ = { mmname = '__pow', method = function(a, b) return a:__pow__(b) end };
   __mod__ = { mmname = '__mod', method = function(a, b) return a:__mod__(b) end };
   __len__ = { mmname = '__len', method = function(a, b) return a:__len__(b) end };
   __unm__ = { mmname = '__unm', method = function(a, b) return a:__unm__(b) end };
   __get__ = { mmname = '__getindex',  method = function(a, k) return a:__get__(k) end };
   __set__ = { mmname = '__setindex',  method = function(a, k, v) a:__set__(k, v) end };
   __concat__ = { mmname = '__concat', method = function(a, b) return a:__concat__(b) end };
   __pairs__  = { mmname = '__pairs',  method = function(a, b) return a:__pairs__() end };
   __ipairs__ = { mmname = '__ipairs', method = function(a, b) return a:__ipairs__() end };
   __call__   = { mmname = '__call',   method = function(self, ...) return self:__call__(...) end };
}

local function class(name, base, body)
   local class = { __name = name, __base = base }
   local __getters__ = { }
   local __setters__ = { }
   local __members__ = { }
   if base then
      setmetatable(__getters__, { __index = base.__getters__ })
      setmetatable(__setters__, { __index = base.__setters__ })
      setmetatable(__members__, { __index = base.__members__ })
   end

   class.__getters__ = __getters__
   class.__setters__ = __setters__
   class.__members__ = __members__

   function class.__index(o, k)
      if __getters__[k] then
         return __getters__[k](o)
      end
      if __members__[k] then
         return __members__[k]
      end
      if class.__getindex then
         return class.__getindex(o, k)
      end
      return nil
   end
   function class.__newindex(o, k, v)
      if __setters__[k] then
         __setters__[k](o, v)
      elseif class.__setindex then
         class.__setindex(o, k, v)
      else
         rawset(o, k, v)
      end
   end
   function class.__tostring(o)
      if o.toString then
         return o:toString()
      else
         return string.format('<%s>:%p', name, o)
      end
   end
   body(setmetatable(class, Class), base and base.__members__ or nil)
   for name, delg in pairs(special) do
      if __members__[name] then
         class[delg.mmname] = delg.method
      end
   end
   return class
end

local function include(into, ...)
   local args = { ... }
   for i=1, #args do
      local from = args[i] 
      for k,v in pairs(from.__getters__) do
         into.__getters__[k] = v
      end
      for k,v in pairs(from.__setters__) do
         into.__setters__[k] = v
      end
      for k,v in pairs(from.__members__) do
         into.__members__[k] = v
      end
   end
end

local Array = setmetatable({ __members__ = { } }, Class)
function Array:__apply(...)
   return setmetatable({
      length = select('#', ...), [0] = select(1, ...), select(2, ...)
   }, self)
end
function Array:self() end
function Array.__iter(a)
   local l = a.length
   local i = -1
   return function(a)
      i = i + 1
      local v = a[i]
      if i < l then
         return i, v
      end
      return nil
   end, a
end
Array.__pairs = function(self)
   return function(self, ctrl)
      local i = ctrl + 1
      if i < self.length then
         return i, self[i]
      end
   end, self, -1
end

function Array.__members__:join(sep)
   return table.concat({ Array.__spread(self) }, sep)
end
function Array.__members__:push(val)
   self[self.length] = val
end
function Array.__members__:pop()
   local last = self[self.length - 1]
   self[self.length - 1] = nil
   self.length = self.length - 1
   return last
end
function Array.__members__:shift()
   local v = self[0]
   local l = self.length
   for i=1, l - 1 do
      self[i - 1] = self[i]
   end
   self.length = l - 1
   self[l - 1] = nil
   return v
end
function Array.__members__:unshift(v)
   for i = l - 1, 0 do
      self[i + 1] = self[i]
   end
   self[0] = v
end
function Array.__members__:slice(offset, count)
   local a = Array()
   for i=offset, i + count do
      a[i] = self[i]
   end
   return a
end
function Array.__members__:reverse()
   local a = Array()
   for i = self.length - 1, 0 do
      a[a.length] = self[i]
   end
   return a
end
do
   local gaps = {
      1391376, 463792, 198768, 86961, 33936, 13776,
      4592, 1968, 861, 336, 112, 48, 21, 7, 3, 1
   }
   local less = function(a, b) return a < b end
   function Array.__members__:sort(before, n)
      n = n or self.length
      before = before or less
      for i=1, #gaps do
         local gap = gaps[i]
         for i = gap, n - 1 do
           local v = self[i]
           for j = i - gap, 0, -gap do
             local tv = self[j]
             if not before(v, tv) then break end
             self[i] = tv
             i = j
           end
           self[i] = v
         end
       end
       return self
   end
end
function Array.__spread(a)
   return unpack(a, 0, a.length - 1)
end
function Array.__len(a)
   return a.length
end
function Array.__tostring(a)
   if a.toString then
      return a:toString()
   end
   return string.format("[Array: %p]", self)
end
function Array.__index(a, k)
   if Array.__members__[k] then
      return Array.__members__[k]
   end
   return nil
end
function Array.__newindex(a, i, v)
   if type(i) == 'number' and i >= a.length then
      a.length = i + 1
   end
   rawset(a, i, v)
end
function Array.__members__:toString()
   local b = { }
   for i=0, self.length - 1 do
      b[#b + 1] = tostring(self[i])
   end
   return table.concat(b, ', ')
end
function Array.__members__:map(f)
   local b = Array()
   for i=0, self.length - 1 do
      b[i] = f(i, self[i])
   end
   return b
end

local function try(try, catch, finally)
   local ok, rv = xpcall(try, catch)
   if finally then finally() end
   return rv
end

local String = class("String", nil, function(self, super)
   local orig_meta = getmetatable("")
   for k, v in pairs(orig_meta.__index) do
      self.__members__[k] = v
   end
   self.__getindex = function(o, k)
      if type(k) == "table" and getmetatable(k) == Range then
         return string.sub(o, k.left, k.right)
      end
   end
   self.__members__.self = function(self, that)
      return tostring(that)
   end
   self.__members__.match = function(self, regex)
      if type(regex) == 'string' then
         return string.match(self, regex)
      else
         local capt = Array()
         while true do
            local result = regex:exec(self)
            if result == nil then
               break
            end
            capt[capt.length] = result[1]
         end
         if capt.length > 0 then
            return capt
         else
            return nil
         end
      end
   end
   self.__members__.toString = tostring
end)
debug.setmetatable("", String)

local RegExp = class("RegExp", nil, function(self, super)
   local pcre = require('pcre')

   self.__members__.self = function(self, source, flags)
      flags = flags or ''
      self.index = 0
      self.input = ''
      self.source  = source
      local opts = 0
      if string.find(flags, 'i') then
         opts = opts + pcre.lib.PCRE_CASELESS
         self.ignoreCase = true
      end
      if string.find(flags, 'm') then
         opts = opts + pcre.lib.PCRE_MULTILINE
         self.multiLine = true
      end
      self.pattern = assert(pcre.compile(source, opts))
      if string.find(flags, 'g') then
         self.global = true
      end
   end

   self.__members__.exec = function(self, str)
      if self.input ~= str then
         self.input = str
         self.index = 0
      end
      local result = pcre.execute(self.pattern, self.input, self.index)
      if type(result) == 'table' then
         self.index = self.index + #result[1] + 1
         return result
      elseif result == pcre.lib.PCRE_ERROR_NOMATCH then
         return nil
      else
         error(result, 2)
      end
   end

   self.__members__.test = function(self, str)
      local result = pcre.execute(self.pattern, str)
      if type(result) == 'table' then
         return true
      else
         return false
      end
   end

   self.__members__.toString = function(self)
      return string.format('RegExp(%q)', tostring(self.source))
   end
end)

local Error = class("Error", nil, function(self, super)
   self.__members__.self = function(self, mesg)
      self.message = mesg
      self.trace = debug.traceback(mesg, 2)
   end
   self.__members__.toString = function(self)
      return self.message
   end
end)

local function spread(o)
   local m = getmetatable(o)
   if m and m.__spread then
      return m.__spread(o)
   end
   return unpack(o)
end
local function each(o, ...)
   if type(o) == 'function' then
      return o, ...
   end
   local m = getmetatable(o)
   if m and m.__iter then
      return m.__iter(o, ...)
   end
   return pairs(o)
end

Range = { }
Range.__index = Range
function Range.__in(self, that)
   local n = tonumber(that)
   if type(n) == 'number' and n == n then
      return n >= self.min and n <= self.max
   end
   return false
end
function Range.__tostring(self)
   return string.format("Range[%s..%s]", self.left, self.right)
end
function Range.__iter(self)
   local i, r = self.left, self.right
   local n = i <= r and 1 or -1
   return function()
      local j = i
      i = i + n
      if n > 0 and j > r then
         return nil
      elseif n < 0 and j < r then
         return nil
      end
      return j
   end
end

local function range(left, right, inclusive)
   return setmetatable({
      left = left,
      right = right,
      inclusive = inclusive == true,
   }, Range)
end
local function __in__(self, that)
   local m = getmetatable(that)
   if m and m.__in then
      return m.__in(self)
   end
   if type(that) == 'table' then
      return rawget(that, self) ~= nil
   end
   return false
end

local function import(from, ...)
   if type(from) == 'string' then
      from = require(from)
   end
   local list = { }
   for i=1, select('#', ...) do
      list[i] = from[select(i, ...)]
   end
   return unpack(list)
end

local system
local function yield(...)
   local coro, main = coroutine.running()
   if main then
      return system.schedule(...)
   else
      return coroutine.yield(...)
   end
end

local ArrayPattern, TablePattern, ApplyPattern

local __var__ = newproxy()

local function __match__(that, this)
   print("match:", that, this)
   local type_this = type(this)
   local type_that = type(that)

   local meta_this = getmetatable(this)
   local meta_that = getmetatable(that)
   if meta_that then
      if meta_that.__match then
         return meta_that.__match(that, this)
      elseif meta_that == Class then
         return meta_this == that
      else
         return meta_this == meta_that
      end
   elseif type_this ~= type_that then
      return false
   else
      return this == that
   end
end

local function expand(iter, stat, ctrl, ...)
   if iter == nil then return ... end
   local k, v = iter(stat, ctrl)
   if k == nil then return ... end
   if type(v) == 'table' then
      return expand(v[1], v[2], v[3], expand(iter, stat, k, ...))
   end
   return v, expand(iter, stat, k, ...)
end

local function extract(patt, subj)
   return expand(patt:bind(subj))
end

local TablePattern = class("TablePattern", nil, function(self)
   self.__apply = function(self, keys, desc, meta)
      return setmetatable({
         keys = keys;
         desc = desc;
         meta = meta;
      }, self)
   end

   self.__pairs = function(self)
      local i = 0
      return function(self, _)
         i = i + 1
         local k = self.keys[i]
         if k ~= nil then
            return k, self.desc[k]
         end
      end, self, nil
   end

   self.__match = function(self, that)
      local desc = self.desc
      local meta = self.meta
      if meta and getmetatable(that) ~= meta then
         return false
      end
      for k, v in pairs(self) do
         if v == __var__ then
            if that[k] == nil then
               return false
            end
         else
            if not __match__(v, that[k]) then
               return false
            end
         end
      end
      return true
   end

   self.__members__.bind = function(self, subj)
      if subj == nil then return end
      local meta = self.meta
      local iter, stat, ctrl = pairs(self)
      return function(stat, ctrl)
         for k, v in iter, stat, ctrl do
            if v == __var__ then
               if meta then
                  -- XXX: assert instead?
                  return k, meta.__index(subj, k)
               else
                  return k, subj[k]
               end
            elseif type(v) == 'table' then
               return k, { v:bind(subj[k]) }
            end
         end
      end, stat, ctrl
   end
end)

local ArrayPattern = class("ArrayPattern", nil, function(self)
   self.__apply = function(self, ...)
      return setmetatable({
         length = select('#', ...), [0] = select(1, ...), select(2, ...)
      }, self)
   end

   self.__ipairs = function(self)
      return function(self, ctrl)
         local i = ctrl + 1
         if i < self.length then
            return i, self[i]
         end
      end, self, -1
   end

   self.__match = function(self, that)
      if getmetatable(that) ~= Array then
         return false
      end
      for k, v in ipairs(self) do
         if v ~= __var__ then
            if not __match__(v, that[i]) then
               return false
            end
         end
      end
      return true
   end

   self.__members__.bind = function(self, subj)
      if subj == nil then return end
      local iter, stat, ctrl = ipairs(self)
      return function(stat, ctrl)
         for i, v in iter, stat, ctrl do
            if v == __var__ then
               return i, subj[i]
            elseif type(v) == 'table' then
               return i, { v:bind(subj[i]) }
            end
         end
      end, stat, ctrl
   end

end)

local ApplyPattern = class("ApplyPattern", nil, function(self)
   self.__apply = function(self, base, ...)
      return setmetatable({
         base = base,
         narg = select('#', ...),
         ...
      }, self)
   end

   self.__match = function(self, that)
      local base = self.base
      if base.__match then
         return base.__match(base, that)
      end
      return getmetatable(that) == self.base
   end

   self.__members__.bind = function(self, subj)
      if subj == nil then return end
      local i = 1
      local subj = self.base.__unapply(subj)
      return function(self)
         while i <= self.narg do
            local k = i
            local v = self[i]
            i = i + 1
            if v == __var__ then
               return k, subj[k]
            elseif type(v) == 'table' then
               return k, { v:bind(subj[k]) }
            end
         end
      end, self, nil
   end

end)

local Grammar = { }
Grammar.__index = { }
Grammar.__index.match = function(self, ...)
   return self.__patt:match(...)
end
Grammar.__call = function(self, ...)
   return self.__patt:match(...)
end
Grammar.__tostring = function(self)
   return string.format('Grammar<%s>', tostring(self.__name))
end
Grammar.__index.__match = function(self, subj, ...)
   if type(subj) ~= 'string' then return false end
   return self.__patt:match(subj, ...)
end

local function grammar(name, patt)
   local self = { __name = name, __patt = patt }
   self.__unapply = function(subj)
      return { self.__patt:match(subj) }
   end
   return setmetatable(self, Grammar)
end

local rule = { }
lpeg.setmaxstack(1024)
do
   local def = { }

   def.nl  = lpeg.P("\n")
   def.pos = lpeg.Cp()

   local any=lpeg.P(1)
   lpeg.locale(def)

   def.a = def.alpha
   def.c = def.cntrl
   def.d = def.digit
   def.g = def.graph
   def.l = def.lower
   def.p = def.punct
   def.s = def.space
   def.u = def.upper
   def.w = def.alnum
   def.x = def.xdigit
   def.A = any - def.a
   def.C = any - def.c
   def.D = any - def.d
   def.G = any - def.g
   def.L = any - def.l
   def.P = any - def.p
   def.S = any - def.s
   def.U = any - def.u
   def.W = any - def.w
   def.X = any - def.x

   rule.def = def
   rule.Def = function(id)
      if def[id] == nil then
         throw("No predefined pattern '"..tostring(id).."'", 2)
      end
      return def[id]
   end

   local mm = getmetatable(lpeg.P(0))
   rule.__add = mm.__add
   rule.__sub = mm.__sub
   rule.__pow = mm.__pow
   rule.__mul = mm.__mul
   rule.__div = mm.__div
   rule.__len = mm.__len
   rule.__unm = mm.__unm
   for k,v in pairs(lpeg) do rule[k] = v end
end

local function run(code, ...)
   code(...)
end

local usage = "usage: %s [options]... [script [args]...].\
Available options are:\
  -e chunk\tExecute string 'chunk'.\
  -o file \tSave bytecode to 'file'.\
  -b      \tDump formatted bytecode.\
  -p      \tPrint the parse tree.\
  -t      \tPrint the transformed tree.\
  -s      \tUse the Lua source generator backend.\
  --      \tStop handling options."
local function runopt(args)
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
      name = '@'..opts[1]
      local file = assert(io.open(opts[1], 'r'))
      code = file:read('*a')
      file:close()
   end
   local main = assert(loadstring(compiler.compile(code, name, opts), name))
   if not opts['-b'] then
      main(unpack(args))
   end
end

local predef = {
   try    = try;
   Array  = Array;
   Error  = Error;
   RegExp = RegExp;
   Module = Module;
   Class  = Class;
   class  = class;
   module = module;
   import = import;
   yield  = yield;
   throw  = error;
   grammar = grammar;
   __rule__ = rule;
   include  = include;
   __range__  = range;
   __spread__ = spread;
   __typeof__ = type;
   __match__  = __match__;
   __extract__ = extract;
   __each__   = each;
   __var__ = __var__;
   __in__  = __in__;
   __is__  = __is__;
   __as__  = setmetatable;
   ArrayPattern = ArrayPattern;
   TablePattern = TablePattern;
   ApplyPattern = ApplyPattern;
}

export.run = run
export.runopt = runopt
export.predef = predef

system = require('system.nga')
package.loaded['@system'] = system
return export

