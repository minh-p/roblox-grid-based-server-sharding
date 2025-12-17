local RegionManager = require(script.Region.RegionManager)

-- Create pointy top hexagon
local radius = 100
local center = Vector3.new(0, 0, 0)

local vertices = table.create(6)

for i = 0, 5 do
  local angle = math.rad(60 * i + 30)
  vertices[i + 1] = center + Vector3.new(radius * math.cos(angle), 0, radius * math.sin(angle))
end

local edges = {}
for i = 1, 6 do
  table.insert(edges, {a = vertices[i], b = vertices[(i % 6) + 1]})
end


hexagonModel = Instance.new("Model")
for _, edge in edges do
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(0, 170, 255)

    local length = (edge.b - edge.a).Magnitude
    part.Size = Vector3.new(1, 1, length)
    part.CFrame = CFrame.lookAt((edge.a + edge.b) / 2, edge.b)

    part.Parent = hexagonModel

end
hexagonModel.Parent = workspace

local regionManager = RegionManager()
regionManager:run()
