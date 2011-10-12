
if SF then return end -- Already loaded
SF = {}

-- Send files to client
if SERVER then
	AddCSLuaFile("SFLib.lua")
	AddCSLuaFile("Compiler.lua")
	AddCSLuaFile("Instance.lua")
	AddCSLuaFile("Libraries.lua")
	AddCSLuaFile("Preprocess.lua")
	AddCSLuaFile("Permissions.lua")
	AddCSLuaFile("Editor.lua")
end

-- Load files
include("Compiler.lua")
include("Instance.lua")
include("Libraries.lua")
include("Preprocessor.lua")
include("Permissions.lua")
include("Editor.lua")

SF.defaultquota = CreateConVar("sf_defaultquota", "100000", {FCVAR_ARCHIVE,FCVAR_REPLICATED},
	"The default number of Lua instructions to allow Starfall scripts to execute")

local dgetmeta = debug.getmetatable

--- The default environment
SF.DefaultEnvironment = {}
local DefaultEnvironment = SF.DefaultEnvironment
DefaultEnvironment.__index = DefaultEnvironment
DefaultEnvironment.__metatable = "Environment"

--- A set of all instances that have been created. It has weak keys and values.
-- Instances are put here after initialization.
SF.allInstances = setmetatable({},{__mode="kv"})

--- Calls a script hook on all processors.
function SF.RunScriptHook(hook,...)
	for _,instance in pairs(SF.allInstances) do
		if not instance.error then instance:runScriptHook(hook,...) end
	end
end

--- Creates a type that is safe for SF scripts to use. Instances of the type
-- cannot access the type's metatable
function SF.Typedef(name, base)
	local tbl = base or {}
	tbl.__metatable = tbl.__metatable or name
	tbl.__index = tbl.__index or function(self,k) if k:sub(1,2) ~= "__" then return tbl[k] end end
	return tbl
end

--- Creates a new context. A context is used to define what scripts will have access to.
-- @param env The environment metatable to use for the script. Default is SF.DefaultEnvironment
-- @param directives Additional Preprocessor directives to use. Default is an empty table
-- @param permissions The permissions manager to use. Default is SF.DefaultPermissions
-- @param ops Operations quota. Default is specified by the convar "sf_defaultquota"
-- @param libs Additional (local) libraries for the script to access. Default is an empty table.
function SF.CreateContext(env, directives, permissions, ops, libs)
	local context = {}
	context.env = env or DefaultEnvironment
	context.directives = directives or {}
	context.permissions = permissions or SF.Permissions
	context.ops = ops or SF.defaultquota:GetInt()
	context.libs = libs or {}
	return context
end

--- Checks the type of val. Errors if the types don't match
-- @param val The value to be checked.
-- @param typ A string type or metatable.
-- @param level Level at which to error at. 3 is added to this value. Default is 0.
-- @param default A value to return if val is nil.
function SF.CheckType(val, typ, level, default)
	if not val and default then return default
	elseif type(val) == typ then return val
	elseif dgetmeta(val) == typ then return val
	else
		level = (level or 0) + 3
		
		local typname
		if type(typ) == "table" then
			typname = typ.__metatable or "table"
		else
			typname = type(typ)
		end
		
		local funcname = debug.getinfo(level-1, "n").name or "<unnamed>"
		error("Type mismatch (Expected "..typname..", got "..SF_Compiler.GetType(typ)..") in function "..funcname,level)
	end
	
end

--- Creates wrap/unwrap functions for sensitive values, by using a lookup table
-- (which is set to have weak keys and values)
-- @param metatable The metatable to assign the wrapped value.
-- @return The function to wrap sensitive values to a SF-safe table
-- @return The function to unwrap the SF-safe table to the sensitive table
function SF.CreateWrapper(metatable)
	local sensitive2sf = setmetatable({},{__mode="kv"})
	local sf2sensitive = setmetatable({},{__mode="kv"})
	
	local function wrap(value)
		if sensitive2sf[value] then return sensitive2sf[value] end
		local tbl = setmetatable({},metatable)
		sensitive2sf[value] = tbl
		sf2sensitive[tbl] = value
		return tbl
	end
	
	local function unwrap(value)
		return sf2sensitive[value]
	end
	
	return wrap, unwrap
end

-- Library loading
if SERVER then
	local l
	MsgN("-SF - Loading Libraries")

	
	MsgN("- Loading SF server-side libraries")
	l = file.FindInLua("starfall2/libs_sv/*.lua")
	for _,filename in pairs(l) do
		print("-  Loading "..filename)
		include("starfall2/libs_sv/"..filename)
	end
	MsgN("- End loading server-side libraries")

	
	MsgN("- Adding client-side libraries to send list")
	l = file.FindInLua("starfall2/libs_cl/*.lua")
	for _,filename in pairs(l) do
		print("-  Adding "..filename)
		AddCSLuaFile("starfall2/libs_cl/"..filename)
	end
	MsgN("- End loading client-side libraries")


	MsgN("- Loading shared libraries")
	l = file.FindInLua("starfall2/libs_sh/*.lua")
	for _,filename in pairs(l) do
		print("-  Loading "..filename)
		include("starfall2/libs_sh/"..filename)
		AddCSLuaFile("starfall2/libs_sh/"..filename)
	end
	MsgN("- End loading shared libraries")

	
	MsgN("-End Loading SF Libraries")
else
	local l
	MsgN("-SF - Loading Libraries")

	
	MsgN("- Loading client-side libraries")
	l = file.FindInLua("starfall2/libs_cl/*.lua")
	for _,filename in pairs(l) do
		print("-  Loading "..filename)
		include("starfall2/libs_cl/"..filename)
	end
	MsgN("- End loading client-side libraries")


	MsgN("- Loading shared libraries")
	l = file.FindInLua("starfall2/libs_sh/*.lua")
	for _,filename in pairs(l) do
		print("-  Loading "..filename)
		include("starfall2/libs_sh/"..filename)
	end
	MsgN("- End loading shared libraries")

	
	MsgN("-End Loading SF Libraries")
end

SF.Libraries.CallHook("postload")
