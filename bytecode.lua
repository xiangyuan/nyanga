--[=[
 dump   = header proto+ 0U
 header = ESC 'L' 'J' versionB flagsU [namelenU nameB*]
 proto  = lengthU pdata
 pdata  = phead bcinsW* uvdataH* kgc* knum* [debugB*]
 phead  = flagsB numparamsB framesizeB numuvB numkgcU numknU numbcU
          [debuglenU [firstlineU numlineU]]
 kgc    = kgctypeU { ktab | (loU hiU) | (rloU rhiU iloU ihiU) | strB* }
 knum   = intU0 | (loU1 hiU)
 ktab   = narrayU nhashU karray* khash*
 karray = ktabk
 khash  = ktabk ktabk
 ktabk  = ktabtypeU { intU | (loU hiU) | strB* }
 uvdata = register index with high bit set if local to outer
 debug  = lninfoV* uvals vars '\0'
 uvals  = nameB* '\0'
 vars   = nameB* '\0' startU endU

 B = 8 bit,
 H = 16 bit,
 W = 32 bit,
 V = B, H or W,
 U = ULEB128 of W, U0/U1 = ULEB128 of W+1,
]=]

local bit  = require 'bit'
local ffi  = require 'ffi'
local util = require 'util'

local typeof = getmetatable

local function enum(t)
   for i=0,#t do t[t[i]] = i end
   return t
end

-- forward declarations
local Buf, Ins, Proto, Dump, KNum, KObj

local MAX_REG = 200
local MAX_UVS = 60

local BC = enum {
   [0] = 'ISLT', 'ISGE', 'ISLE', 'ISGT', 'ISEQV', 'ISNEV', 'ISEQS','ISNES',
   'ISEQN', 'ISNEN', 'ISEQP', 'ISNEP', 'ISTC', 'ISFC', 'IST', 'ISF', 'MOV',
   'NOT', 'UNM', 'LEN', 'ADDVN', 'SUBVN', 'MULVN', 'DIVVN', 'MODVN', 'ADDNV',
   'SUBNV', 'MULNV', 'DIVNV', 'MODNV', 'ADDVV', 'SUBVV', 'MULVV', 'DIVVV',
   'MODVV', 'POW', 'CAT', 'KSTR', 'KCDATA', 'KSHORT', 'KNUM', 'KPRI', 'KNIL',
   'UGET', 'USETV', 'USETS', 'USETN', 'USETP', 'UCLO', 'FNEW', 'TNEW', 'TDUP',
   'GGET', 'GSET', 'TGETV', 'TGETS', 'TGETB', 'TSETV', 'TSETS', 'TSETB',
   'TSETM', 'CALLM', 'CALL', 'CALLMT', 'CALLT', 'ITERC', 'ITERN', 'VARG',
   'ISNEXT', 'RETM', 'RET', 'RET0', 'RET1', 'FORI', 'JFORI', 'FORL', 'IFORL',
   'JFORL', 'ITERL', 'IITERL', 'JITERL', 'LOOP', 'ILOOP', 'JLOOP', 'JMP',
   'FUNCF', 'IFUNCF', 'JFUNCF', 'FUNCV', 'IFUNCV', 'JFUNCV', 'FUNCC', 'FUNCCW',
}

local BC_ABC = 0
local BC_AD  = 1
local BC_AJ  = 2

local BC_MODE = {
   [0] = 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1,
   1, 0, 0, 0, 2, 1, 1, 1, 1, 2, 2, 2, 2, 1, 2, 2, 1, 2, 2, 1, 2, 1,
   1, 1, 1, 1, 1, 1, 1,
}

local VKNIL   = 0
local VKFALSE = 1
local VKTRUE  = 2

local NO_JMP = bit.bnot(0)

local KOBJ = enum {
   [0] = "CHILD", "TAB", "I64", "U64", "COMPLEX", "STR",
}
local KTAB = enum {
   [0] = "NIL", "FALSE", "TRUE", "INT", "NUM", "STR",
}

local FOR_IDX   = "(for index)";
local FOR_STOP  = "(for limit)";
local FOR_STEP  = "(for step)";
local FOR_GEN   = "(for generator)";
local FOR_STATE = "(for state)";
local FOR_CTL   = "(for control)";

ffi.cdef[[
   void *malloc(size_t);
   void *realloc(void*, size_t);
   int free(void*);

   typedef struct Buf {
     size_t size;
     size_t offs;
     uint8_t *data;
   } Buf;
]]

Buf = { }
Buf.new = function(size)
   if not size then
      size = 2048
   end
   local self = ffi.new('Buf', size)
   self.data  = ffi.C.malloc(size)
   self.offs  = 0
   return self
end
Buf.__gc = function(self)
   ffi.C.free(self.data)
end
Buf.__index = { }
Buf.__index.need = function(self, size)
   local need_size = self.offs + size
   if self.size <= need_size then
      while self.size <= need_size do
         self.size = self.size * 2
      end
      self.data = ffi.C.realloc(ffi.cast('void*', self.data), self.size)
   end
end
Buf.__index.put = function(self, v)
   self:need(1)
   local offs = self.offs
   self.data[offs] = v
   self.offs = offs + 1
   return offs
end
Buf.__index.put_uint8 = Buf.__index.put

Buf.__index.put_uint16 = function(self, v)
   self:need(2)
   local offs = self.offs
   local dptr = self.data + offs
   dptr[0] = v
   v = bit.rshift(v, 8)
   dptr[1] = v
   self.offs = offs + 2
   return offs
end

Buf.__index.put_uint32 = function(self, v)
   self:need(4)
   local offs = self.offs
   local dptr = self.data + offs

   dptr[0] = v
   v = bit.rshift(v, 8)
   dptr[1] = v
   v = bit.rshift(v, 8)
   dptr[2] = v
   v = bit.rshift(v, 8)
   dptr[3] = v

   self.offs = offs + 4
   return offs
end

Buf.__index.put_uleb128 = function(self,  v)
   v = tonumber(v)
   local i, offs = 0, self.offs
   repeat
      local b = bit.band(v, 0x7f)
      v = bit.rshift(v, 7)
      if v ~= 0 then
         b = bit.bor(b, 0x80)
      end
      self:put(b)
      i = i + 1
   until v == 0
   return offs
end

Buf.__index.put_bytes = function(self, v)
   local offs = self.offs
   self:need(#v)
   ffi.copy(self.data + offs, v)
   self.offs = offs + #v
   return offs
end
Buf.__index.pack = function(self)
   return ffi.string(self.data, self.offs)
end

local double_1 = ffi.typeof('double[1]')
local uint32_1 = ffi.typeof('uint32_t[1]')
Buf.__index.put_number = function(self, v)
   local offs = self.offs
   local numv = double_1(v)
   local char = ffi.cast('uint8_t*', numv)

   local u32_lo, u32_hi = uint32_1(0), uint32_1(0)
   ffi.copy(u32_lo, char, 4)
   ffi.copy(u32_hi, char + 4, 4)

   self:put_uleb128(1 + 2 * u32_lo[0]) -- 33 bits with lsb set
   if u32_lo[0] >= 0x80000000 then
      self.data[self.offs-1] = bit.bor(self.data[self.offs-1], 0x10)
   end
   self:put_uleb128(u32_hi[0])

   return offs
end

ffi.metatype('Buf', Buf)

Ins = { }
Ins.__index = { }
function Ins.new(op, a, b, c)
   return setmetatable({
      op;
      a or 0;
      b or 0;
      c or 0;
   }, Ins)
end
function Ins.__index:write(buf)
   local op, a = self[1], self[2]
   buf:put(op)
   buf:put(a)
   local mode = BC_MODE[op]
   if mode == BC_ABC then
      local b, c = self[3], self[4]
      buf:put(c)
      buf:put(b)
   elseif mode == BC_AD then
      local d = self[3]
      buf:put_uint16(d)
   elseif mode == BC_AJ then
      local j = self[3]
      buf:put_uint16(j + 0x8000)
   else
      error("bad instruction ["..tostring(op).."] (op mode unknown)")
   end
end

KObj = { }
KObj.__index = { }
function KObj.new(v)
   return setmetatable({ v }, KObj)
end
function KObj.__index:write(buf)
   local t, v = type(self[1]), self[1]
   if t == "string" then
      self:write_string(buf, v)
   elseif t == 'table' then
      if typeof(v) == Proto then
         self:write_proto(buf, v)
      else
         self:write_table(buf, v)
      end
   end
end
function KObj.__index:write_string(buf, v)
   buf:put_uleb128(KOBJ.STR + #v)
   buf:put_bytes(v)
end
function KObj.__index:write_table(buf, v)
   error("NYI")
   local seen = { }
   for i, v in ipairs(v) do
      seen[i] = true
   end
end

KNum = { }
KNum.__index = { }
function KNum.new(v)
   return setmetatable({ v }, KNum)
end
function KNum.__index:write(buf)
   buf:put_number(self[1])
end

Proto = {
   CHILD  = 0x01; -- Has child prototypes.
   VARARG = 0x02; -- Vararg function.
   FFI    = 0x04; -- Uses BC_KCDATA for FFI datatypes.
   NOJIT  = 0x08; -- JIT disabled for this function.
   ILOOP  = 0x10; -- Patched bytecode with ILOOP etc.
}
function Proto.new(flags, outer)
   return setmetatable({
      flags  = flags or 0;
      outer  = outer;
      params = { };
      upvals = { };
      code   = { };
      kobj   = { };
      knum   = { };
      debug  = { };
      lninfo = { };
      labels = { };
      tohere = { };
      kcache = { };
      varinfo = { };
      actvars = { };
      freereg   = 0;
      currline  = 1;
      firstline = 1;
      numlines  = 1;
      framesize = 0;
      explret = false;
   }, Proto)
end
Proto.__index = { }
function Proto.__index:nextreg(num)
   num = num or 1
   local reg = self.freereg
   self.freereg = self.freereg + num
   if self.freereg >= self.framesize then
      self.framesize = self.freereg
   end
   return reg
end
function Proto.__index:enter()
   local outer = self.actvars
   self.actvars = setmetatable({ }, {
      freereg = self.freereg;
      __index = outer;
   })
end
function Proto.__index:is_root_scope()
   return (getmetatable(self.actvars) == nil)
end
function Proto.__index:leave()
   local scope = assert(getmetatable(self.actvars), "cannot leave main scope")
   self.freereg = scope.freereg
   self.actvars = scope.__index
end
function Proto.__index:child(flags)
   self.flags = bit.bor(self.flags, Proto.CHILD)
   local child = Proto.new(flags, self)
   child.idx = #self.kobj
   self.kobj[child] = #self.kobj
   self.kobj[#self.kobj + 1] = child
   return child
end
function Proto.__index:const(val)
   if type(val) == 'string' then
      if not self.kcache[val] then
         local item = KObj.new(val)
         item.idx = #self.kobj
         self.kcache[val] = item
         self.kobj[#self.kobj + 1] = item
      end
   elseif type(val) == 'number' then
      if not self.kcache[val] then
         local item = KNum.new(val)
         item.idx = #self.knum
         self.kcache[val] = item
         self.knum[#self.knum + 1] = item
      end
   else
      error("not a const: "..tostring(val))
   end
   return self.kcache[val].idx
end
function Proto.__index:line(ln)
   self.currline = ln
   if ln > self.currline then
      self.numlines = ln
   end
end
function Proto.__index:emit(op, a, b, c)
   --print(("Ins:%s %s %s %s"):format(BC[op], a, b, c))
   local ins = Ins.new(op, a, b, c)
   self.code[#self.code + 1] = ins
   self.lninfo[#self.lninfo + 1] = self.currline
   return ins
end
function Proto.__index:write(buf)
   local has_child
   if bit.band(self.flags, Proto.CHILD) ~= 0 then
      has_child = true
      for i=1, #self.kobj do
         local o = self.kobj[i]
         if typeof(o) == Proto then
            o:write(buf)
         end
      end
   end

   local body = Buf.new()
   self:write_body(body)

   local offs = body.offs
   self:write_debug(body)

   local head = Buf.new()
   self:write_head(head, body.offs - offs)

   buf:put_uleb128(head.offs + body.offs) -- length of the proto

   local head_pack = ffi.string(head.data, head.offs)
   local body_pack = ffi.string(body.data, body.offs)

   buf:put_bytes(head_pack)
   buf:put_bytes(body_pack)
end
function Proto.__index:write_head(buf, size_debug)
   buf:put(self.flags)
   buf:put(#self.params)
   buf:put(self.framesize)
   buf:put(#self.upvals)
   buf:put_uleb128(#self.kobj)
   buf:put_uleb128(#self.knum)
   buf:put_uleb128(#self.code)
   buf:put_uleb128(size_debug or 0)
   buf:put_uleb128(self.firstline)
   buf:put_uleb128(self.numlines)
end
function Proto.__index:write_body(buf)
   for i=1, #self.code do
      self.code[i]:write(buf)
   end
   for i=1, #self.upvals do
      local uval = self.upvals[i]
      if uval.outer_idx then
         -- the upvalue refer to a local of the enclosing function
         local uv = bit.bor(uval.outer_idx, 0x8000)
         buf:put_uint16(uv)
      else
         -- the upvalue refer to an upvalue of the enclosing function
         local uv = uval.outer_uv
         buf:put_uint16(uv)
      end
   end
   for i=#self.kobj, 1, -1 do
      local o = self.kobj[i]
      if typeof(o) == Proto then
         buf:put_uleb128(KOBJ.CHILD)
      else
         self.kobj[i]:write(buf)
      end
   end
   for i=1, #self.knum do
      self.knum[i]:write(buf)   
   end
end
function Proto.__index:write_debug(buf)
   local first = self.firstline
   if self.numlines < 256 then
      for i=1, #self.lninfo do
         local delta = self.lninfo[i] - first
         buf:put_uint8(delta)
      end
   elseif self.numlines < 65536 then 
      for i=1, #self.lninfo do
         local delta = self.lninfo[i] - first
         buf:put_uint16(delta)
      end
   else
      for i=1, #self.lninfo do
         local delta = self.lninfo[i] - first
         buf:put_uint32(delta)
      end
   end
   for i=1, #self.upvals do
      local uval = self.upvals[i]
      buf:put_bytes(uval.vinfo.name.."\0")
   end
   local lastpc = 0
   for i=1, #self.varinfo do
      local var = self.varinfo[i]
      local startpc, endpc = (var.startpc or 0), (var.endpc or 0) + 1
      buf:put_bytes(var.name.."\0")
      buf:put_uleb128(startpc - lastpc)
      buf:put_uleb128(endpc - startpc)
      lastpc = startpc
   end
end
function Proto.__index:newvar(name, reg, ofs)
   if not reg then reg = self:nextreg() end
   if not ofs then ofs = #self.code end
   local var = {
      idx      = reg;
      startpc  = ofs;
      endpc    = ofs;
      name     = name;
   }
   self.actvars[name] = var
   self.varinfo[name] = var

   var.vidx = #self.varinfo
   self.varinfo[#self.varinfo + 1] = var

   return var
end
function Proto.__index:lookup(name)
   if self.actvars[name] then
      return self.actvars[name], false
   elseif self.outer then
      return self.outer:lookup(name), true
   end
   return nil
end
function Proto.__index:getvar(name)
   local info = self.actvars[name]
   if not info then return nil end
   if not info.startpc then
      info.startpc = #self.code
   end
   info.endpc = #self.code
   return info.idx
end
function Proto.__index:param(...)
   local var = self:newvar(...)
   var.startpc = 0
   self.params[#self.params + 1] = var
   return var.idx
end
function Proto.__index:upval(name)
   if not self.upvals[name] then
      local proto, upval, vinfo = self.outer, { }
      while proto do
         if proto.actvars[name] then
            break
         end
         proto = proto.outer
      end
      vinfo = assert(self:lookup(name), "no upvalue found for "..name)

      upval = { vinfo = vinfo; proto = proto; }

      -- for each upval we set either outer_idx or outer_uv
      if proto == self.outer then
         -- The variable is in the enclosing function's scope.
         -- We store just its register index.
         upval.outer_idx = vinfo.idx
      else
         -- The variable is in the outer scope of the enclosing
         -- function. We register this variable as an upvalue for
         -- the enclosing function. Then we store the upvale index.
         upval.outer_uv = self.outer:upval(name)
      end

      proto.need_close = true

      self.upvals[name] = upval
      upval.idx = #self.upvals
      self.upvals[#self.upvals + 1] = upval
   end
   return self.upvals[name].idx
end
function Proto.__index:here(name)
   if name == nil then name = util.genid() end
   if self.tohere[name] then
      -- forward jump
      local back = self.tohere[name]
      for i=1, #back do
         local offs = back[i]
         self.code[offs][3] = #self.code - offs
      end
      self.tohere[name] = nil
   else
      -- backward jump
      self.labels[name] = #self.code - 1
   end
   return name
end
function Proto.__index:enable_jump(name)
   if type(name) == 'number' then
      error("bad label")
   end
   local here = self.tohere[name]
   if not here then
      here = { }
      self.tohere[name] = here
   end
   here[#here + 1] = #self.code + 1
end
function Proto.__index:jump(name)
   if self.labels[name] then
      -- backward jump
      local offs = self.labels[name]
      if self.need_close then
         return self:emit(BC.UCLO, self.freereg, offs - #self.code)
      else
         return self:emit(BC.JMP, self.freereg, offs - #self.code)
      end
   else
      -- forward jump
      self:enable_jump(name)
      return self:emit(BC.JMP, self.freereg, NO_JMP)
   end
end
function Proto.__index:loop(name)
   if self.labels[name] then
      -- backward jump
      local offs = self.labels[name]
      return self:emit(BC.LOOP, self.freereg, offs - #self.code)
   else
      -- forward jump
      self:enable_jump(name)
      return self:emit(BC.LOOP, self.freereg, NO_JMP)
   end
end
function Proto.__index:op_jump(delta)
   return self:emit(BC.JMP, self.freereg, delta)
end
function Proto.__index:op_loop(delta)
   return self:emit(BC.LOOP, self.freereg, delta)
end

-- branch if condition
function Proto.__index:op_test(cond, a, here)
   local inst = self:emit(cond and BC.IST or BC.ISF, 0, a)
   if here then here = self:jump(here) end
   return inst, here
end
-- branch if comparison
function Proto.__index:op_comp(cond, a, b, here)
   if cond == 'LE' then
      cond = 'GE'
      a, b = b, a
   elseif cond == 'LT' then
      cond = 'GT'
      a, b = b, a
   elseif cond == 'EQ' or cond == 'NE' then
      local tb = type(b)
      if tb == 'nil' or tb == 'boolean' then
         cond = cond..'P'
         if tb == 'nil' then
            b = VKNIL
         else
            b = b == true and VKTRUE or VKFALSE
         end
      -- XXX: we can't differentiate between a number and a register
      --elseif tb == 'number' then
      --   cond = cond..'N'
      elseif tb == 'string' then
         cond = cond..'S'
      else
         cond = cond..'V'
      end
   end
   local inst = self:emit(BC['IS'..cond], a, b)
   if here then here = self:jump(here) end
   return inst, here
end

function Proto.__index:op_add(dest, var1, var2)
   return self:emit(BC.ADDVV, dest, var1, var2)
end
function Proto.__index:op_sub(dest, var1, var2)
   return self:emit(BC.SUBVV, dest, var1, var2)
end
function Proto.__index:op_mul(dest, var1, var2)
   return self:emit(BC.MULVV, dest, var1, var2)
end
function Proto.__index:op_div(dest, var1, var2)
   return self:emit(BC.DIVVV, dest, var1, var2)
end
function Proto.__index:op_mod(dest, var1, var2)
   return self:emit(BC.MODVV, dest, var1, var2)
end
function Proto.__index:op_pow(dest, var1, var2)
   return self:emit(BC.POW, dest, var1, var2)
end
function Proto.__index:op_gget(dest, name)
   return self:emit(BC.GGET, dest, self:const(name))
end
function Proto.__index:op_gset(from, name)
   return self:emit(BC.GSET, from, self:const(name))
end

function Proto.__index:op_not(dest, var1)
   return self:emit(BC.NOT, dest, var1)
end
function Proto.__index:op_unm(dest, var1)
   return self:emit(BC.UNM, dest, var1)
end
function Proto.__index:op_len(dest, var1)
   return self:emit(BC.LEN, dest, var1)
end

function Proto.__index:op_move(dest, from)
   return self:emit(BC.MOV, dest, from)
end
function Proto.__index:op_load(dest, val)
   local tv = type(val)
   if tv == 'nil' then
      return self:emit(BC.KPRI, dest, VKNIL)
   elseif tv == 'boolean' then
      return self:emit(BC.KPRI, dest, val and VKTRUE or VKFALSE)
   elseif tv == 'string' then
      return self:emit(BC.KSTR, dest, self:const(val))
   elseif tv == 'number' then
      if math.floor(val) == val and val < 0x8000 and val >= -0x8000 then
         return self:emit(BC.KSHORT, dest, val)
      else
         return self:emit(BC.KNUM, dest, self:const(val))
      end
   else
      error("cannot load as constant: "..tostring(val))
   end
end
function Proto.__index:op_tnew(dest, narry, nhash)
   if narry then
      if narry < 3 then
         narry = 3
      elseif narry > 0x7ff then
         narry = 0x7ff
      end
   else
      narry = 0
   end
   if nhash then
      nhash = math.ceil(nhash / 2)
   else
      nhash = 0
   end
   return self:emit(BC.TNEW, dest, bit.bor(narry, bit.lshift(nhash, 11)))
end
function Proto.__index:op_tget(dest, tab, key)
   if type(key) == 'string' then
      return self:emit(BC.TGETS, dest, tab, self:const(key))
   else
      return self:emit(BC.TGETV, dest, tab, key)
   end
end
function Proto.__index:op_tset(tab, key, val)
   if type(key) == 'string' then
      return self:emit(BC.TSETS, val, tab, self:const(key))
   else
      return self:emit(BC.TSETV, val, tab, key)
   end
end
function Proto.__index:op_tsetm(base, vnum)
   local knum = double_1(0)
   local vint = ffi.cast('uint8_t*', knum)
   vint[0] = bit.band(vnum, 0x00FF)
   vint[1] = bit.rshift(vnum, 8)
   local vidx = self:const(tonumber(knum[0]))
   return self:emit(BC.TSETM, base, vidx)
end
function Proto.__index:op_fnew(dest, pidx)
   return self:emit(BC.FNEW, dest, pidx)
end
function Proto.__index:op_uclo(jump)
   return self:emit(BC.UCLO, #self.actvars, jump or 0)
end
function Proto.__index:op_uset(name, val)
   local slot = self:upval(name)
   local tv   = type(val)
   if tv == 'string' then
      return self:emit(BC.USETS, slot, self:const(val))
   elseif tv == 'nil' or tv == 'boolean' then
      local pri
      if tv == 'nil' then
         pri = VKNIL
      else
         pri = val and VKTRUE or VKFALSE
      end
      return self:emit(BC.USETP, slot, pri)
   else
      return self:emit(BC.USETV, slot, val)
   end
end
function Proto.__index:op_uget(dest, name)
   local slot = self:upval(name)
   return self:emit(BC.UGET, dest, slot)
end
function Proto.__index:close_block_uvals(reg, exit)
   -- the condition on reg ensure that UCLO is emitted only if
   -- local variables were declared in the block
   local block_uclo = (reg < self.freereg) and not self:is_root_scope()

   if self.need_close and block_uclo then
      if exit then
         assert(not self.labels[name], "expected forward jump")
         self:enable_jump(exit)
         self:emit(BC.UCLO, reg, NO_JMP)
      else
         self:emit(BC.UCLO, reg, 0)
      end
   else
      if exit then
         assert(not self.labels[name], "expected forward jump")
         self:enable_jump(exit)
         return self:emit(BC.JMP, reg, NO_JMP)
      end
   end
end
function Proto.__index:close_uvals()
   if self.need_close then
      self:emit(BC.UCLO, #self.actvars, 0)
   end
end
function Proto.__index:op_ret(base, rnum)
   if #self.code > 0 and self.code[#self.code][1] == BC.CALLMT then return end
   self:close_uvals()
   return self:emit(BC.RET, base, rnum + 1)
end
function Proto.__index:op_ret0()
   if #self.code > 0 and self.code[#self.code][1] == BC.CALLMT then return end
   self:close_uvals()
   return self:emit(BC.RET0, 0, 1)
end
function Proto.__index:op_ret1(base)
   if #self.code > 0 and self.code[#self.code][1] == BC.CALLMT then return end
   self:close_uvals()
   return self:emit(BC.RET1, base, 2)
end
function Proto.__index:op_retm(base, rnum)
   if #self.code > 0 and self.code[#self.code][1] == BC.CALLMT then return end
   self:close_uvals()
   return self:emit(BC.RETM, base, rnum)
end
function Proto.__index:op_varg(base, want)
   return self:emit(BC.VARG, base, want + 1, #self.params)
end
function Proto.__index:op_call(base, want, narg)
   return self:emit(BC.CALL, base, want + 1, narg + 1)
end
function Proto.__index:op_callt(base, narg)
   self:close_uvals()
   return self:emit(BC.CALLT, base, narg + 1)
end
function Proto.__index:op_callm(base, want, narg)
   return self:emit(BC.CALLM, base, want + 1, narg)
end
function Proto.__index:op_callmt(base, narg)
   self:close_uvals()
   return self:emit(BC.CALLMT, base, narg)
end
function Proto.__index:op_fori(base, stop, step)
   local loop = self:emit(BC.FORI, base, NO_JMP)
   self:here(loop)
   return loop
end
function Proto.__index:op_forl(base, loop)
   local offs = self.labels[loop]
   loop[3] = #self.code - offs
   return self:emit(BC.FORL, base, offs - #self.code)
end
function Proto.__index:op_iterc(base, want)
   return self:emit(BC.ITERC, base, want + 1, 3)
end
function Proto.__index:op_iterl(base, loop)
   local offs = self.labels[loop]
   return self:emit(BC.ITERL, base, offs - #self.code)
end
function Proto.__index:op_cat(base, rbot, rtop)
   return self:emit(BC.CAT, base, rbot, rtop)
end

Dump = {
   HEAD_1 = 0x1b;
   HEAD_2 = 0x4c;
   HEAD_3 = 0x4a;
   VERS   = 0x01;
   BE     = 0x01;
   STRIP  = 0x02;
   FFI    = 0x04;
   DEBUG  = false;
}
Dump.__index = { }
function Dump.new(main, name, flags)
   local self =  setmetatable({
      main  = main or Proto.new(Proto.VARARG);
      name  = name;
      flags = flags or 0;
   }, Dump)
   return self
end
function Dump.__index:write_header(buf)
   buf:put(Dump.HEAD_1)
   buf:put(Dump.HEAD_2)
   buf:put(Dump.HEAD_3)
   buf:put(Dump.VERS)
   buf:put(self.flags)
   local name = self.name
   if bit.band(self.flags, Dump.STRIP) == 0 then
      if not name then
         name = '(binary)'
      end
      buf:put_uleb128(#name)
      buf:put_bytes(name)
   end
end
function Dump.__index:write_footer(buf)
   buf:put(0x00)
end
function Dump.__index:pack()
   local buf = Buf.new()
   self:write_header(buf)
   self.main:write(buf)
   self:write_footer(buf)
   return buf:pack()
end

return {
   Buf   = Buf;
   Ins   = Ins;
   KNum  = KNum;
   KObj  = KObj;
   Proto = Proto;
   Dump  = Dump;
   BC    = BC;
}

