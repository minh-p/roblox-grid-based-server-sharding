-- Purpose: OOP framework
-- Designer: SuperSpeedy101

local Utility = {}
local RunService = game:GetService("RunService")

function Utility:eventListener(bindableEvent, method)
  bindableEvent:Connect(function(...)
    self[method](self, ...)
  end)
end

function Utility:remoteListener(remoteEvent, method)
  if RunService:IsServer() then
    remoteEvent.OnServerEvent:Connect(function(...)
      self[method](self, ...)
    end)
  elseif RunService:IsClient() then
   remoteEvent.OnClientEvent:Connect(function(...)
     self[method](self, ...)
   end)
  end
end

function Utility:bindToClose(method)
  game:BindToClose(function()
    self[method](self)
  end)
end

local OOP = {}
OOP.Utility = Utility

function OOP:__call(...)
  local object = {}
  setmetatable(object, self)

  if self.__init then
    self.__init(object, ...)
  end
  return object
end

function OOP:__index(index)
  if rawget(self, "__super") then
    return self.__super[index]
  end
  return rawget(self, index)
end

function OOP.class(class)
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
