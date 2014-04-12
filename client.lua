luarpc = require("luarpc")

local p1 = luarpc.createProxy("localhost", 3000, "interface")
local p2 = luarpc.createProxy("localhost", 3001, "interface")
local p3 = luarpc.createProxy("localhost", 3001, "interface")

local r, s = p1.foo(1, nil, 3)
print(r, s)

local t, s = p2.boo("3")
print(t)

local q, s = p1.boo("4")
print(q)

local q, s = p1.boo(7)
print(q)

local p, s = p3.foo(2, 3)
print(p, s)

--local q = p2.too("Hello world\nHow are you\n")
--print(q)
