function _OnInit()
    if GAME_ID == 0xF266B00B or GAME_ID == 0xFAF99301 and ENGINE_TYPE == "ENGINE" then--PCSX2
        Platform = 'PS2'
        Now = 0x032BAE0 --Current Location
        Save = 0x032BB30 --Save File
        Obj0 = 0x1C94100 --00objentry.bin
        Sys3 = 0x1CCB300 --03system.bin
        Btl0 = 0x1CE5D80 --00battle.bin
        Slot1 = 0x1C6C750 --Unit Slot 1
    elseif GAME_ID == 0x431219CC and ENGINE_TYPE == 'BACKEND' then--PC
        Platform = 'PC'
        Now = 0x0714DB8 - 0x56454E
        Save = 0x09A7070 - 0x56450E
        Obj0 = 0x2A22B90 - 0x56450E
        Sys3 = 0x2A59DB0 - 0x56450E
        Btl0 = 0x2A74840 - 0x56450E
        Slot1 = 0x2A20C58 - 0x56450E
    end
    -- limits and magic offsets taken from https://github.com/1234567890num/KH2FM-Plando-Useful-Codes/wiki/MP-Costs-(CMD)
    limitMPCostOff = {0x7E50, 0x7D30, 0x7C10, 0x7DC0, 0x0E30, 0x0FB0, 0x1940, 0x2E10, 0x3320, 0x3D40, 0x3E60, 0x3F80, 0x40A0, 0x4430, 0x49A0, 0x4B80, 0x5840, 0x67D0}
    -- Ideally the base costs would be read from the sys3 on startup, but while testing it seems like the lua starts before sys3 is loaded
    baseLimitCost = {0x41,0x3C,0x50,0x48,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF}
    magicMPCostOff = {0x09E0, 0x15E0, 0x1610, 0x0A40, 0x1640, 0x1670, 0x0A10, 0x16A0, 0x16D0, 0x0A70, 0x1700, 0x1730, 0x1F40, 0x1F70, 0x1FA0, 0x1FD0, 0x2000, 0x2030}
    baseMagicCost = {0x0C,0x0C,0x0C,0x0F,0x0F,0x0F,0x12,0x12,0x12,0xFF,0xFF,0xFF,0x1E,0x1E,0x1E,0x0A,0x0A,0x0A}
    -- Run speed offsets taken from https://github.com/1234567890num/KH2FM-Plando-Useful-Codes/wiki/Other-Stats
    moveSpeedOff = {0x17CE4, 0x17D18, 0x17D4C, 0x17D80, 0x17DB4, 0x17E1C, 0x17DE8, 0x17E50, 0x18190, 0x181F8, 0x1822C, 0x18364, 0x18058}
    baseMoveSpeed = {8,12,12,10,16,18,16,7,20,8,8,8,8}
    -- glide speed is in fmab entries in sys3 see https://openkh.dev/kh2/file/type/preferences.html
    glideSpeedOff = {0x17A90, 0x17AD4, 0x17B18, 0x17B5C, 0x17BA0}
    baseGlideSpeed = {16, 20, 24, 32, 64}
    --offsets taken from https://github.com/1234567890num/KH2FM-Plando-Useful-Codes/wiki/Drive-Forms-&-Summons
    driveCostOff = {0x03E0, 0x0410, 0x7A30, 0x04A0, 0x04D0, 0x0500, 0x5180, 0x10A0, 0x1070, 0x37A0, 0x6440, 0x6470, 0x7A60, 0x64A0, 0x64D0}
    driveBaseCost = {3,3,4,4,5,9,3,3,3,3,3,3,4,4,5}
    driveDiscount = {0, 1, 2, 3, 3, 4, 5}
    maxMPOff = 0x184
    valOff = 0x32F6
    wisOff = 0x332E
    mastOff = 0x339E
    finOff = 0x33D6
    limOff = 0x3366
    --I would prefer offsets, but I don't know how these values was derived in the first place as I took it from one of TheNja09's mods
    drawMemoryPos = 0x24BC952
    --was using this to check abilities, but don't need it
    --soraStatsOff = 0x24F0
    --Values I want to track over multiple ticks
    lMasterLevel = -1
    drawRange = -1
    dbgV1 = -1
end
function applyMPDiscount(baseCost, formLevel, maxMP, memoryPos)
  local costMod = 1 - ((formLevel - 1) * 0.08333333333333)
  if baseCost == 0xFF then
    costMod = (maxMP*costMod)/255.0 --255 is 0xFF but need it in a float format to prevent rounding
  end
  WriteByte(memoryPos, math.max(1, math.floor(costMod * baseCost)))
end

function _OnFrame()
  local valorLevel = ReadByte(Save+valOff)
  local wisdomLevel = ReadByte(Save+wisOff)
  local masterLevel = ReadByte(Save+mastOff)
  local finalLevel = ReadByte(Save+finOff)
  local limitLevel = ReadByte(Save+limOff)
  local maxMP = ReadByte(Slot1+maxMPOff)
  local itemDraw = ReadFloat(drawMemoryPos)
  -- reduce limit costs based on limit form level
  for idx, mpCost in pairs(baseLimitCost) do
    applyMPDiscount(mpCost, limitLevel, maxMP, Sys3+limitMPCostOff[idx])
  end

  -- reduce magic costs based on wisdom form level
  for idx, mpCost in pairs(baseMagicCost) do
    applyMPDiscount(mpCost, wisdomLevel, maxMP, Sys3+magicMPCostOff[idx])
  end
  
  --Valor improves movement speed
  for idx, baseSpeed in pairs(baseMoveSpeed) do
    WriteFloat(Sys3+moveSpeedOff[idx], baseSpeed+((valorLevel-1)*4))
  end
  for idx, baseSpeed in pairs(baseGlideSpeed) do
    WriteFloat(Sys3+glideSpeedOff[idx], baseSpeed+((valorLevel-1)*8))
  end

  --Gain a level of draw for every level of master
  --by updating the value when it changes I can get how much draw the player has from abilities
  if drawRange ~= itemDraw or lMasterLevel ~= masterLevel then
    lMasterLevel = masterLevel
    itemDraw = itemDraw+((masterLevel-1) * 125.0)
    drawRange = itemDraw
    WriteFloat(drawMemoryPos, itemDraw)
  end

  --Drive form discount from final form
  for idx, cost in pairs(driveBaseCost) do
    WriteByte(Sys3+driveCostOff[idx], math.max(0, (cost-driveDiscount[math.min(7, finalLevel)])))
  end
  
end
