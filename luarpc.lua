-- Load namespace
socket = require("socket")

-- Start Globals --
LOGGER = false

RPCServer =
{
  host = "*",
  port = 3000,
  servertimeout = 5,
  clienttimeout = 5
}

RPC = {}
servers = {}
objects = {}
-- End Globals --

--[[
-- Writes to a file some important information if LOGGER is true
-- @param ...	anything
--]]
function log(...) 
	if LOGGER then
		local logFile = assert(io.open("server.log", "a"))
		logFile:write("[" .. os.date() .. "]: " .. ... .. "\n")
		logFile:close()
	end
end

--[[
-- Prints a table with an indentation 
-- @param tbl 		The table to be printed
-- @param indent 	The number of spaces (optional)
--]]
function tprint(tbl, indent)
	if not indent then 
		indent = 0 
	end

	for k, v in pairs(tbl) do
		formatting = string.rep(" ", indent) .. "[" .. k .. "]" .. ": "
		
		if type(v) == "table" then
			print(formatting)
			tprint(v, indent + 1)
		elseif type(v) == 'boolean' then
			print(formatting .. tostring(v))	
		else
			print(formatting .. v)
		end	
	end
end

--[[
-- Writes to a file some important information if LOGGER is true
-- @param tableArg	An empty table or with elements
-- @param value		A value to be added to the table
-- @return 			A table with the element value inserted
--]]
function add2table(tableArg, value)
	if tableArg == nil then
		tableArg = {value}
	else
		table.insert(tableArg, value)
	end

	return tableArg 
end

--[[
-- Creates a socket binded to a port with specific function to response
-- @param object 			A table that contains implementations of some functions 
-- @param arq_interface		A string that is the path to the interface of the functions
-- @return 					The server socket
--]]
function createServant(object, arq_interface) 
	local port = RPCServer.port + #servers

	if interface == nil then
		interface = parseInterface(arq_interface)
	end

	-- Create a socket and bind it to the host, and port
	local server = assert(socket.bind(RPCServer.host, port))
	table.insert(servers, server)
	objects[server] = object

	print("Socket on " .. RPCServer.host .. ":" .. port)
	log("Socket on " .. RPCServer.host .. ":" .. port)

	return server
end

--[[
-- Wait for calls to the servers created with the function createServant
--]]
function waitIncoming()
	if next(servers) == nil then
		error("First call createServant")
  	end

  	while true do
  		local readers = socket.select(servers, nil, 1)

  		for i, server in ipairs(readers) do
  			server:settimeout(RPCServer.servertimeout)
	    	local client = server:accept()

	    	 -- Get client ip
    		local client_ip = client:getpeername()
    		log("Connection established(" .. client_ip .. ")")

	    	local method, err = client:receive()

	    	if err or objects[server][method] == nil then
	    		client:send("___ERRORPC: The function doesn't exist\n")
	    		break
	    	end

	    	--[[local n_args, err = client:receive()

	    	if err then
	    		client:send("___ERRORPC: The number of arguments is not correct\n")
	    		break
	    	end]]
	    	
	    	n_args = interface[method][1].args.length

	    	local params = {}
	    	local result = {}

	    	for j = 1, n_args do
	    		local param, err = client:receive()
	    		table.insert(params, param)
	    	end

	    	result = {objects[server][method](unpack(params))}

	    	if not err then
	    		--[[local temp = #result

	    		for _, v in ipairs(result) do
	    			temp = temp .. '\n' .. v
	    		end

				client:send(temp .. '\n')]]

				for _, v in ipairs(result) do
	    			client:send(v .. '\n')
	    		end
			else
				client:send("___ERRORPC: " .. err)
			end

			--client:close()
	    end
  	end
end

--[[
-- Creates a table with all the requirement data to make a connection with a socket
-- @param ip 				The ip of the socket to connect
-- @param port				The port of the socket to connect
-- @param arq_interface		A string that is the path to the interface of the functions
-- @return 					A table with the parsed interface and some functions as metatables
--]]
function createProxy(ip, port, arq_interface)
	local client = {ip = ip, port = port}
	local package = parseInterface(arq_interface, client)

	return package
end

--[[
-- Parse the interface that is stored on a file
-- @param arq_interface		A string that is the path to the interface of the functions
-- @param client 			A table that contains the ip and port of the server sockets
-- @return 					A table with the parsed interface and some functions as metatables
--]]
function parseInterface(arq_interface, client)
	local file = assert(io.open(arq_interface, "r"))
	local interface = file:read("*all")
	file:close()

	-- Return table
	local package = {}

	-- Control for non existent functions
	local controller = setmetatable({}, 
		{
			__index = 
				function(t, k)
					error("Function doesn't exist")
				end
		}
	)

	-- Remove comments
	interface = string.gsub(interface, "/%*.-%*/", "")

	-- Get the functions
	functions = string.gmatch(interface, "%s*interface%s*%w+%s*{(.+)}%s*;$")

	for r_type, name, params in string.gmatch(functions(), "%s*(%a+)%s*(%w+)%s*%((.-)%)%s*;") do
		if package[name] == nil and client ~= nil then
			package[name] = {client = client}
		elseif package[name] == nil then
			package[name] = {}
		end

		local temp = 
		{
			result = {length = 0},	
			args   = {length = 0}
		}

		if r_type ~= "void" then
			table.insert(temp.result, r_type)
			temp.result.length = temp.result.length + 1
		end

		for p_dir, p_type, p_name in string.gmatch(params, "%s*(%a+)%s*(%a+)%s*(%w+)") do
			if p_dir == "in" then
				table.insert(temp.args, p_type)
				temp.args.length = temp.args.length + 1
			elseif p_dir == "out" then
				table.insert(temp.result, p_type)
				temp.result.length = temp.result.length + 1
			elseif p_dir == "inout" then
				table.insert(temp.args, p_type)
				table.insert(temp.result, p_type)
				temp.args.length = temp.args.length + 1
				temp.result.length = temp.result.length + 1
			end
		end

		table.insert(package[name], temp)

		local method = {}
		
		function method.__call(t, ...)
			local argument, message = packArgument(name, t, ...)

			if argument == "error" then
				return argument, message
			end

			return transmit(t, argument)
		end
		
		setmetatable(package[name], method)
	end

	setmetatable(package, {__index = controller})

	return package
end

--[[
-- Pack the function name and the parameters to send 
-- @param method			The method name 
-- @param package 			A table that containts the parsed data of the interface (only the method)
-- @param ...				All the parameters for the method
-- @return 					The package (string) to be send to the socket server
--]]
function packArgument(method, package, ...)
	local data = {...}
	--local argument = method .. '\n' .. #data
	local argument = method

	local errorNArg = true

	-- Check for correct amount of arguments
	for i, v in ipairs(package) do
		if v.args.length == #data then
			errorNArg = false
		end
	end

	if errorNArg then
		return "error", "Wrong number of arguments"
	end

	local correctArg = {}

	-- Check for correct arguments types (transform if possible) and package the data
	for i, v in ipairs(data) do
		for _i, _v in ipairs(package) do
			local correct = false

			if type(v) == "string" and _v.args[i] == "double" then
				if tonumber(v) ~= nil then
					correct = true
				end
			elseif type(v) == "number" and (_v.args[i] == "string" or _v.args[i] == "char") then
				if tostring(v) ~= nil then
					correct = true
				end
			elseif type(v) == "number" and _v.args[i] == "double" or 
			   	   type(v) == "string" and (_v.args[i] == "string" or _v.args[i] == "char") then
			   		correct = true
			end
			correctArg[_i] = add2table(correctArg[_i], correct)
		end
		
		argument = argument .. '\n' .. v 
	end

	for i, v in ipairs(correctArg) do
		local flag = true

		for _i, _v in ipairs(v) do
			if _v == false then
				flag = false
				break
			end
		end

		if flag == true then
			return argument
		end
	end

	if next(correctArg) == nil then
		return argument
	end

	return "error", "Wrong arguments"
end

--[[
-- Transmits the data to the server and waits for the response
-- @param t			A table with data that includes the server ip and port
-- @param package 	The package to be send
-- @return 			The results that the server sent
--]]
function transmit(t, package)
	local ip   = t.client.ip or RPCServer.host
	local port = t.client.port or RPCServer.port

  	-- Connection to the server
  	local client = assert(socket.connect(ip, port))
  	client:settimeout(RPCServer.clienttimeout)

  	client:send(package .. "\n")

  	local n_results = t[1].result.length
  	--local n_results, err = client:receive()

  	if err then
  		return "error", "Problem at the receiving"
  	end

  	local results = {}

  	for i = 1, n_results do 
  		local result, err = client:receive()
  		table.insert(results, result)
  	end

  	--client:close()

  	return unpack(results)
end

-- Main functions of the library returned as a table

RPC.createServant = createServant
RPC.waitIncoming  = waitIncoming
RPC.createProxy   = createProxy

return RPC