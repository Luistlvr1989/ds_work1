luarpc = require("luarpc")

function string.totable(s)
	local temp = string.gmatch(s, "{(.-)}")
	local r_table = {}

	for value in string.gmatch(temp(), "([^,]+)") do
		table.insert(r_table, value)
	end

	return r_table
end

myobj1 = { 
	foo = 
		function (a, b, s)
			return a + b, "alo alo"
		end,
	boo = 
		function (n)
			local t = string.totable(n)
			return t[1]
		end,
	too = 
		function (s)
			return s .. " hello"
		end
}

myobj2 = { 
	foo = 
		function (a, b, s)
			return a + b, "tchau"
		end,
	boo = 
		function (n)
			local t = string.totable(n)
			return t[2]
		end,
	too = 
		function (s)
			return s .. " bye"
		end
}

serv1 = luarpc.createServant(myobj1, "interface")
serv2 = luarpc.createServant(myobj2, "interface")

luarpc.waitIncoming()