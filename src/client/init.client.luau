local Players = game:GetService("Players")
local debugGui = require(Players.LocalPlayer.PlayerScripts.Client.DebugGui)()
local navMenuGui = require(Players.LocalPlayer.PlayerScripts.Client.NavMenuGui)()

debugGui:run()
navMenuGui:run()
