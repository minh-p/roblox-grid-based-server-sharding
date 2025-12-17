local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Pract = require(Players.LocalPlayer.PlayerScripts.Client.Pract)
local PractTypes = require(Players.LocalPlayer.PlayerScripts.Client.Pract.Types)
type PractElement = PractTypes.Element
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local OOP = require(ReplicatedStorage.Shared.OOP)

--- @class NavMenuGui
--- @client
--- NavMenuGui made with Pract library. Starter place navigation into world
local NavMenuGui = OOP.class{}

--- Constructor
function NavMenuGui:__init()
  self._openNavMenuRemoteEvent = ReplicatedStorage:FindFirstChild("NavMenu") or ReplicatedStorage:WaitForChild("NavMenu")
  self._requestTeleportRemoteEvent = ReplicatedStorage:FindFirstChild("TeleportRequest") or ReplicatedStorage:WaitForChild("TeleportRequest")
  self._open = false
end

--- Run function
function NavMenuGui:run(): nil
  OOP.Utility.remoteEventListener(self, self._openNavMenuRemoteEvent, "_onNavMenuOpenOrder")
  self._handle = Pract.mount(Pract.create(self:generateClassComponent()), PlayerGui, "NavMenuGui")
  return nil
end

--- Gui Builder
function NavMenuGui.constructGui(props: {open: boolean, requestTeleportRemoteEvent: RemoteEvent}): PractElement
  if props.open then
    return Pract.create("ScreenGui", {ResetOnSpawn = false, IgnoreGuiInset = true}, {
      Frame = Pract.create("Frame", {
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 0.1,
        BackgroundColor3 = Color3.new(0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5)
      }, {
        Label = Pract.create("TextLabel", {
          Text = "Scuffed Teleport Menu",
          TextSize = 24,
          BackgroundColor3 = Color3.new(0, 0, 0),
          Position = UDim2.fromScale(0.5, 0.2),
          AnchorPoint = Vector2.new(0.5, 0.5),
          TextColor3 = Color3.new(255, 255, 255)
        }),
        World1Frame = Pract.create("Frame", {
          Position = UDim2.fromScale(0.5, 0.4),
          Size = UDim2.fromScale(0.2, 0.2),
          BackgroundColor3 = Color3.new(0, 0, 0),
          AnchorPoint = Vector2.new(0.5, 0.5)
        }, {
          Label = Pract.create("TextButton", {
            Text = "World 1",
            Size = UDim2.fromScale(1, 1),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundColor3 = Color3.new(0, 0, 0),
            TextColor3 = Color3.new(255, 255, 255),
            AnchorPoint = Vector2.new(0.5, 0.5),
            InputEnded = function(_, input: InputObject)
              if input.UserInputType == Enum.UserInputType.MouseButton1 then
                props.requestTeleportRemoteEvent:FireServer(1)
              end
            end
          })
        })
      })
    })
  else
    return Pract.create("ScreenGui", {ResetOnSpawn = false})
  end
end

--- Generate PractClassComponent
function NavMenuGui:generateClassComponent()
  return Pract.classComponent {
    init = function(cls)
      cls:setState {
        open = self._open,
        requestTeleportRemoteEvent = self._requestTeleportRemoteEvent
      }
      self.mounted = true
      task.spawn(function()
        repeat
          task.wait(1)
          cls:setState { open = self._open }
        until not self.mounted
      end)
    end,
    willUnmount = function(cls)
      self.mounted = false
    end,
    render = function(cls)
      return Pract.create(self.constructGui, {
        open = cls.state.open,
        requestTeleportRemoteEvent = cls.state.requestTeleportRemoteEvent
      })
    end
  }
end

function NavMenuGui:_onNavMenuOpenOrder(): nil
  self._open = true
  return nil
end

return NavMenuGui
