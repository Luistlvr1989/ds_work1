luarpc = require("luarpc")

myobj1 = { 
	foo = 
		function (a, b, s)
			return a + b, "alo alo"
		end,
	boo = 
		function (n)
			return n
		end
}

myobj2 = { 
	foo = 
		function ()
			return "tchau"
		end,
	too = 
		function (a, b, s)
			return a - b, "tchau"
		end,
	boo = 
		function (n)
			return 1
		end
}

serv1 = luarpc.createServant(myobj1, "interface")
serv2 = luarpc.createServant(myobj2, "interface")

luarpc.waitIncoming()