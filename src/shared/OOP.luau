-- Purpose: OOP framework
-- Designer: SuperSpeedy101
local RunService = game:GetService("RunService")

--- @class OOP
---
--- Luau Object-Orientated Programming Framework. https://devforum.roblox.com/t/efficient-object-oriented-programming-tutorial/1061153
local OOP = {}

--- @type OOPClass {any}
--- @private
--- @within OOP
--- A class created from OOP.class({})

--- OOPClass() constructor, metamethod setting. After receving the OOPClass through OOP.class({}), object can be constructed with OOPClass()
---
--- @param ... List<Any> -- Arguments passed through as constructor.
function OOP:__call(...): any
  local object = {}
  setmetatable(object, self)

  if self.__init then
    self.__init(object, ...)
  end
  return object
end

--- Helper that searches class + its __super chain
--- @within OOP
--- @param class OOPClass -- Object/class being looked up
--- @param key string -- Key (attribute/method) being looked up
local function lookupInClassChain(class, key: string): any
  local v = rawget(class, key)
  if v ~= nil then return v end

  local super = rawget(class, "__super")
  if super ~= nil then
    return lookupInClassChain(super, key)
  end

  return nil
end

--- A OOP class is defined in a module script:
--- ```lua
--- local Class = OOP.class{x = 1, y = 2}
--- function Class:__init(x, y)
---   -- If x, y are nil, default values are referenced
---   -- because of metatable assignment
---   self.x = x
---   self.y = y
--- end
--- function Class:getSum()
---   return self.x + self.y
--- end
--- function Class:__tostring()
---   return `Class has attributes {self.x}, {self.y}`
--- end
--- return Class
--- ````
---
--- And then utilized elsewhere:
--- ```lua
--- local Class = require(CLASS_PATH)
--- local object = Class()
--- -- Or
--- local object = Class(1, 2)
---
--- print(object:getSum()) --> 3
--- print(object) --> "Class has attributes 1, 2"
--- ```
---
--- @param class any -- Attributes list for default values, __super inheritance.
function OOP.class(class: any): any
  if class.__super then
    for key, value in pairs(class.__super) do
      local sub = string.sub(key, 1, 2)
      if sub == "__" and key ~= "__super" and key ~= "__init" then
        class[key] = value
      end
    end
  end
  class.__index = function(obj, key)
    -- rawget(obj, key) is always nil here (otherwise __index wouldn't run),
    -- but leaving it makes intent explicit and is harmless.
    local v = rawget(obj, key)
    if v ~= nil then return v end

    return lookupInClassChain(class, key)
  end
  return setmetatable(class, OOP)
end

--- @class Utility
---
--- Utility for event listeners structured in the OOP way.
local Utility = {}

--- Bind an event to an object's method
---
--- @param object OOPClass -- Object passed to eventListener which holds the methods.
--- @param event RBXScriptSignal -- Event passed to the function
--- @param method string -- Method's name as an attribute in object
function Utility.eventListener(object, event: RBXScriptSignal, method: string): nil
  event:Connect(function(...)
    object[method](object, ...)
  end)
  return nil
end

--- Remote event bind on either client or server
---
--- @param object OOPClass -- Object passed to remoteListener which holds the methods.
--- @param remoteEvent RemoteEvent -- Remote Event used
--- @param method string -- Method's name as an attribute in object
function Utility.remoteEventListener(object, remoteEvent: RemoteEvent, method: string): nil
  if RunService:IsServer() then
    remoteEvent.OnServerEvent:Connect(function(...)
      object[method](object, ...)
    end)
  elseif RunService:IsClient() then
   remoteEvent.OnClientEvent:Connect(function(...)
     object[method](object, ...)
   end)
  end
  return nil
end

--- Remote function bind on either client or server
---
--- @param object OOPClass -- Object passed to remoteListener which holds the methods.
--- @param remoteFunction RemoteFunction -- Remote Function used
--- @param method string -- Method's name as an attribute in object
function Utility.remoteFunctionListener(object, remoteFunction: RemoteFunction, method: string): nil
  if RunService:IsServer() then
    remoteFunction.OnServerInvoke = function(...)
      return object[method](object, ...)
    end
  elseif RunService:IsClient() then
   remoteFunction.OnClientInvoke = function(...)
     return object[method](object, ...)
   end
  end
  return nil
end

--- Function to continuously cycle per interval
---
--- @param object OOPClass
--- @param interval number -- Time per cycle
--- @param method string -- Method name
function Utility.cycle(object, interval: number, method: string): nil
  task.spawn(function()
    while true do
      object[method](object)
      task.wait(interval)
    end
  end)
  return nil
end

--- Bind to game's closing event (game:BindToClose())
---
--- @param object OOPClass -- Object which holds the methods
--- @param method string -- Method's name as an attribute in object.
function Utility.bindToClose(object, method): nil
  game:BindToClose(function()
    object[method](object)
  end)
  return nil
end

--- @prop Utility Utility
--- @within OOP
--- OOP.Utility provides the Utility module
OOP.Utility = Utility
return OOP

