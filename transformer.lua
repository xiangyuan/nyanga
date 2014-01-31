local B = require('builder')
local util = require('util')

local Scope = { }
Scope.__index = Scope
function Scope.new(outer)
   local self = {
      outer = outer;
      entries = { };
   }
   return setmetatable(self, Scope)
end
function Scope:define(name, info)
   self.entries[name] = info
end
function Scope:lookup(name)
   if self.entries[name] then
      return self.entries[name]
   elseif self.outer then
      return self.outer:lookup(name)
   else
      return nil
   end
end

local Context = { }
Context.__index = Context
function Context.new()
   local self = {
      scope = Scope.new()
   }
   return setmetatable(self, Context)
end
function Context:enter()
   self.scope = Scope.new(self.scope)
end
function Context:leave()
   self.scope = self.scope.outer
end
function Context:define(name, info)
   info = info or { }
   self.scope:define(name, info)
   return info
end
function Context:lookup(name)
   local info = self.scope:lookup(name)
   return info
end

local match = { }

function match:Chunk(node)
   self.hoist = { }
   self.block = { }
   local export = B.identifier('export')
   self.block[#self.block + 1] = B.localDeclaration({ export }, { B.table({}) })
   for i=1, #node.body do
      local stmt = self:get(node.body[i])
      self.block[#self.block + 1] = stmt
   end
   for i=#self.hoist, 1, -1 do
      table.insert(self.block, 1, self.hoist[i])
   end
   self.block[#self.block + 1] = B.returnStatement({ export })
   return B.chunk(self.block)
end
function match:ImportStatement(node)
   local args = { self:get(node.from) }
   for i=1, #node.names do
      args[#args + 1] = B.literal(node.names[i].name)
   end
   return B.localDeclaration(self:list(node.names), {
      B.callExpression(B.identifier('import'), args)
   })
end
function match:ExportStatement(node)
   local block = { }
   for i=1, #node.names do
      local expr = B.memberExpression(
         B.identifier('export'), self:get(node.names[i])
      )
      block[#block + 1] = B.assignmentExpression(
         { expr }, { self:get(node.names[i]) }
      )
   end
   return B.blockStatement(block)
end
function match:Literal(node)
   return B.literal(node.value)
end
function match:Identifier(node)
   return B.identifier(node.name)
end
function match:VariableDeclaration(node)
   local decl = { }
   local simple = true
   for i=1, #node.names do
      -- recursively define new variables
      local queue = { node.names[i] }
      while #queue > 0 do
         local n = table.remove(queue, 1)
         if n.type == 'ArrayPattern' then
            simple = false
            for i=1, #n.elements do
               queue[#queue + 1] = n.elements[i]
            end
         elseif n.type == 'TablePattern' then
            simple = false
            for i=1, #n.entries do
               queue[#queue + 1] = n.entries[i].value
            end
         elseif n.type == 'ApplyPattern' then
            simple = false
            for i=1, #n.arguments do
               queue[#queue + 1] = n.arguments[i]
            end
         elseif n.type == 'Identifier' then
            self.ctx:define(n.name)
            decl[#decl + 1] = B.identifier(n.name)
         end
      end
   end

   if simple then
      return B.localDeclaration(decl, self:list(node.inits or { }))
   else
      node.left = node.names
      node.right = node.inits

      return B.blockStatement {
         B.localDeclaration(decl, { }),
         match.AssignmentExpression(self, node)
      }
   end
end
--[[
   a, { x = x, y = y } as Point = f()
   a, _1 = f()

   _2 = TablePattern({ x = __var__, y = __var__ }, Point)
   x = _2:__unapply(_1)

   a, Point(x, y) = f()
   a, _1 = f()
   _2 = ApplyPattern(Point, __var__, __var__)
   x, y = _2:__unapply(_1)

   a, [b, c], Point([x], y) = f()
   a, _1, _2 = f()
   b = _1[0]
   c = _1[1]
   _3, _4 = __unapply__(Point, _2)
   x = _3[0]
   y = _4

]]
local function extract_bindings(node)
   local list = { }
   local queue = { node }
   while #queue > 0 do
      local n = table.remove(queue, 1)
      if n.type == 'ArrayPattern' then
         for i=1, #n.elements do
            queue[#queue + 1] = n.elements[i]
         end
      elseif n.type == 'TablePattern' then
         for i=1, #n.entries do
            queue[#queue + 1] = n.entries[i].value
         end
      elseif n.type == 'ApplyPattern' then
         for i=1, #n.arguments do
            queue[#queue + 1] = n.arguments[i]
         end
      elseif n.type == 'Identifier' then
         list[#list + 1] = n
      elseif n.type == 'MemberExpression' then
         list[#list + 1] = n
      else
         assert(n.type == 'Literal')
      end
   end
   return list
end
function match:AssignmentExpression(node)
   local body = { }
   local decl = { }
   local init = { }
   local dest = { }
   for i=1, #node.left do
      local n = node.left[i]
      local t = n.type
      if t == 'TablePattern' or t == 'ArrayPattern' or t == 'ApplyPattern' then
         -- destructuring
         local tvar = util.genid()
         self.ctx:define(tvar)

         local temp = B.identifier(tvar)
         local left = { }
         n.temp = temp
         n.left = left

         init[#init + 1] = temp
         decl[#decl + 1] = temp
         dest[#dest + 1] = n

         -- define new variables
         local bind = extract_bindings(n)
         for i=1, #bind do
            local n = bind[i]
            if n.type == 'Identifier' then
               if not self.ctx:lookup(n.name) then
                  self.ctx:define(n.name)
                  decl[#decl + 1] = B.identifier(n.name)
               end
               left[#left + 1] = B.identifier(n.name)
            elseif n.type == 'MemberExpression' then
               left[#left + 1] = self:get(n)
            end
         end
      else
         -- simple case
         if n.type == 'Identifier' and not self.ctx:lookup(n.name) then
            self.ctx:define(n.name)
            decl[#decl + 1] = B.identifier(n.name)
         end
         init[#init + 1] = self:get(n)
      end
   end

   -- declare locals
   if #decl > 0 then
      body[#body + 1] = B.localDeclaration(decl, { })
   end

   for i=1, #dest do
      local patt = B.identifier(util.genid())
      body[#body + 1] = B.localDeclaration({ patt }, { self:get(dest[i])})
      dest[i].patt = patt
   end

   body[#body + 1] = B.assignmentExpression(init, self:list(node.right))

   -- destructure
   for i=1, #dest do
      body[#body + 1] = B.assignmentExpression(
         dest[i].left, {
            B.callExpression(
               B.identifier('__unapply__'), { dest[i].patt, dest[i].temp }
            )
         }
      )
   end

   return B.blockStatement(body)
end
function match:ArrayPattern(node)
   local list = { }
   for i=1, #node.elements do
      local n = node.elements[i]
      if n.type == 'Identifier' or n.type == 'MemberExpression' then
         list[#list + 1] = B.identifier('__var__')
      else
         list[#list + 1] = self:get(n)
      end
   end
   return B.callExpression(B.identifier('ArrayPattern'), list)
end
function match:TablePattern(node)
   local tab = { }
   local idx = 1
   for i=1, #node.entries do
      local n = node.entries[i]

      local key, val
      if n.name then
         key = n.name.name
      elseif n.expr then
         key = self:get(n.expr)
      else
         -- array part
         key = B.literal(idx)
         idx = idx + 1
      end
      local nv = n.value
      if nv.type == 'Identifier' or nv.type == 'MemberExpression' then
         tab[key] = B.identifier('__var__')
      else
         tab[key] = self:get(nv)
      end
   end
   local args = { B.table(tab) }
   if node.coerce then
      args[#args + 1] = self:get(node.coerce)
   end
   return B.callExpression(B.identifier('TablePattern'), args)
end
function match:ApplyPattern(node)
   local args = { self:get(node.callee) }
   for i=1, #node.arguments do
      local n = node.arguments[i]
      if n.type == 'Identifier' or n.type == 'MemberExpression' then
         args[#args + 1] = B.identifier('__var__')
      else
         args[#args + 1] = self:get(n)
      end
   end
   return B.callExpression(B.identifier('ApplyPattern'), args)
end
function match:UpdateExpression(node)
   local oper = string.sub(node.operator, 1, -2)
   local expr
   if oper == 'or' or oper == 'and' then
      expr = match.LogicalExpression(self, {
         operator = oper,
         left     = node.left,
         right    = node.right
      })
   else
      expr = match.BinaryExpression(self, {
         operator = oper,
         left     = node.left,
         right    = node.right
      })
   end
   return B.assignmentExpression({ self:get(node.left) }, { expr })
end
function match:MemberExpression(node)
   return B.memberExpression(
      self:get(node.object), self:get(node.property), node.computed
   )
end
function match:SelfExpression(node)
   return B.identifier('self')
end
function match:SuperExpression(node)
   return B.identifier('super')
end

function match:ThrowStatement(node)
   return B.expressionStatement(
      B.callExpression(B.identifier('throw'), { self:get(node.argument) }) 
   )
end

function match:ReturnStatement(node)
   if self.retsig then
      return B.doStatement(
         B.blockStatement{
            B.assignmentExpression(
               { self.retsig }, { B.literal(true) }
            );
            B.assignmentExpression(
               { self.retval }, self:list(node.arguments)
            );
            B.returnStatement{ self.retval }
         }
      )
   end
   return B.returnStatement(self:list(node.arguments))
end

function match:YieldStatement(node)
   return B.expressionStatement(
      B.callExpression(
         B.identifier('yield'),
         self:list(node.arguments)
      )
   )
end

function match:IfStatement(node)
   local test, cons, altn = self:get(node.test)
   if node.consequent then
      cons = self:get(node.consequent)
   end
   if node.alternate then
      altn = self:get(node.alternate)
   end
   local stmt = B.ifStatement(test, cons, altn)
   return stmt
end

function match:GivenStatement(node)
   local body = { }
   local disc = B.tempid()

   body[#body + 1] = B.localDeclaration({ disc }, { self:get(node.discriminant) })

   local cases = { }
   for i=1, #node.cases do
      local case = node.cases[i]
      local test
      local cons = self:get(case.consequent)
      if case.test then
         local t = case.test.type
         if t == 'ArrayPattern' or t == 'TablePattern' or t == 'ApplyPattern' then
            -- for storing the template
            local temp = B.tempid()
            self.ctx:define(temp.name)

            body[#body + 1] = B.localDeclaration(
               { temp }, { self:get(case.test) }
            )
            test = B.callExpression(B.identifier('__match__'), { temp, disc })

            local head = { }
            local bind = extract_bindings(case.test)
            local vars = { }
            for i=1, #bind do
               local n = bind[i]
               if n.type == 'Identifier' then
                  self.ctx:define(n.name)
                  vars[#vars + 1] = self:get(n)
               end
               bind[i] = self:get(n)
            end
            if #vars > 0 then
               head[#head + 1] = B.localDeclaration(vars, { })
            end

            head[#head + 1] = B.assignmentExpression(
               bind,
               { B.callExpression(B.identifier('__unapply__'), { temp, disc }) }
            )
            for i=1, #cons.body do
               head[#head + 1] = cons.body[i]
            end
            cons = B.blockStatement(head)
         elseif t == 'Literal' then
            test = B.binaryExpression("==", disc, self:get(case.test))
         else
            test = self:get(case.test)
         end
      else
         test = B.literal(true)
      end
      cases[#cases + 1] = B.ifStatement(test, cons)
   end

   util.fold_left(cases, function(a, b)
      a.alternate = b
      return b
   end)

   body[#body + 1] = cases[1]

   return B.doStatement(B.blockStatement(body))
end

function match:TryStatement(node)
   local oldret = self.retsig
   local oldval = self.retval

   self.retsig = B.tempid()
   self.retval = B.tempid()

   local try = B.functionExpression({ }, self:get(node.body))

   local finally
   if node.finalizer then
      finally = B.functionExpression({ }, self:get(node.finalizer))
   end

   local exit = util.genid()

   local clauses = { }
   for i=#node.guardedHandlers, 1, -1 do
      local clause = node.guardedHandlers[i]
      local cons = self:get(clause.body)
      local head = B.localDeclaration(
         { self:get(clause.param) }, { B.vararg() }
      )
      cons.body[#cons.body + 1] = B.gotoStatement(B.identifier(exit))
      clauses[#clauses + 1] = head
      clauses[#clauses + 1] = B.ifStatement(self:get(clause.guard), cons)
   end
   if node.handler then
      local clause = node.handler
      local cons = self:get(clause.body)
      local head = B.localDeclaration(
         { self:get(clause.param) }, { B.vararg() }
      )
      cons.body[#cons.body + 1] = B.gotoStatement(B.identifier(exit))
      clauses[#clauses + 1] = head
      clauses[#clauses + 1] = B.doStatement(cons)
   end
   clauses[#clauses + 1] = B.labelStatement(B.identifier(exit))

   local catch = B.functionExpression(
      { B.vararg() }, B.blockStatement(clauses)
   )

   local expr = B.callExpression(B.identifier('try'), { try, catch, finally })
   local temp = self.retval
   local rets = self.retsig

   self.retsig = oldret
   self.retval = oldval

   return B.doStatement(
      B.blockStatement{
         B.localDeclaration({ rets }, { B.literal(false) });
         B.localDeclaration({ temp }, { B.literal(nil) });
         B.expressionStatement(expr);
         B.ifStatement(
            rets, B.blockStatement{ B.returnStatement{ temp } }
         )
      }
   )
end
function match:BreakStatement(node)
   return B.breakStatement()
end
function match:ContinueStatement(node)
   return B.gotoStatement(self.loop)
end

function match:LogicalExpression(node)
   return B.logicalExpression(
      node.operator, self:get(node.left), self:get(node.right)
   )
end

local bitop = {
   [">>"]  = 'rshift',
   [">>>"] = 'arshift',
   ["<<"]  = 'lshift',
   ["|"]   = 'bor',
   ["&"]   = 'band',
   ["^"]   = 'bxor',
}
function match:BinaryExpression(node)
   local o = node.operator
   if bitop[o] then
      local call = B.memberExpression(
         B.identifier('bit'),
         B.identifier(bitop[o])
      )
      local args = { self:get(node.left), self:get(node.right) }
      return B.callExpression(call, args)
   end
   if o == 'is' then
      return B.callExpression(B.identifier('__is__'), {
         self:get(node.left), self:get(node.right)
      })
   end
   if o == 'as' then
      return B.callExpression(B.identifier('__as__'), {
         self:get(node.left), self:get(node.right)
      })
   end
   if o == '..' then
      return B.callExpression(B.identifier('__range__'), {
         self:get(node.left), self:get(node.right)
      })
   end
   if o == '**' then o = '^'  end
   if o == '~'  then o = '..' end
   if o == '!=' then o = '~=' end

   return B.binaryExpression(o, self:get(node.left), self:get(node.right))
end
function match:UnaryExpression(node)
   local o = node.operator
   local a = self:get(node.argument)
   if o == 'typeof' then
      return B.callExpression(B.identifier('__typeof__'), { a })
   elseif o == '~' then
      local call = B.memberExpression(B.identifier('bit'), B.identifier('bnot'))
      return B.callExpression(call, { a })
   end
   return B.unaryExpression(o, a)
end
function match:FunctionDeclaration(node)
   local name
   if not node.expression then
      name = self:get(node.id[1])
   end

   local params  = { }
   local prelude = { }
   local vararg  = false

   self.ctx:enter()

   for i=1, #node.params do
      local name = self:get(node.params[i])
      self.ctx:define(name.name)
      params[#params + 1] = name
      if node.defaults[i] then
         local test = B.binaryExpression("==", name, B.literal(nil))
         local expr = self:get(node.defaults[i])
         local cons = B.blockStatement{
            B.assignmentExpression({ name }, { expr })
         }
         prelude[#prelude + 1] = B.ifStatement(test, cons)
      end
   end

   if node.rest then
      params[#params + 1] = B.vararg()
      prelude[#prelude + 1] = B.localDeclaration(
         { B.identifier(node.rest.name) },
         { B.callExpression(B.identifier('Array'), { B.vararg() }) }
      )
   end

   local body = self:get(node.body)
   for i=#prelude, 1, -1 do
      table.insert(body.body, 1, prelude[i])
   end

   local func
   if node.generator then
      local inner = B.functionExpression({ }, body, vararg)
      func = B.functionExpression(params, B.blockStatement{
         B.returnStatement{
            B.callExpression(
               B.memberExpression(B.identifier("coroutine"), B.identifier("wrap")),
               { inner }
            )
         }
      }, vararg)
   else
      func = B.functionExpression(params, body, vararg)
   end

   self.ctx:leave()

   if node.expression then
      return func
   end

   local decl = B.localDeclaration({ name }, { })
   local frag = { decl }

   frag[#frag + 1] = B.assignmentExpression({ name }, { func });

   return B.blockStatement(frag)
end

function match:IncludeStatement(node)
   local args = self:list(node.names)
   table.insert(args, 1, B.identifier("self"))
   return B.expressionStatement(B.callExpression(B.identifier("include"), args))
end

function match:ModuleDeclaration(node)
   local name = self:get(node.id)

   local properties = { }
   local body = { }

   self.hoist[#self.hoist + 1] = B.localDeclaration({ name }, { })

   local outer_hoist = self.hoist
   self.hoist = { }

   for i=1, #node.body do
      if node.body[i].type == "PropertyDefinition" then
         local prop = node.body[i]
         local desc = properties[prop.key.name] or { }
         if prop.kind == 'get' then
            desc.get = self:get(prop)
         elseif prop.kind == 'set' then
            desc.set = self:get(prop)
         else
            desc.value = self:get(prop)
         end

         properties[prop.key.name] = desc

         if desc.get then
            -- self.__getters__[key] = desc.get
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(
                  B.memberExpression(B.identifier("self"), B.identifier("__getters__")),
                  B.identifier(prop.key.name)
               ) },
               { desc.get }
            )
         elseif desc.set then
            -- self.__setters__[key] = desc.set
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(
                  B.memberExpression(B.identifier("self"), B.identifier("__setters__")),
                  B.identifier(prop.key.name)
               ) },
               { desc.set }
            )
         else
            -- self.__members__[key] = desc.value
            local base
            if prop.static then
               base = B.identifier("self")
            else
               base = B.memberExpression(
                  B.identifier("self"), B.identifier("__members__")
               )
            end
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(base, B.identifier(prop.key.name)) },
               { desc.value }
            )
         end
      elseif node.body[i].type == 'ClassDeclaration' or node.body[i].type == "ModuleDeclaration" then
         body[#body + 1] = self:get(node.body[i])
         local inner_name = self:get(node.body[i].id)
         body[#body + 1] = B.assignmentExpression(
            { B.memberExpression(B.identifier("self"), inner_name) },
            { inner_name }
         )
      else
         body[#body + 1] = self:get(node.body[i])
      end
   end

   for i=#self.hoist, 1, -1 do
      table.insert(body, 1, self.hoist[i])
   end

   self.hoist = outer_hoist

   local init = B.callExpression(
      B.identifier('module'), {
         B.literal(node.id.name),
         B.functionExpression(
            { B.identifier('self') },
            B.blockStatement(body)
         )
      }
   )

   return B.assignmentExpression(
      { name }, { init }
   )
end

function match:ClassDeclaration(node)
   local name = self:get(node.id)
   local base = node.base and self:get(node.base) or B.literal(nil)

   local properties = { }
   local body = { }

   self.hoist[#self.hoist + 1] = B.localDeclaration({ name }, { })

   local outer_hoist = self.hoist
   self.hoist = { }

   for i=1, #node.body do
      if node.body[i].type == "PropertyDefinition" then
         local prop = node.body[i]
         local desc = properties[prop.key.name] or { }
         if prop.kind == 'get' then
            desc.get = self:get(prop)
         elseif prop.kind == 'set' then
            desc.set = self:get(prop)
         else
            desc.value = self:get(prop)
         end
         if desc.static then
            if desc.static.value ~= prop.static then
               error("property "..prop.key.name.." already defined as static")
            end
         end

         desc.static = B.literal(prop.static)
         properties[prop.key.name] = desc

         if desc.get then
            -- self.__getters__[key] = desc.get
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(
                  B.memberExpression(B.identifier("self"), B.identifier("__getters__")),
                  B.identifier(prop.key.name)
               ) },
               { desc.get }
            )
         elseif desc.set then
            -- self.__setters__[key] = desc.set
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(
                  B.memberExpression(B.identifier("self"), B.identifier("__setters__")),
                  B.identifier(prop.key.name)
               ) },
               { desc.set }
            )
         else
            -- self.__members__[key] = desc.value
            local base
            if prop.static then
               base = B.identifier("self")
            else
               base = B.memberExpression(
                  B.identifier("self"), B.identifier("__members__")
               )
            end
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(base, B.identifier(prop.key.name)) },
               { desc.value }
            )
         end
      elseif node.body[i].type == 'ClassDeclaration' then
         body[#body + 1] = self:get(node.body[i])
         local inner_name = self:get(node.body[i].id)
         body[#body + 1] = B.assignmentExpression(
            { B.memberExpression(B.identifier("self"), inner_name) },
            { inner_name }
         )
      else
         body[#body + 1] = self:get(node.body[i])
      end
   end

   for i=#self.hoist, 1, -1 do
      table.insert(body, 1, self.hoist[i])
   end

   self.hoist = outer_hoist

   local init = B.callExpression(
      B.identifier('class'), {
         B.literal(node.id.name), base,
         B.functionExpression(
            { B.identifier('self'), B.identifier('super') },
            B.blockStatement(body)
         )
      }
   )

   return B.assignmentExpression(
      { name }, { init }
   )
end

function match:GrammarDeclaration(node)
   local name = self:get(node.id)

   local rules = { }
   local body  = { }

   self.hoist[#self.hoist + 1] = B.localDeclaration({ name }, { })

   local outer_hoist = self.hoist
   self.hoist = { }

   local seen = false
   for i=1, #node.body do
      if node.body[i].type == "RuleDeclaration" then
         local name = node.body[i].name
         local patt = self:get(node.body[i].pattern)
         local base = B.memberExpression(
            B.identifier('self'), B.identifier('__rules__')
         )
         if not seen then
            seen = true
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(base, B.literal(1), true) },
               { B.literal(name) }
            )
         end
         body[#body + 1] = B.assignmentExpression(
            { B.memberExpression(base, B.identifier(name)) },
            { patt }
         )
      else
         body[#body + 1] = self:get(node.body[i])
      end
   end

   for i=#self.hoist, 1, -1 do
      table.insert(body, 1, self.hoist[i])
   end

   self.hoist = outer_hoist

   local init = B.callExpression(
      B.identifier('grammar'), {
         B.literal(node.id.name),
         B.functionExpression(
            { B.identifier('self') },
            B.blockStatement(body)
         )
      }
   )

   return B.assignmentExpression(
      { name }, { init }
   )
end

function match:SpreadExpression(node)
   return B.callExpression(
      B.identifier('__spread__'), { self:get(node.argument) }
   )
end
function match:NilExpression(node)
   return B.literal(nil)
end
function match:PropertyDefinition(node)
   node.value.generator = node.generator
   return self:get(node.value)
end
function match:BlockStatement(node)
   return B.blockStatement(self:list(node.body))
end
function match:ExpressionStatement(node)
   return B.expressionStatement(self:get(node.expression))
end
function match:CallExpression(node)
   local callee = node.callee
   if callee.type == 'MemberExpression' and not callee.computed then
      if callee.object.type == 'SuperExpression' then
         local args = self:list(node.arguments)
         local recv = B.memberExpression(
            B.identifier('super'),
            self:get(callee.property)
         )
         table.insert(args, 1, B.identifier('self'))
         return B.callExpression(recv, args)
      else
         if callee.namespace then
            return B.callExpression(self:get(callee), self:list(node.arguments))
         else
            local recv = self:get(callee.object)
            local prop = self:get(callee.property)
            return B.sendExpression(recv, prop, self:list(node.arguments))
         end
      end
   else
      if callee.type == 'SuperExpression' then
         local args = self:list(node.arguments)
         local recv = B.memberExpression(
            B.identifier('super'),
            B.identifier('self')
         )
         table.insert(args, 1, B.identifier('self'))
         return B.callExpression(recv, args)
      else
         local args = self:list(node.arguments)
         --table.insert(args, 1, B.literal(nil))
         return B.callExpression(self:get(callee), args)
      end
   end
end
function match:WhileStatement(node)
   local loop = B.identifier(util.genid())
   local save = self.loop
   self.loop = loop
   local body = B.blockStatement{
      self:get(node.body);
      B.labelStatement(loop);
   }
   self.loop = save
   return B.whileStatement(self:get(node.test), body)
end
function match:RepeatStatement(node)
   local loop = B.identifier(util.genid())
   local save = self.loop
   self.loop = loop
   local body = B.blockStatement{
      self:get(node.body);
      B.labelStatement(loop);
   }
   self.loop = save
   return B.repeatStatement(self:get(node.test), body)
end
function match:ForStatement(node)
   local loop = B.identifier(util.genid())
   local save = self.loop
   self.loop = loop

   local name = self:get(node.name)
   local init = self:get(node.init)
   local last = self:get(node.last)
   local step = self:get(node.step)
   local body = B.blockStatement{
      self:get(node.body);
      B.labelStatement(loop)
   }
   self.loop = save

   return B.forStatement(B.forInit(name, init), last, step, body)
end
function match:ForInStatement(node)
   local loop = B.identifier(util.genid())
   local save = self.loop
   self.loop = loop

   local none = B.tempid()
   local temp = B.tempid()
   local iter = B.callExpression(B.identifier('__each__'), { self:get(node.right) })

   local left = { }
   for i=1, #node.left do
      left[i] = self:get(node.left[i])
   end

   local body = B.blockStatement{
      self:get(node.body);
      B.labelStatement(loop);
   }
   self.loop = save

   return B.forInStatement(B.forNames(left), iter, body)
end
--[[
function match:RegExp(node)
   return B.callExpression(
      B.identifier('RegExp'), {
         B.literal(node.pattern),
         B.literal(node.flags)
      }
   )
end
--]]
function match:RangeExpression(node)
   return B.callExpression(B.identifier('__range__'), {
      self:get(node.min), self:get(node.max)
   })
end
function match:ArrayExpression(node)
   return B.callExpression(B.identifier('Array'), self:list(node.elements))
end
function match:TableExpression(node)
   local tab = { }
   for i=1, #node.entries do
      local item = node.entries[i]

      local key, val
      if item.name then
         key = item.name.name
      elseif item.expr then
         key = self:get(item.expr)
      end

      if key ~= nil then
         tab[key] = self:get(item.value)
      else
         tab[#tab + 1] = self:get(item.value)
      end
   end

   return B.table(tab)
end
function match:RawString(node)
   local list = { }
   local tostring = B.identifier('tostring')
   for i=1, #node.expressions do
      local expr = node.expressions[i]
      if type(expr) == 'string' then
         list[#list + 1] = B.literal(expr)
      else
         list[#list + 1] = B.callExpression(tostring, { self:get(expr.expression) })
      end
   end
   return B.listExpression('..', list)
end
function match:ArrayComprehension(node)
   local temp = B.tempid()
   local body = B.blockStatement{
      B.localDeclaration({ temp }, {
         B.callExpression(B.identifier('Array'), { })
      })
   }
   local last = body
   for i=1, #node.blocks do
      local loop = self:get(node.blocks[i])
      local test = node.blocks[i].filter
      if test then
         local body = loop.body
         local cond = B.ifStatement(self:get(test), body)
         loop.body = B.blockStatement{ cond }
         last.body[#last.body + 1] = loop
         last = body
      else
         last.body[#last.body + 1] = loop
         last = loop.body
      end
   end
   last.body[#last.body + 1] = B.assignmentExpression({
      B.memberExpression(temp, B.unaryExpression('#', temp), true)
   }, {
      self:get(node.body)    
   })
   body.body[#body.body + 1] = B.returnStatement{ temp }
   return B.callExpression(
      B.parenExpression{
         B.functionExpression({ }, body)
      }, { }
   )
end
function match:ComprehensionBlock(node)
   local iter = B.callExpression(
      B.identifier('__each__'), { self:get(node.right) }
   )
   local left = self:list(node.left)
   local body = { }
   return B.forInStatement(B.forNames(left), iter, B.blockStatement(body))
end

function match:RegExp(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('P')),
      { self:get(node.pattern) }
   )
end
function match:PatternAlternate(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('__add')),
      { self:get(node.left), self:get(node.right) }
   )
end
function match:PatternSequence(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('__mul')),
      { self:get(node.left), self:get(node.right) }
   )
end
function match:PatternAny(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('P')),
      { B.literal(1) }
   )
end
function match:PatternAssert(node)
   local call
   if node.operator == '&' then
      call = '__len'
   else
      call = '__unm'
   end
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier(call)),
      { self:get(node.argument) }
   )
end
function match:PatternProduction(node)
   local oper, call = node.operator
   if oper == '~>' then
      call = 'Cf'
   elseif oper == '+>' then
      call = 'Cmt'
   else
      assert(oper == '->')
      call = '__div'
   end
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier(call)),
      { self:get(node.left), self:get(node.right) }
   )
end
function match:PatternRepeat(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('__pow')),
      { self:get(node.left), B.literal(node.count) }
   )
end

function match:PatternCaptSubst(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('Cs')),
      { self:get(node.pattern) }
   )
end
function match:PatternCaptTable(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('Ct')),
      { self:get(node.pattern) }
   )
end
function match:PatternCaptConst(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('Cc')),
      { self:get(node.pattern) }
   )
end
function match:PatternCaptGroup(node)
   local args = { self:get(node.pattern) }
   if node.name then
      args[#args + 1] = B.literal(node.name)
   end
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('Cg')),
      args
   )
end
function match:PatternCaptBack(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('Cb')),
      { B.literal(node.name) }
   )
end
function match:PatternReference(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('V')),
      { B.literal(node.name) }
   )
end
function match:PatternClass(node)
   local expr = self:get(node.alternates)
   if node.negated then
      local any = B.callExpression(
         B.memberExpression(B.identifier('rule'), B.identifier('P')),
         { B.literal(1) }
      )
      expr = B.callExpression(
         B.memberExpression(B.identifier('rule'), B.identifier('__sub')),
         { any, expr }
      )
   end
   return expr
end
function match:PatternRange(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('R')),
      { B.literal(node.left), B.literal(node.right) }
   )
end
function match:PatternTerm(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('P')),
      { B.literal(node.literal) }
   )
end
function match:PatternPredef(node)
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('Def')),
      { B.literal(node.name) }
   )
end
function match:PatternArgument(node)
   local narg = string.match(node.name, '^(%d+)$')
   return B.callExpression(
      B.memberExpression(B.identifier('rule'), B.identifier('Carg')),
      { tonumber(narg) }
   )
end

local function countln(src, pos, idx)
   local line = 0
   local index, limit = idx or 1, pos
   while index <= limit do
      local s, e = string.find(src, "\n", index, true)
      if s == nil or e > limit then
         break
      end
      index = e + 1
      line  = line + 1
   end
   return line 
end

local function transform(tree, src)
   local self = { }
   self.line = 1
   self.pos  = 0

   self.ctx = Context.new()

   function self:sync(node)
      local pos = node.pos
      if pos ~= nil and pos > self.pos then
         local prev = self.pos
         local line = countln(src, pos, prev + 1) + self.line
         self.line = line
         self.pos = pos
      end
   end

   function self:get(node, ...)
      if not match[node.type] then
         error("no handler for "..tostring(node.type))
      end
      self:sync(node)
      local line = self.line
      local out = match[node.type](self, node, ...)
      if out then out.line = line end
      return out
   end

   function self:list(nodes, ...)
      local list = { }
      for i=1, #nodes do
         list[#list + 1] = self:get(nodes[i], ...)
      end
      return list
   end

   return self:get(tree)
end

return {
   transform = transform
}
