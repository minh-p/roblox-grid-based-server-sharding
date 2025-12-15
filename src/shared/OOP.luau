-- Purpose: OOP framework
-- Designer: SuperSpeedy101
local RunService = game:GetService("RunService")

--- @class Utility
---
--- Utility for event listeners structured in the OOP way.
local Utility = {}

--- Bind an event to an object's method
---
--- @param object OOPClass -- Object passed to eventListener which holds the methods.
--- @param event RBXScriptSignal -- Event passed to the function
--- @param method string -- Method's name as an attribute in object
function Utility.eventListener(object, event: RBXScriptSignal, method: string)
  event:Connect(function(...)
    object[method](object, ...)
  end)
end

--- Remote event bind on either client or server
---
--- @param object OOPClass -- Object passed to remoteListener which holds the methods.
--- @param remoteEvent RemoteEvent -- Remote Event used
--- @param method string -- Method's name as an attribute in object
function Utility.remoteListener(object, remoteEvent, method)
  if RunService:IsServer() then
    remoteEvent.OnServerEvent:Connect(function(...)
      object[method](object, ...)
    end)
  elseif RunService:IsClient() then
   remoteEvent.OnClientEvent:Connect(function(...)
     object[method](object, ...)
   end)
  end
end

--- Bind to game's closing event (game:BindToClose())
---
--- @param object OOPClass -- Object which holds the methods
--- @param method string -- Method's name as an attribute in object.
function Utility.bindToClose(object, method)
  game:BindToClose(function()
    object[method](object)
  end)
end

--- @class OOP
---
--- Luau Object-Orientated Programming Framework. https://devforum.roblox.com/t/efficient-object-oriented-programming-tutorial/1061153
local OOP = {}
OOP.Utility = Utility

--- OOPClass() constructor, metamethod setting. After receving the OOPClass through OOP.class({}), object can be constructed with OOPClass()
---
--- @param ... List<Any> -- Arguments passed through as constructor.
function OOP:__call(...)
  local object = {}
  setmetatable(object, self)

  if self.__init then
    self.__init(object, ...)
  end
  return object
end

--- OOPObject indexing with inheritance implemented. Inheritance depends on if __super assigned to super class is an attribute of class attributes list pass to .class().
---
--- @param index any -- metamethod param index can be a string, number, or any non-nil value.
function OOP:__index(index: any)
  if rawget(self, "__super") then
    return self.__super[index]
  end
  return rawget(self, index)
end

--- Create class
---
--- @param class any -- Attributes list for default values, __super inheritance.
function OOP.class(class: any)
  if class.__super then
    for key, value in pairs(class.__super) do
      local sub = string.sub(key, 1, 2)
      if sub == "__" and key ~= "__super" and key ~= "__init" then
        class[key] = value
      end
    end
  end
  class.__index = class
  return setmetatable(class, OOP)
end

return OOP
