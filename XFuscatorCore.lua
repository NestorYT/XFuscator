require 'LuaMinify.ParseLua'
require 'LuaMinify.FormatMini'
require 'LAT'

local function obfuscate(code, level, mxLevel, useLoadstring, makeFluff, randomComments, step2, useUglifier, encryptConstants)
    if useLoadstring == nil then useLoadstring = true end
    level = level or 1
    mxLevel = mxLevel or 2
    if makeFluff == nil then makeFluff = true end
    if randomComments == nil then randomComments = true end
    if step2 == nil then step2 = true end
    if useUglifier == nil then useUglifier = false end
    if encryptConstants == nil then encryptConstants = false end
    
    local concat = function(...) return table.concat({...}, "") end
    local function dumpString(x) 
        --return concat("\"", x:gsub(".", function(d) return "\\" .. string.byte(d) end), "\"") 
        return x:gsub(".", function(d) 
            return "\\" .. d:byte()
            --[[local b = string.byte(d)
            if b < 32 or b > 126 then
                return "\\" .. string.byte(d) 
            else
                return d
            end
            
            local v = ""
            local ch = string.byte(d)
            -- other chars with values > 31 are '"' (34), '\' (92) and > 126
            if ch < 32 or ch == 34 or ch == 92 or ch > 126 then
                if ch >= 7 and ch <= 13 then
                    ch = string.sub("abtnvfr", ch - 6, ch - 6)
                elseif ch == 34 or ch == 92 then
                    ch = string.char(ch)
                end
                v = v .. "\\" .. ch
            else-- 32 <= v <= 126 (NOT 255)
                v = v .. string.char(ch)
            end
            return v
            ]]
        end)
    end
    local function GenerateSomeFluff()
        if makeFluff == false then return "" end
        
        local randomTable = { "N00BING N00B TABLE", "game.Workspace:ClearAllChildren()", "?????????", "game", "Workspace", "wait", "loadstring", "Lighting", "TeleportService", "error", "crash__", "_", "____", "\\\"FOOLED YA?!?!\\\"", "\\\"MWAHAHA H4X0RZ\\\"", "string", "table", "\\\"KR3D17 70 XFU5K470R\\\"", "string", "os", "tick", "\"system\"" }
        --for i = 1, 100 do print(math.random(1, #randomTable)) end
        local x = math.random(1, #randomTable)
        if x > (#randomTable / 2) then
            local randomName = randomTable[x]
            return concat("local ", string.rep("_", math.random(5, 10)), " = ", "____[#____ - 9](", "'" .. dumpString("loadstring(\"return " .. randomName .. "\")()") .. "'", ")\n")
        elseif x > 3 then
            return concat("local ", string.rep("_", math.random(5, 10)), " = ____[", math.random(1, 31), "]\n")
        else -- x == 3, 2, or 1
            return concat("local ", ("_"):rep(100), " = ", '"' .. dumpString("XFU5K470R R00LZ") .. '"', "\n")
        end
    end
    local function GenerateFluff() 
        --local x = { } for i = 1, math.random(2, 10) do table.insert(x, GenerateSomeFluff()) end return table.concat(x) 
        if makeFluff then
            return GenerateSomeFluff()
        else
            return ""
        end
    end
    math.randomseed(os and os.time() or tick())
    
    print("Inital parsing ...")
    local str = ""
    local success,tok = LexLua(code)
    if not success then
        error("Failed to parse code: " .. tok)
    end
    local ast
    success, ast = ParseLua(tok)
    if not success then
        error("Failed to parse code: " .. ast)
    end
    
    print("Extracting constants ...")
    local CONSTANT_POOL_NAME
    base = 'CONSTANT_POOl'
    local chars = "QWERTYUIOPASDFGHJKLZXCVBNMqwertyuioplkjhgfdsazxcvbnm_1234567890"
    while code:find(base, 1, true) do
        local n = math.random(1, #chars)
        base = base .. chars:sub(n, n)
    end
    CONSTANT_POOL_NAME = base
    
    -- Rip constant strings out
    local function makeNode(index)
        return { 
            AstType = 'IndexExpr',
            ParentCount = 1,
            Base = { AstType = 'VarExpr', Name = CONSTANT_POOL_NAME },
            Index = { AstType = 'NumberExpr', Value = { Data = index } }
        } -- Ast Node
    end
    
    table.insert(ast.Body, 1, { 
        AstType = 'LocalStatement', 
        Scope = ast.Scope,
        LocalList = { 
            --ast.Scope:CreateLocal('CONSTANT_POOL'),
            { Scope = ast.Scope, Name = CONSTANT_POOL_NAME, CanRename = true },
        }, 
        InitList = { 
            { EntryList = { }, AstType = 'ConstructorExpr' },
        },
    })
    local constantPoolAstNode = ast.Body[1].InitList[1]
    
    local CONSTANT_POOL = { }
    local nilIndex
    local index = 1
    local function insertConstant(v, index, type)
        table.insert(constantPoolAstNode.EntryList, { 
            Type = 'Key', 
            Value = { AstType = type or 'StringExpr', Value = v }, 
            Key = { AstType = 'NumberExpr', Value = { Data = tostring(index) } }
        })
    end
    
    local function addConstant(const)
        if CONSTANT_POOL[const] then return CONSTANT_POOL[const] end
        if const == nil and nilIndex then return nilIndex end
        
        if type(const) == 'string' then
            insertConstant({ Data = '"' .. dumpString(const) .. '"', Constant = const }, index, 'StringExpr')
            CONSTANT_POOL[const] = index
            index = index + 1
            return CONSTANT_POOL[const]
        elseif type(const) == 'number' then
            insertConstant({ Data = const }, index, 'NumberExpr')
            CONSTANT_POOL[const] = index
            index = index + 1
            return CONSTANT_POOL[const]
        elseif type(const) == 'nil' then
            insertConstant(const, index, 'NilExpr')
            nilIndex = index
            index = index + 1
            return nilIndex
        elseif type(const) == 'boolean' then
            insertConstant(const, index, 'BooleanExpr')
            CONSTANT_POOL[const] = index
            index = index + 1
            return CONSTANT_POOL[const]
        elseif const.AstType == 'VarExpr' then
            table.insert(constantPoolAstNode.EntryList, { 
                Type = 'Key', 
                Value = const,
                Key = { AstType = 'NumberExpr', Value = { Data = tostring(index) } }
            })
            CONSTANT_POOL[const] = index
            index = index + 1
            return CONSTANT_POOL[const]
        else 
            error("Unable to process constant of type '" .. const .. "'")
        end
    end
    
    local fixExpr, fixStatList
    
    fixExpr = function(expr)
		if expr.AstType == 'VarExpr' then
            if expr.Local then
                return expr
            else
                --local i = addConstant(expr)
                --return makeNode(i)
            end
		elseif expr.AstType == 'NumberExpr' then
			local i = addConstant(tonumber(expr.Value.Data))
            return makeNode(i)
		elseif expr.AstType == 'StringExpr' then
			local i = addConstant(expr.Value.Constant)
            return makeNode(i)
		elseif expr.AstType == 'BooleanExpr' then
			local i = addConstant(expr.Value)
            return makeNode(i)
		elseif expr.AstType == 'NilExpr' then
			local i = addConstant(nil)
            return makeNode(i)
		elseif expr.AstType == 'BinopExpr' then
			expr.Lhs = fixExpr(expr.Lhs)
			expr.Rhs = fixExpr(expr.Rhs)
		elseif expr.AstType == 'UnopExpr' then
			expr.Rhs = fixExpr(expr.Rhs)
		elseif expr.AstType == 'DotsExpr' then
		elseif expr.AstType == 'CallExpr' then
			expr.Base = fixExpr(expr.Base)
			for i = 1, #expr.Arguments do
				expr.Arguments[i] = fixExpr(expr.Arguments[i])
			end
		elseif expr.AstType == 'TableCallExpr' then
			expr.Base = fixExpr(expr.Base)
			expr.Arguments[1] = fixExpr(expr.Arguments[1])
		elseif expr.AstType == 'StringCallExpr' then
            expr.Base = fixExpr(expr.Base)
            expr.Arguments[1] = fixExpr(expr.Arguments[1])
		elseif expr.AstType == 'IndexExpr' then
			expr.Base = fixExpr(expr.Base)
            expr.Index = fixExpr(expr.Index)
		elseif expr.AstType == 'MemberExpr' then
			expr.Base = fixExpr(expr.Base)
		elseif expr.AstType == 'Function' then
			fixStatList(expr.Body)
		elseif expr.AstType == 'ConstructorExpr' then
			for i = 1, #expr.EntryList do
				local entry = expr.EntryList[i]
				if entry.Type == 'Key' then
					entry.Key = fixExpr(entry.Key)
                    entry.Value = fixExpr(entry.Value)
				elseif entry.Type == 'Value' then
					entry.Value = fixExpr(entry.Value)
				elseif entry.Type == 'KeyString' then
					entry.Value = fixExpr(entry.Value)
				end
			end
		end
		return expr
	end

	local fixStmt = function(statement)
		if statement.AstType == 'AssignmentStatement' then
			for i = 1, #statement.Lhs do
				statement.Lhs[i] = fixExpr(statement.Lhs[i])
			end
            for i = 1, #statement.Rhs do
                statement.Rhs[i] = fixExpr(statement.Rhs[i])
            end
		elseif statement.AstType == 'CallStatement' then
			statement.Expression = fixExpr(statement.Expression)
		elseif statement.AstType == 'LocalStatement' then
            for i = 1, #statement.InitList do
                statement.InitList[i] = fixExpr(statement.InitList[i])
            end
		elseif statement.AstType == 'IfStatement' then
			statement.Clauses[1].Condition = fixExpr(statement.Clauses[1].Condition)
			fixStatList(statement.Clauses[1].Body)
			for i = 2, #statement.Clauses do
				local st = statement.Clauses[i]
				if st.Condition then
					st.Condition = fixExpr(st.Condition)
                end
				fixStatList(st.Body)
			end
		elseif statement.AstType == 'WhileStatement' then
			statement.Condition = fixExpr(statement.Condition)
			fixStatList(statement.Body)
		elseif statement.AstType == 'DoStatement' then
			fixStatList(statement.Body)
		elseif statement.AstType == 'ReturnStatement' then
			for i = 1, #statement.Arguments do
				statement.Arguments[i] = fixExpr(statement.Arguments[i])
			end
		elseif statement.AstType == 'BreakStatement' then
		elseif statement.AstType == 'RepeatStatement' then
			fixStatList(statement.Body)
			statement.Condition = fixExpr(statement.Condition)
		elseif statement.AstType == 'Function' then
			if statement.IsLocal then
			else
				statement.Name = fixExpr(statement.Name)
			end
			fixStatList(statement.Body)
		elseif statement.AstType == 'GenericForStatement' then
			for i = 1, #statement.Generators do
				statement.Generators[i] = fixExpr(statement.Generators[i])
			end
			fixStatList(statement.Body)
		elseif statement.AstType == 'NumericForStatement' then
			statement.Start = fixExpr(statement.Start)
            statement.End = fixExpr(statement.End)
			if statement.Step then
				statement.Step = fixExpr(statement.Step)
			end
			fixStatList(statement.Body)
        elseif statement.AstType == 'LabelStatement' then
        elseif statement.AstType == 'GotoStatement' then
        else
            print("Unknown AST Type: " .. statement.AstType)
		end
	end

	fixStatList = function(statList)
		for _, stat in pairs(statList.Body) do
			fixStmt(stat)
		end
	end
    fixStatList(ast)
    
    addConstant("\88\70\85\53\75\52\55\48\82\32\49\53\32\52\87\51\53\48\77\51\46\32\75\82\51\68\49\55\32\55\48\32\88\70\85\53\75\52\55\48\82\33", index)
    
    if encryptConstants then
        print("Encrypting constants ...")
        local bit = bit or bit32 or require'bit'
        local xor = bit.bxor or bit.xor
        local password = math.random(1, 100)
        local _, node = ParseLua([[local decrypt = function(c)
    local bit = bit or bit32 or require'bit'
    return bit.bxor(]] .. tostring(password) .. [[, c)
end
]])
        table.insert(ast.Body, 1, node.Body[1])
        for k, v in pairs(constantPoolAstNode.EntryList) do
            if v.Value then
                if v.Value.AstType == 'StringExpr' then
                    local str = v.Value.Value.Constant
                    local t = { }
                    for i = 1, str:len() do
                        t[#t + 1] = xor(str:sub(i, i):byte(), password)
                    end
                    
                    local newNode = "local _ = table.concat { "
                    for k, v in pairs(t) do
                        newNode = newNode .. "string.char(decrypt(" .. v .. ")), "
                    end
                    newNode = newNode .. " }"
                    local _, node = ParseLua(newNode)
                    if not _ then error(node) end
                    constantPoolAstNode.EntryList[k].Value = node.Body[1].InitList[1]
                end
            end
        end
    end
    
    local a = Format_Mini(ast)
    if useUglifier then
        print("Uglifying ...")
        local keywords = { "and", "break", "do", "else", "elseif",
        "end", "false", "for", "function", "if",
            "in", "local", "nil", "not", "or", "repeat",
                "return", "then", "true", "until", "while" }
        
        -- make code SMALL
        local wordMap = {
            
        }
        
        local base_char = 128
        while base_char + #wordMap <= 255 and code:find("["..string.char(base_char).."-"..string.char(base_char+#wordMap-1).."]") do
            base_char = base_char + 1
        end
        
        for _, w in pairs(keywords) do
            wordMap[w] = base_char
            base_char = base_char + 1
        end
        for w in a:gmatch("([%a_][%w_]+)") do
            wordMap[w] = base_char
            base_char = base_char + 1
        end
        if base_char <= 255 then 
            for k, v in pairs(wordMap) do
                a:gsub(k, string.char(v))
                --print(k, v)
            end
            
            local tmp = "local wordMap = { "
            for k, v in pairs(wordMap) do
                tmp = tmp .. '["' .. dumpString(k) .. '"] = ' .. v .. ", "
            end
            tmp = tmp .. [[ }
        local code -- assigned later
        local function patch()
            for k, v in pairs(wordMap) do
                code = code:gsub(string.char(v), k)
            end
        end
        code = "]] .. dumpString(a) .. [["
        patch()
        loadstring(code)()]]
            
            a = tmp
            
        end
    end
    
    success, ast = ParseLua(a)
    if not success then
        -- If it got this far, and then fails, there is a problem with XFuscator
        error("Failed to parse code: " .. ast)
    end
    
    a = Format_Mini(ast) -- Extra security (renames code from 'tmp' and CONSTANT_POOL, and constant encryption)
    
    if useLoadstring then
        print("Precompiling ...")
        a, b = loadstring(a)
        if not a then
            error("Failed to precompile code: " .. b)
        end
        a = string.dump(a)
        local file
        
        local function makeRandomName()
            local id = ""
            for i = 1, math.random(0, 20) do
                id = id .. string.char(math.random(0, 255))
            end
            return id
        end
            
        if a:sub(1, 5) == '\27LuaQ' then -- Renames locals to completely unrepresentable strings. MWAHAHA!!
            file = LAT.Lua51.Disassemble(a)
        elseif a:sub(1, 5) == '\27LuaR' then
            file = LAT.Lua52.Disassemble(a)
        end
        
        local function doFunc(f)
            for i = 0, f.Locals.Count - 1 do
                local lcl = f.Locals[i]
                lcl.Name = "<local$" .. tostring(i) .. ">_" .. makeRandomName()
                lcl.Name = tostring(i) .. makeRandomName()
            end
        end
        
        if file then
            print("  - Renaming locals in precompiled chunk to utter nonsense ...")
            doFunc(file.Main)
            
            a = file:Compile(false) -- Don't verify chunk
        end
    end
    local a2 = a
    if step2 == true then
        print("Step 2 ...")
        -- Convert to char/table/loadstring thing
        math.randomseed(os and os.time() or tick())
        local __X = math.random()
        a2 = [[ math.randomseed(]] .. __X .. [[)
    local ____
    ____ = { function(...) local t = { ...} return ____[8](t) end, print, game, math.frexp, math.random(1, 1100), string.dump, string.sub, table.concat, wait, tick, loadstring, "t", function(x) local x2 = loadstring(x) if x2 then return ____[tonumber("\50\48")](function() x2() end) else return nil end end, "InsertService", 1234567890, getfenv, "", "wai", 7.2, pcall, math.pi, "" }
    ]] .. GenerateFluff() .. [[local ___ = ____[5]
    ]] .. GenerateFluff() .. [[local _ = function(x) return string.char(x / ___) end
    ]] .. GenerateFluff() .. [[local __ = {]]
        math.randomseed(__X)
        local ___X = math.random(1, 1100)
        local a3 = { }
        for i = 1, a:len() do
            table.insert(a3, concat("_(", (string.byte(a:sub(i, i)) * ___X), "), "))
        end
        a2 = a2 .. table.concat(a3, "")
        a2 = a2 .. " } \n"
        a2 = a2 .. GenerateFluff()
        a2 = a2 .. "return ____[11]((____[8](__)), ____[#____])()\n"
    else
        a2 = "return loadstring('" .. dumpString(a) .. "')()"
    end
    
    if randomComments then
        print("Inserting unreadable and pointless comments ...")
        a2 = a2:gsub("[%s]+", function() 
            local r = "" 
            for i = 1, math.random(0, 20) do 
                local x = math.random(1, 100)
                if x < 25 then
                    r = r .. string.char(math.random(1, 9))
                elseif x < 50 then
                    r = r .. string.char(math.random(11,28))
                elseif x < 75 then
                    r = r .. string.char(math.random(32, 90))
                elseif x < 90 then
                    r = r .. string.char(math.random(94, 126))
                else
                    r = r .. string.char(math.random(128, 255))
                end
            end 
            return " --[[" .. r .. "]] " 
        end)
    end
    
    a2 = a2:gsub("\r+", " ")
    a2 = a2:gsub("\n+", " ")
    a2 = a2:gsub("\t+", " ")
    a2 = a2:gsub("[ ]+", " ")
    
    --a2 = a2 .. GenerateFluff() TODO
    if level < mxLevel then
        print(concat("OBFUSCATED AT LEVEL ", level, " OUT OF ", mxLevel, " (" .. a:len() .. " Obfuscated characters)"))
        return obfuscate(a2, level + 1, mxLevel)
    else
        print(concat("OBFUSCATED AT LEVEL ", level, " OUT OF ", mxLevel, " (", a:len(), " Obfuscated Characters) [Done]"))
        return a2
    end
end

function XFuscate(...)
    local s, code = pcall(obfuscate, ...)
    if not s then 
        return nil, code
    else
        return code
    end
end
