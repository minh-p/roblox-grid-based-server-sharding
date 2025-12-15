local Assert = require(game:GetService("ReplicatedStorage").Shared.Assert)
local RegionMath = require(game:GetService("ServerScriptService").Server.Region.RegionMath)

return {
  name = "RegionMath Tests",
  steps = {
    function()
      local regionMath = RegionMath(10, {0, 0})
      Assert.equal(regionMath.radius, 10, "RegionMath init failed: radius not set or incorrect")
      Assert.equal(regionMath.gridPos[1], 0, "RegionMath init failed: gridPosX not set or incorrect")
      Assert.equal(regionMath.gridPos[2], 0, "RegionMath init failed: gridPosY not set or incorrect")
    end,
    function()
      -- Testing getFractionalAxisHex
      -- Exact center
      local regionMath = RegionMath(10, {0, 0})
      -- Center
      local result = regionMath:getFractionalAxisHex(0, 0)
      Assert.near(result.q, 0.0000)
      Assert.near(result.r, 0.0000)
      
      -- Pure X movement (z = 0)
      result = regionMath:getFractionalAxisHex(10, 0)
      Assert.near(result.q, 0.5774)
      Assert.near(result.r, 0.0000)
      
      result = regionMath:getFractionalAxisHex(-10, 0)
      Assert.near(result.q, -0.5774)
      Assert.near(result.r, 0.0000)
      
      -- Pure Z movement (x = 0)
      result = regionMath:getFractionalAxisHex(0, 10)
      Assert.near(result.q, -0.3333)
      Assert.near(result.r, 0.6667)
      
      result = regionMath:getFractionalAxisHex(0, -10)
      Assert.near(result.q, 0.3333)
      Assert.near(result.r, -0.6667)
      
      -- Diagonal-ish
      result = regionMath:getFractionalAxisHex(-8, 10)
      Assert.near(result.q, -0.7952)
      Assert.near(result.r, 0.6667)
      
      result = regionMath:getFractionalAxisHex(8, 10)
      Assert.near(result.q, 0.1285)
      Assert.near(result.r, 0.6667)
      
      result = regionMath:getFractionalAxisHex(-8, -10)
      Assert.near(result.q, -0.1285)
      Assert.near(result.r, -0.6667)
      
      result = regionMath:getFractionalAxisHex(8, -10)
      Assert.near(result.q, 0.7952)
      Assert.near(result.r, -0.6667)
      
      -- Interior sanity checks
      result = regionMath:getFractionalAxisHex(3, 4)
      Assert.near(result.q, 0.0399)  -- (sqrt3/3*0.3) - (1/3*0.4) ≈ 0.0399
      Assert.near(result.r, 0.2667)
      
      result = regionMath:getFractionalAxisHex(-4, 2)
      Assert.near(result.q, -0.2976) -- (sqrt3/3*-0.4) - (1/3*0.2) ≈ -0.2976
      Assert.near(result.r, 0.1333)
      
      result = regionMath:getFractionalAxisHex(5, 5)
      Assert.near(result.q, 0.1220)  -- (sqrt3/3*0.5) - (1/3*0.5) ≈ 0.1220
      Assert.near(result.r, 0.3333)

      -- Boundary stress test
      local z = 5 * math.sqrt(3) -- ≈ 8.660254...
      
      result = regionMath:getFractionalAxisHex(-5, z)
      Assert.near(result.q, -0.5774)
      Assert.near(result.r, 0.5774)
      
      result = regionMath:getFractionalAxisHex(5, z)
      Assert.near(result.q, 0.0000)
      Assert.near(result.r, 0.5774)
    end,
  }
}
