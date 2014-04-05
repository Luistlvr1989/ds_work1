luarpc = require("luarpc")

local p1 = luarpc.createProxy("localhost", 3000, "interface")
local p2 = luarpc.createProxy("localhost", 3001, "interface")

local r, s = p1.foo(1, "2")
print(r, s)

local t = p2.boo(10)
print(t)

local q = p1.boo(10)
print(q)

local q = p2.too("Hello world\nHow are you\n")
print(q)