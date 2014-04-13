luarpc = require("luarpc")

N_CLIENTS = 1
PORTS = {3000, 3001}

AMOUNT, MIN_SIZE, MAX_SIZE = 10, 180, 200

local clients = {}

math.randomseed(os.time())

function table.val_to_str(v)
  if "string" == type(v) then
    v = string.gsub(v, "\n", "\\n")
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$') then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"') .. '"'
  else
    return "table" == type(v) and table.tostring(v) or
      tostring(v)
  end
end

function table.key_to_str(k)
  if "string" == type(k) and string.match( k, "^[_%a][_%a%d]*$") then
    return k
  else
    return "[" .. table.val_to_str(k) .. "]"
  end
end

function table.tostring(tbl)
  local result, done = {}, {}
  for k, v in ipairs(tbl) do
    table.insert(result, table.val_to_str(v))
    done[k] = true
  end
  for k, v in pairs(tbl) do
    if not done[k] then
      table.insert(result,
        table.key_to_str(k) .. "=" .. table.val_to_str(v))
    end
  end
  return "{" .. table.concat(result, ",") .. "}"
end

function string.totable(s)
	local temp = string.gmatch(s, "{(.-)}")
	local r_table = {}

	for value in string.gmatch(temp(), "([^,]+)") do
		table.insert(r_table, value)
	end

	return r_table
end

function makeString()
	local size = math.random(MIN_SIZE, MAX_SIZE)
	local string = ""

	for i = 1, size do
		string = string .. string.char(math.random(32, 126))
	end

	return string
end

-- Main Code

-- Clients Creation

for i = 1, N_CLIENTS do
	local port = PORTS[math.random(1, 2)]
	local client = luarpc.createProxy("localhost", port, "interface")
	table.insert(clients, client)
end

--[[ 
-- First Tests

for i = 1, AMOUNT do

	for _, v in ipairs(clients) do
		local call = math.random(1, 3)
		
		if call == 1 then
			v.foo(math.random(1, 10), math.random(1, 10))
		elseif call == 2 then
			v.boo(makeString())
		elseif call == 3 then
			v.too(makeString())
		end
	end

end


-- Second Tests

for i = 1, AMOUNT do

	for _, v in ipairs(clients) do
		v.boo(makeString())
	end

end
]]


-- Third Tests

doubles = {}

for i = 1, 100 do 
	table.insert(doubles, math.random(1, 100))
end

for i = 1, AMOUNT do

	for _, v in ipairs(clients) do
		v.boo(table.tostring(doubles))
	end

end

--doubles = string.totable(stable)






-- Older Tests

--[[
local p1 = luarpc.createProxy("localhost", 3000, "interface")
local p2 = luarpc.createProxy("localhost", 3001, "interface")
local p3 = luarpc.createProxy("localhost", 3001, "interface")
local p4 = luarpc.createProxy("localhost", 3000, "interface")
local p5 = luarpc.createProxy("localhost", 3001, "interface")
local p6 = luarpc.createProxy("localhost", 3000, "interface")
local p7 = luarpc.createProxy("localhost", 3000, "interface")
local p8 = luarpc.createProxy("localhost", 3001, "interface")

--local r, s = p1.foo(1, nil, 3)
local r, s = p1.foo(1, 3)
print(r, s)

--local t, s = p2.boo("3")
--print(t, s)

print(p2.boo("3"))

--local q, s = p1.boo("4")
--print(q, s)

print(p1.boo("3"))

local q, s = p2.boo(7)
print(q)

local p, s = p3.foo(2, 3)
print(p, s) 

local p, s = p4.foo(1, 1)
print(p, s) 

local t, s = p1.boo("10")
print(t, s)

local t, s = p2.boo("10")
print(t, s)

local p, s = p4.foo(10, 2)
print(p, s) 

local r, s = p1.boo("nil")
print(r, s)

local r, s = p8.boo("nil")
print(r, s)

local p, s = p7.foo(10, 2)
print(p, s) 

local r, s = p1.foo(1, nil, 3)
print(r, s)]]

--local q = p2.too("Hello world\nHow are you\n")
--print(q)