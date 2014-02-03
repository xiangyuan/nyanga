--[=[
Copyright (C) 2013-2014 Richard Hundt and contributors.
See Copyright Notice in nyanga
]=]

local defs = { }
local util = require('nyanga.util')

defs.tonumber = function(s)
   local n = string.gsub(s, '_', '')
   return tonumber(n)
end
defs.tostring = tostring

function defs.octal(s)
   return tostring(tonumber(s, 8))
end
function defs.quote(s)
   return string.format("%q", s)
end
local escape_lookup = {
   ["a"] = "\a",
   ["b"] = "\b",
   ["f"] = "\f",
   ["n"] = "\n",
   ["r"] = "\r",
   ["t"] = "\t",
   ["v"] = "\v",
   ["0"] = "\0",
   ['"'] = '"',
   ["'"] = "'",
   ["\\"]= "\\"
}
function defs.escape(s)
   local t = string.sub(s, 2)
   local n = tonumber(t)
   if n then return string.char(n) end
   if escape_lookup[t] then return escape_lookup[t] end
   error("invalid escape sequence")
end
function defs.chunk(body)
   return { type = "Chunk", body = body }
end
function defs.stmt(pos, node)
   node.pos = pos
   return node
end
function defs.term(pos, node)
   node.pos = pos
   if node.type == 'Identifier' then
      node.check = true
   end
   return node
end
function defs.expr(pos, node)
   node.pos = pos
   return node
end

function defs.includeStmt(names)
   return { type = "IncludeStatement", names = names }
end
function defs.moduleDecl(name, body)
   return { type = "ModuleDeclaration", id = name, body = body }
end

function defs.exportStmt(names)
   return { type = "ExportStatement", names = names }
end
function defs.rawString(exprs)
   return { type = "RawString", expressions = exprs }
end
function defs.rawExpr(expr)
   return { type = "RawExpression", expression = expr }
end
function defs.importStmt(names, from, ...)
   return { type = "ImportStatement", names = names, from = from }
end
function defs.error(src, pos, name)
   local loc = string.sub(src, pos, pos)
   if loc == '' then
      error("Unexpected end of input", 2)
   else
      local tok = string.match(src, '%s*(%S+)', pos) or loc
      local line = 0
      local ofs  = 0
      while ofs < pos do
         local a, b = string.find(src, "\n", ofs)
         if a then
            ofs = a + 1
            line = line + 1
         else
            break
         end
      end
      error("Unexpected token '"..tok.."' on line "..tostring(line).." "..tostring(name or '?'), 2)
   end
end
function defs.fail(src, pos, msg)
   local loc = string.sub(src, pos, pos)
   if loc == '' then
      error("Unexpected end of input")
   else
      local tok = string.match(src, '(%w+)', pos) or loc
      error(msg.." near '"..tok.."'")
   end
end
function defs.literal(val)
   return { type = "Literal", value = val }
end
function defs.literalNumber(s)
   return { type = "Literal", value = tonumber(s) }
end
function defs.boolean(val)
   return val == 'true'
end
function defs.nilExpr()
   return { type = "Literal", value = nil }
end
function defs.identifier(name)
   return { type = "Identifier", name = name }
end
function defs.compExpr(body, blocks)
   return { type = "ArrayComprehension", blocks = blocks, body = body }
end
function defs.compBlock(lhs, rhs, filter)
   return { type = "ComprehensionBlock", left = lhs, right = rhs, filter = filter }
end
function defs.arrayExpr(elements)
   return { type = "ArrayExpression", elements = elements }
end

function defs.arrayPatt(elements)
   return { type = "ArrayPattern", elements = elements }
end
function defs.tablePatt(entries, coerce)
   return { type = "TablePattern", entries = entries, coerce = coerce }
end
function defs.applyPatt(expr)
   local base = expr[1]
   for i=2, #expr do
      if expr[i][1] == "(" then
         base = defs.callExpr(base, expr[i][2])
      else
         base = defs.memberExpr(base, expr[i][2], expr[i][1] == "[")
         base.namespace = expr[i][1] == "::"
      end
   end
   base.type = 'ApplyPattern'
   return base
end

function defs.tableEntry(item)
   return item
end

function defs.tableExpr(entries)
   return { type = "TableExpression", entries = entries }
end
--[[
function defs.regexExpr(expr, flags)
   local rx = require('pcre')
   expr = string.gsub(expr, "(\\[rnt\\])", defs.escape)
   assert(rx.compile(expr))
   return { type = "RegExp", pattern = expr, flags = flags }
end
--]]
function defs.ifStmt(test, cons, altn)
   if cons.type ~= "BlockStatement" then
      cons = defs.blockStmt{ cons }
   end
   if altn and altn.type ~= "BlockStatement" then
      altn = defs.blockStmt{ altn }
   end
   return { type = "IfStatement", test = test, consequent = cons, alternate = altn }
end
function defs.whileStmt(test, body)
   return { type = "WhileStatement", test = test, body = body }
end
function defs.repeatStmt(body, test)
   return { type = "RepeatStatement", test = test, body = body }
end
function defs.forStmt(name, init, last, step, body)
   return {
      type = "ForStatement",
      name = name, init = init, last = last, step = step,
      body = body
   }
end
function defs.forInStmt(left, right, body)
   return { type = "ForInStatement", left = left, right = right, body = body }
end
function defs.spreadExpr(arg)
   return { type = "SpreadExpression", argument = arg }
end
function defs.funcDecl(path, head, body)
   if body.type ~= "BlockStatement" then
      body = defs.blockStmt{ defs.returnStmt{ body } }
   end

   local name, oper
   if path then
      if #path == 1 then
         name = path[1]
      else
         name = util.fold_left(path, function(a, b)
            if type(b) == 'string' then
               oper = b
               return a
            else
               return defs.memberExpr(a, b)
            end
         end)
      end
   end

   local decl = { type = "FunctionDeclaration", name = name, body = body }
   local defaults, params, rest = { }, { }, nil
   if oper == '.' then
      params[#params + 1] = defs.identifier('self')
   end
   for i=1, #head do
      local p = head[i]
      if p.rest then
         rest = p.name
      else
         params[#params + 1] = p.name
         if p.default then
            defaults[i] = p.default
         end
      end 
   end

   decl.params   = params
   decl.defaults = defaults
   decl.rest     = rest

   return decl
end
function defs.funcExpr(head, body)
   local decl = defs.funcDecl(nil, head, body)
   decl.expression = true
   return decl
end
function defs.coroExpr(...)
   local expr = defs.funcExpr(...)
   expr.generator = true
   return expr
end
function defs.coroDecl(...)
   local decl = defs.funcDecl(...)
   decl.generator = true
   return decl
end
function defs.coroProp(...)
   local prop = defs.propDefn(...)
   prop.generator = true
   return prop
end
function defs.blockStmt(body)
   return {
      type = "BlockStatement",
      body = body
   }
end
function defs.givenStmt(disc, cases, default)
   if default then
      cases[#cases + 1] = defs.givenCase(nil, default)
   end
   return { type = "GivenStatement", discriminant = disc, cases = cases }
end
function defs.givenCase(test, cons)
   return { type = "GivenCase", test = test, consequent = cons }
end

function defs.returnStmt(args)
   return { type = "ReturnStatement", arguments = args }
end
function defs.yieldStmt(args)
   return { type = "YieldStatement", arguments = args }
end
function defs.breakStmt()
   return { type = "BreakStatement" }
end
function defs.continueStmt()
   return { type = "ContinueStatement" }
end
function defs.throwStmt(expr)
   return { type = "ThrowStatement", argument = expr }
end
function defs.tryStmt(body, handlers, finalizer)
   local guarded = { }
   local handler
   for i=1, #handlers do
      if handlers[i].guard then
         guarded[#guarded + 1] = handlers[i]
      else
         assert(i == #handlers, "catch all handler must be last")
         handler = handlers[i]
      end
   end
   return {
      type = "TryStatement",
      body = body,
      handler = handler,
      guardedHandlers = guarded,
      finalizer = finalizer
   }
end
function defs.catchClause(param, guard, body)
   if not body then body, guard = guard, nil end
   return { type = "CatchClause", param = param, guard = guard, body = body }
end

function defs.classDecl(name, base, body)
   if #base == 0 and not base.type then
      base = nil
   end
   return { type = "ClassDeclaration", id = name, base = base, body = body }
end
function defs.classBody(body)
   return { type = "ClassBody", body = body }
end
function defs.classMember(s, m)
   m.static = s == "static"
   if not m.static then
      table.insert(m.value.params, 1, defs.identifier("self"))
   end
   return m
end
function defs.propDefn(k, n, h, b)
   local func = defs.funcExpr(h, b)
   for i=#func.defaults, 1, -1 do
      func.defaults[i + 1] = func.defaults[i]
   end
   func.defaults[1] = nil
   return { type = "PropertyDefinition", kind = k, key = n, value = func }
end
function defs.exprStmt(pos, expr)
   return { type = "ExpressionStatement", expression = expr, pos = pos }
end
function defs.selfExpr()
   return { type = "SelfExpression" }
end
function defs.superExpr()
   return { type = "SuperExpression" }
end
function defs.prefixExpr(o, a)
   return { type = "UnaryExpression", operator = o, argument = a }
end
function defs.postfixExpr(expr)
   local base = expr[1]
   for i=2, #expr do
      if expr[i][1] == "(" then
         base = defs.callExpr(base, expr[i][2])
      else
         base = defs.memberExpr(base, expr[i][2], expr[i][1] == "[")
         base.namespace = expr[i][1] == "::"
      end
   end
   return base
end
function defs.memberExpr(b, e, c)
   return { type = "MemberExpression", object = b, property = e, computed = c }
end
function defs.callExpr(expr, args)
   return { type = "CallExpression", callee = expr, arguments = args } 
end
function defs.newExpr(expr, args)
   return { type = "NewExpression", callee = expr, arguments = args } 
end

function defs.binaryExpr(op, lhs, rhs)
   return { type = "BinaryExpression", operator = op, left = lhs, right = rhs }
end
function defs.logicalExpr(op, lhs, rhs)
   return { type = "LogicalExpression", operator = op, left = lhs, right = rhs }
end
function defs.assignExpr(lhs, rhs)
   return { type = "AssignmentExpression", left = lhs, right = rhs }
end
function defs.updateExpr(left, op, right)
   return { type = "UpdateExpression", left = left, operator = op, right = right }
end
function defs.localDecl(lhs, rhs)
   return { type = "VariableDeclaration", names = lhs, inits = rhs }
end
function defs.doStmt(block)
   return { type = "DoStatement", body = block }
end

local op_info = {
   ["or"]  = { 1, 'L' },
   ["and"] = { 2, 'L' },

   ["|"]   = { 4, 'L' },
   ["^"]   = { 5, 'L' },
   ["&"]   = { 6, 'L' },

   ["=="]  = { 7, 'L' },
   ["!="]  = { 7, 'L' },

   ["is"]  = { 8, 'L' },
   ["as"]  = { 8, 'L' },
   ["in"]  = { 9, 'L' },

   [">="]  = { 10, 'L' },
   ["<="]  = { 10, 'L' },
   [">"]   = { 10, 'L' },
   ["<"]   = { 10, 'L' },

   ["<<"]  = { 11, 'L' },
   [">>"]  = { 11, 'L' },
   [">>>"] = { 11, 'L' },

   ["+"]   = { 12, 'L' },
   ["-"]   = { 12, 'L' },
   [".."]  = { 12, 'R' },

   ["*"]   = { 13, 'L' },
   ["/"]   = { 13, 'L' },
   ["%"]   = { 13, 'L' },

   ["~_"]  = { 14, 'R' },
   ["-_"]  = { 14, 'R' },
   ["+_"]  = { 14, 'R' },
   ["!_"]  = { 14, 'R' },

   ["not_"]    = { 14, 'R' },
   ["typeof_"] = { 14, 'R' },

   ["**"]  = { 15, 'R' },
   ["#_"]  = { 16, 'R' },
}

local patt_op_info = {
   ["~>"]  = { 1, 'L' },
   ["->"]  = { 1, 'L' },
   ["+>"]  = { 1, 'L' },

   ["|"]   = { 2, 'L' },

   ["&_"]  = { 3, 'R' },
   ["!_"]  = { 3, 'R' },

   ["+"]   = { 3, 'L' },
   ["*"]   = { 3, 'L' },
   ["?"]   = { 3, 'L' },

   ["^+"]  = { 4, 'R' },
   ["^-"]  = { 4, 'R' },
}

local shift = table.remove

local function debug(t)
   return (string.gsub(util.dump(t), "%s+", " "))
end

local function fold_expr(exp, min)
   local lhs = shift(exp, 1)
   if type(lhs) == 'table' and lhs.type == 'UnaryExpression' then
      local op   = lhs.operator..'_'
      local info = op_info[op]
      table.insert(exp, 1, lhs.argument)
      lhs.argument = fold_expr(exp, info[1])
   end
   while op_info[exp[1]] ~= nil and op_info[exp[1]][1] >= min do
      local op = shift(exp, 1)
      local info = op_info[op]
      local prec, assoc = info[1], info[2]
      if assoc == 'L' then
         prec = prec + 1
      end
      local rhs = fold_expr(exp, prec)
      if op == "or" or op == "and" then
         lhs = defs.logicalExpr(op, lhs, rhs)
      else
         lhs = defs.binaryExpr(op, lhs, rhs)
      end
   end
   return lhs
end

function defs.infixExpr(exp)
   return fold_expr(exp, 0)
end

function defs.regexExpr(expr)
   return { type = "RegExp", pattern = expr }
end

function defs.grammarDecl(name, body)
   return { type = "GrammarDeclaration", id = name, body = body }
end
function defs.pattGrammar(rules)
   return { type = "PatternGrammar", rules = rules }
end

function defs.pattExpr(pass)
   return pass -- for now
end

function defs.pattAlt(list)
   return util.fold_left(list, function(a, b)
      return { type = "PatternAlternate", left = a, right = b }
   end)
end
function defs.pattSeq(list)
   return util.fold_left(list, function(a, b)
      return { type = "PatternSequence", left = a, right = b }
   end)
end
function defs.pattAny()
   return { type = "PatternAny" }
end
function defs.pattAssert(oper, term)
   return { type = "PatternAssert", operator = oper, argument = term }
end

function defs.pattSuffix(term, tail)
   if #tail == 0 then
      return term
   end
   local left = term
   for i=1, #tail do
      tail[i].left = left
      left = tail[i]
   end
   return left
end
function defs.pattProd(oper, expr)
   return { type = "PatternProduction", operator = oper, right = expr }
end
function defs.pattOpt(oper)
   local count
   if oper == '?' then
      count = -1
   elseif oper == '*' then
      count = 0
   else assert(oper == '+')
      count = 1
   end
   return { type = "PatternRepeat", count = count }
end
function defs.pattRep(count)
   return { type = "PatternRepeat", count = tonumber(count) }
end

function defs.pattCaptSubst(expr)
   return { type = "PatternCaptSubst", pattern = expr }
end
function defs.pattCaptTable(expr)
   return { type = "PatternCaptTable", pattern = expr or defs.literal("") }
end
function defs.pattCaptBasic(expr)
   return { type = "PatternCaptBasic", pattern = expr }
end
function defs.pattCaptConst(expr)
   return { type = "PatternCaptConst", argument = expr }
end
function defs.pattCaptGroup(name, expr)
   return { type = "PatternCaptGroup", name = name, pattern = expr }
end
function defs.pattCaptBack(name)
   return { type = "PatternCaptBack", name = name }
end
function defs.pattRef(name)
   return { type = "PatternReference", name = name }
end
function defs.pattClass(prefix, items)
   local expr = util.fold_left(items, function(a, b)
      return { type = "PatternAlternate", left = a, right = b }
   end)
   return { type = "PatternClass", negated = prefix == '^', alternates = expr }
end
function defs.pattRange(left, right)
   return { type = "PatternRange", left = left, right = right }
end
function defs.pattName(name)
   return name
end
function defs.pattTerm(literal)
   return { type = "PatternTerm", literal = literal }
end
function defs.pattPredef(name)
   return { type = "PatternPredef", name = name }
end
function defs.pattArg(index)
   return { type = "PatternArgument", index = index }
end


return defs
