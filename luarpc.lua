-- Load namespace
socket = require("socket")

-- Start Error Messages
ERROR = "ERRORPC"
ARG_ERROR = "Couldn't transform the arguments"
SND_ERROR = "Couldn't send the data to the server"
RCB_ERROR = "Couldn't receive the data from the server"
FTN_ERROR = "The function doesn't exist"
PRM_ERROR = "Couldn't receive argument from client"
RSP_ERROR = "Couldn't respond to the client"
-- End Error Messages

-- Start Globals --
LOGGER = false

CLSE_CONNS = 0
POOL_CONNS = 1

RPCServer =
{
  host = "*",
  port = 3000,
  max_clients = 5,
  servertimeout = 5,
  clienttimeout = 5,
  receivetimeout = 1,
  connection_type = POOL_CONNS
}

RPC = {}
proxy = {}
servers = {}
clients = {}
objects = {}
interfaces = {}
specification = {}

DEFAULTS = 
{
	char   = "c",
	string = "s",
	double = 0.0,
	default = "nil"
}

STRING = "string"
DOUBLE = "double"
CHAR   = "char"
-- End Globals --

--[[
-- Interface function
-- @param t 	A table
--]]
function interface(t)
  specification = t
end

--[[
-- Prints an error message and return it with a string of error added at the beggining
-- @param e			A string with a message
-- @param isServer	A boolean to verify if it's the client or server
-- @return 			A string of error
--]]
function exception(e, isServer) 
	e = "___ERRORPC: " .. e

	if isServer == true  then
		log(e)
		print(e)
	end

	return ERROR, e
end

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
-- Serialize some text to a pre - defined standard
-- @param text		A string
-- @return 			A string serialized
--]]
function serialize(text)
	local message = string.gsub(text, "\n", "\\n")

	return "\"" .. message .. "\""
end

--[[
-- Unserialize some text from a pre - defined standard
-- @param text		A string
-- @return 			A string unserialized
--]]
function unserialize(text)
	local message = string.sub(text, 2, text:len() - 1)
	message =  string.gsub(message, "\\n", "\n")

	return message
end

--[[
-- Verify the correctness of the arguments, and if an error it's found correct if possible
-- @param t     	The table with the arguments especification
-- @param ...		The function arguments
-- @return 			A table with correct arguments, or error
--]]
function verifyArguments(t, ...) 
	local data = {...}

	-- Remove extra arguments
	while #data > t.args.length do
		table.remove(data, #data)
	end

	for i, a_type in ipairs(t.args) do
		local value, serialize_flag = _, true
		
		if data[i] == nil then
			--data[i] = DEFAULTS[a_type]
			data[i] = DEFAULTS["default"]
			serialize_flag = false
		elseif type(data[i]) == "string" and a_type == DOUBLE then
			value = tonumber(data[i])
			if value == nil then
				return exception(ARG_ERROR)
			else
				data[i] = value
			end
		elseif type(data[i]) == "number" and (a_type == STRING or a_type == CHAR) then
			value = tostring(data[i])
			if tostring(data[i]) == nil then
				return exception(ARG_ERROR)
			else
				data[i] = value
			end
		end 

		if type(data[i]) == "string" and serialize_flag == true then
			data[i] = serialize(data[i]) 
		end
	end

	return data
end

--[[
-- Transmits the data to the server and waits for the response
-- @param t			A table with data that includes the server ip and port
-- @param method    The name of the method
-- @param arguments The arguments to be send
-- @return 			The results that the server sent
--]]
function transmitPackage(t, method, arguments)
	local ip   = t.client.ip or RPCServer.host
	local port = t.client.port or RPCServer.port

	local package = method
	for _, v in ipairs(arguments) do
		package = package .. "\n" .. v
	end

	-- Connection to the server
	local client
	if t.client.socket == nil then
		client = assert(socket.connect(ip, port))
  		client:settimeout(RPCServer.clienttimeout)
  		t.client.socket = client
  	else
  		client = t.client.socket
	end
	
  	local _, err = client:send(package .. "\n")
	
  	if err then
  		client:close()
  		return exception(SND_ERROR)
  	end

	local results = {}
  	for i = 1, t.result.length do 
  		local result, err = client:receive()
  		
  		if err then
  			client:close()
  			return exception(RCB_ERROR)
  		end

  		if t.result[i] == STRING and result ~= DEFAULTS["default"] then
  			result = unserialize(result)
  		end

  		table.insert(results, result)
  	end

  	if RPCServer.connection_type == CLSE_CONNS then
  		client:close()
  		t.client.socket = nil
  	end

  	return unpack(results)
end

--[[
-- Parse the interface that is stored on a file
-- @param arq_interface		A string that is the path to the interface of the functions
-- @param client 			A table that contains the ip and port of the server sockets
-- @return 					A table with the parsed interface and some functions as metatables
--]]
function parseInterface(arq_interface, client)
	dofile(arq_interface)

	-- Return table
	local package = {}

	for m_name, m_att in pairs(specification.methods) do

		local temp = 
		{
			client = client,
			result = {length = 0},	
			args   = {length = 0}
		}

		if m_att.resulttype ~= "void" then
			table.insert(temp.result, m_att.resulttype)
			temp.result.length = temp.result.length + 1
		end

		for _, m_arg in pairs(m_att.args) do

			if m_arg.direction == "in" then
				table.insert(temp.args, m_arg.type)
				temp.args.length = temp.args.length + 1
			elseif m_arg.direction == "out" then
				table.insert(temp.result, m_arg.type)
				temp.result.length = temp.result.length + 1
			elseif m_arg.direction == "inout" then
				table.insert(temp.args, m_arg.type)
				table.insert(temp.result, m_arg.type)
				temp.args.length = temp.args.length + 1
				temp.result.length = temp.result.length + 1
			end
		end

		package[m_name] = temp;

		local method = {}
		
		-- Control for the () call
		function method.__call(t, ...)
			local arguments, error_m = verifyArguments(t, ...)

			if arguments == ERROR then
				return error_m
			end

			return transmitPackage(t, m_name, arguments)
		end
		
		setmetatable(package[m_name], method)

	end

	-- Control for non existent functions
	local controller = setmetatable({}, 
		{
			__index = 
				function(t, k)
					error("Function doesn't exist")
				end
		}
	)

	setmetatable(package, {__index = controller})

	return package
end

--[[
-- Handle the client connection
-- @param client		The client socket
-- @param method 		The name of the method that server has to execute
-- @return 				An error if exists
--]]
function handleClient(client, method) 
	local server = proxy[client]
	
	local params  = {}
	local results = {}

	local a_types = interfaces[server][method].args
	local r_types = interfaces[server][method].result

	for i = 1, a_types.length do

		local param, err = client:receive()

		if err then
			client:send(exception(PRM_ERROR, true))
			break
		end

		if a_types[i] == STRING and param ~= DEFAULTS["default"] then
			param = unserialize(param)
		end

		table.insert(params, param)

	end

	--results = {objects[server][method](unpack(params))}
	results = {pcall(objects[server][method], unpack(params))}
	local response = ""

	if results[1] == false then
		results[2] = "___ERRORPC: " .. results[2]
		log(results[2])
	end

	table.remove(results, 1)

	for i = 1, r_types.length do

		if results[i] == nil then
			results[i] = DEFAULTS["default"]
		elseif r_types[i] == STRING then
			results[i] = serialize(results[i])
		end

		response = response .. results[i] .. "\n"

	end

	--[[for i, result in ipairs(results) do
		if r_types[i] == STRING then
			result = serialize(result)
		end

		response = response .. result .. "\n"
	end]]

	local _, err = client:send(response)

  	if err then
  		client:send(exception(RSP_ERROR, true))
  		return RSP_ERROR
  	end
end

--[[
-- Creates a socket binded to a port with specific function to response
-- @param object 			A table that contains implementations of some functions 
-- @param arq_interface		A string that is the path to the interface of the functions
-- @return 					The server socket
--]]
function createServant(object, arq_interface) 
	local port = RPCServer.port + #servers

	local package = parseInterface(arq_interface)

	-- Create a socket and bind it to the host, and port
	local server = assert(socket.bind(RPCServer.host, port))
	server:setoption("tcp-nodelay", true)

	table.insert(servers, server)
	objects[server]    = object
	interfaces[server] = package

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
  		local readers, writers = socket.select(servers, clients)
  		
  		for i, server in ipairs(readers) do
  			
  			if #clients >= RPCServer.max_clients then
  				local r_client = table.remove(clients, 1)
  				r_client:close()
  			end
  			
  			server:settimeout(RPCServer.servertimeout)
	    	local client = server:accept()
	    	proxy[client] = server
	    	
	    	if RPCServer.connection_type == POOL_CONNS then
		    	table.insert(clients, client)
	    	end
	    	
	    	 -- Get client ip
    		local client_ip = client:getpeername()
    		log("Connection established with [" .. client_ip .. "]")

    		-- Receive the method
			local method, err = client:receive()

			if err or objects[server][method] == nil then
				client:send(exception(FTN_ERROR, true))
				break
			end

    		-- Handle Clients
    		handleClient(client, method)

		  	if RPCServer.connection_type == CLSE_CONNS then
		  		proxy[client] = nil
		  		client:close()
		  	end
  		end

  		for _, client in ipairs(writers) do
  			
  			client:settimeout(RPCServer.receivetimeout)
			local method, err = client:receive()
			
			if not err then
				-- Handle Clients
				handleClient(client, method)
			end
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
	local client = {ip = ip, port = port, socket = nil}
	local package = parseInterface(arq_interface, client)

	return package
end

-- Main functions of the library returned as a table
RPC.createServant = createServant
RPC.waitIncoming  = waitIncoming
RPC.createProxy   = createProxy

return RPC