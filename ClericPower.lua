-- Load MQ2 and ImGui libraries
local mq = require('mq')
local ImGui = require('ImGui')
local openGUI, drawGUI = true, true

local spell_routines = {}
spell_routines.Cast_Returns = {
    CAST_CANCELLED = 'CAST_CANCELLED',
    CAST_CANNOTSEE = 'CAST_CANNOTSEE',
    CAST_IMMUNE = 'CAST_IMMUNE',
    CAST_INTERRUPTED = 'CAST_INTERRUPTED',
    CAST_INVIS = 'CAST_INVIS',
    CAST_NOTARGET = 'CAST_NOTARGET',
    CAST_NOTMEMMED = 'CAST_NOTMEMMED',
    CAST_NOTREADY = 'CAST_NOTREADY',
    CAST_OUTOFMANA = 'CAST_OUTOFMANA',
    CAST_OUTOFRANGE = 'CAST_OUTOFRANGE',
    CAST_RESISTED = 'CAST_RESISTED',
    CAST_SUCCESS = 'CAST_SUCCESS',
    CAST_UNKNOWNSPELL = 'CAST_UNKNOWNSPELL',
    CAST_NOTHOLD = 'CAST_NOTHOLD'
}
spell_routines.Cast_Returns_Desc = {
    CAST_CANCELLED = 'Spell was cancelled by ducking (either manually or because mob died)',
    CAST_CANNOTSEE = 'You can\'t see your target',
    CAST_IMMUNE = 'Target is immune to this spell',
    CAST_INTERRUPTED = 'Casting was interrupted and exceeded the given time limit',
    CAST_INVIS = 'You were invis, and noInvis is set to true',
    CAST_NOTARGET = 'You don\'t have a target selected for this spell',
    CAST_NOTMEMMED = 'Spell is not memmed and you gem to mem was not specified',
    CAST_NOTREADY = 'AA ability or spell is not ready yet ',
    CAST_OUTOFMANA = 'You don\'t have enough mana for this spell!',
    CAST_OUTOFRANGE = 'Target is out of range',
    CAST_RESISTED = 'Your spell was resisted!',
    CAST_SUCCESS = 'Your spell was cast successfully! (yay)',
    CAST_UNKNOWNSPELL = 'Spell/Item/Ability was not found',
    CAST_NOTHOLD = 'Spell woundn\'t take hold on target'
}

local noInvis
local FollowFlag
local giveUpTimer
local ResistCounter
local PauseFlag

local noInterrupt = 0
local moveBack = false
local selfResist
local selfResistSpell
local castEndTime
local refreshTime
local itemRefreshTime
local spellNotHold

local function DoCastingEvents()
end
local function PauseFunction()
end
local function ItemCast(spellName, mySub)
end
local function AltCast(spellName, mySub)
end
local function SpellCast(spellType, spellName, spellGem, spellID, giveUpValue)
    if not mq.TLO.Me.Gem(spellName)() then
        if mq.TLO.Cursor.ID() then mq.cmd('/autoinventory') end
        if not mq.TLO.Me.Gem(spellName)() then mq.cmd('/memspell '.. spellGem .. ' '..  spellName) else return spell_routines.Cast_Returns.CAST_NOTMEMMED end
    end
end

spell_routines.Cast = function(spellName, spellGem, spellType, giveUpValue, ResistTotal)
    local castTime
    local castReturn
    local spellID

    if not castReturn then castReturn = spell_routines.Cast_Returns.CAST_CANCELLED end
    DoCastingEvents()
    castReturn = 'X'
    if mq.TLO.Me.Invis() and noInvis then return end
    if spellType == 'item' then
        if not mq.TLO.FindItem(spellName).ID() then return spell_routines.Cast_Returns.CAST_UNKNOWNSPELL end
        castTime = mq.TLO.FindItem(spellName).CastTime()
    elseif spellType == 'alt' then
        if not mq.TLO.Me.AltAbilityReady(spellName)() then return spell_routines.Cast_Returns.CAST_NOTREADY end
        castTime = mq.TLO.Me.AltAbility(spellName).Spell.CastTime()
    else
        if not mq.TLO.Me.Book(spellName)() then return spell_routines.Cast_Returns.CAST_NOTREADY end
        spellID = mq.TLO.Me.Book(spellName).ID()
        castTime = mq.TLO.Spell(spellName).CastTime()
        if mq.TLO.Me.CurrentMana() < mq.TLO.Spell(spellName).Mana() then return spell_routines.Cast_Returns.CAST_OUTOFMANA end
    end
    if castTime > 0.1 then
        mq.TLO.MoveUtils.MovePause()
        if FollowFlag then PauseFunction() end
        if mq.TLO.Me.Moving() then mq.cmd('/keypress back') end
    end
    if not spellType then spellType = 'spell' end
    if giveUpValue then giveUpTimer = giveUpValue end
    if ResistTotal then ResistCounter = ResistTotal end
    while mq.TLO.Me.Casting() or (not mq.TLO.Me.Class.ShortName() == 'BRD' and castTime > 0.1) do
        if mq.TLO.Me.Casting() then mq.delay(100) end
    end
    if mq.TLO.Window('SpellBookWnd').Open() then mq.cmd('/keypress spellbook') end
    if mq.TLO.Me.Ducking() then mq.cmd('/keypress duck') end
    if spellType == 'item' then ItemCast(spellName) end
    if spellType == 'alt' then AltCast(spellName) end
    if spellType ~= 'item' and spellType ~= 'alt' then SpellCast(spellType, spellName, spellGem, spellID, giveUpValue) end
    if PauseFlag then PauseFunction() end
    giveUpTimer = 0
    ResistCounter = 0
    return castReturn
end

-- Event Functions
Fizzled_Last_Spell = false
local function event_cast_fizzle()
    Fizzled_Last_Spell = true
end

-- MQ2 Events
mq.event('BeginCast', "You begin casting#*#", event_cast_fizzle)
mq.event('Collapse', "Your gate is too unstable, and collapses.#*#", event_cast_fizzle)
mq.event('FDFail', "#1# has fallen to the ground.#*#", event_cast_fizzle)
mq.event('Fizzle', "Your spell fizzles#*#", event_cast_fizzle)
mq.event('Immune1', "Your target is immune to changes in its attack speed#*#", event_cast_fizzle)
mq.event('Immune2', "Your target is immune to changes in its run speed#*#", event_cast_fizzle)
mq.event('Immune3', "Your target cannot be mesmerized#*#", event_cast_fizzle)
mq.event('Interrupt1', "Your casting has been interrupted#*#", event_cast_fizzle)
mq.event('Interrupt2', "Your spell is interrupted#*#", event_cast_fizzle)
mq.event('NoHold1', "Your spell did not take hold#*#", event_cast_fizzle)
mq.event('NoHold2', "Your spell would not have taken hold#*#", event_cast_fizzle)
mq.event('NoHold3', "You must first target a group member#*#", event_cast_fizzle)
mq.event('NoHold4', "Your spell is too powerful for your intended target#*#", event_cast_fizzle)
mq.event('NoLOS', "You cannot see your target.#*#", event_cast_fizzle)
mq.event('NoMount', "#*#You can not summon a mount here.#*#", event_cast_fizzle)
mq.event('NoTarget', "You must first select a target for this spell!#*#", event_cast_fizzle)
mq.event('NotReady', "Spell recast time not yet met.#*#", event_cast_fizzle)
mq.event('OutOfMana', "Insufficient Mana to cast this spell!#*#", event_cast_fizzle)
mq.event('OutOfRange', "Your target is out of range, get closer!#*#", event_cast_fizzle)
mq.event('Recover1', "You haven't recovered yet...#*#", event_cast_fizzle)
mq.event('Recover2', "Spell recovery time not yet met#*#", event_cast_fizzle)
mq.event('Resisted', "Your target resisted the #1# spell#*#", event_cast_fizzle)
mq.event('SelfResisted', "You resist the #1# spell#*#", event_cast_fizzle)
mq.event('Standing', "You must be standing to cast a spell#*#", event_cast_fizzle)
mq.event('Stunned', "You are stunned#*#", event_cast_fizzle)
mq.event('Stunned2', "You can't cast spells while stunned!#*#", event_cast_fizzle)
mq.event('Stunned3', "You *CANNOT* cast spells, you have been silenced!#*#", event_cast_fizzle)



-- Define constants
local CASTMODE = "MQ2Cast"

local HealGem1 = 1
local HealGem2 = 2
local HealGem3 = 3
local BuffGem1 = 4
local BuffGem2 = 5
local BuffGem3 = 6
local DebuffGem1 = 7
local DebuffGem2 = 8
local DebuffGem3 = 9
local BuffCheckTimer = 60
local RebuffTimer = 300


local spell_gems = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }

local function SetupGUI()
    if not ImGui then
      print("Error no imguiblah")
      return
     end
     if not drawGUI then return end
    local open, show = ImGui.Begin("clericpower", true, ImGuiWindowFlags.None)
    if not open then
        drawGUI = false
    end
    if drawGUI and show then
      ImGui.Text("Healing")
      HealGem1 = ImGui.Combo("Heal gem 1", HealGem1, spell_gems, #spell_gems, #spell_gems)
      HealGem2 = ImGui.Combo("Heal gem 2", HealGem2, spell_gems, #spell_gems, #spell_gems)
      HealGem3 = ImGui.Combo("Heal gem 3", HealGem3, spell_gems, #spell_gems, #spell_gems)
      ImGui.Text("Buffing")
      BuffGem1 = ImGui.Combo("Buff gem 1", BuffGem1, spell_gems, #spell_gems, #spell_gems)
      BuffGem2 = ImGui.Combo("Buff gem 2", BuffGem2, spell_gems, #spell_gems, #spell_gems)
      BuffGem3 = ImGui.Combo("Buff gem 3", BuffGem3, spell_gems, #spell_gems, #spell_gems)
      ImGui.Text("debuffing")
      DebuffGem1 = ImGui.Combo("debuff gem 1", DebuffGem1, spell_gems, #spell_gems, #spell_gems)
      DebuffGem2 = ImGui.Combo("debuff gem 2", DebuffGem2, spell_gems, #spell_gems, #spell_gems)
      DebuffGem3 = ImGui.Combo("debuff gem 3", DebuffGem3, spell_gems, #spell_gems, #spell_gems)
  --repeat for buff gems and debuff gems. you got this.
   end
   ImGui.End()
   
end 

function HealRoutine()
    if mq.TLO.Me.XTarget(1).ID() > 0 then
        mq.cmdf('/target id %d', mq.TLO.Me.XTarget(1).ID())
    end
    if mq.TLO.Target.ID() > 0 then
        if mq.TLO.Target.PctHPs() <= 80 then
            spell_routines.Cast(HealGem1, CASTMODE)
        end
        if mq.TLO.Target.PctHPs() <= 60 then
            spell_routines.Cast(HealGem2, CASTMODE)
        end
        if mq.TLO.Target.PctHPs() <= 35 then
            spell_routines.Cast(HealGem3, CASTMODE)
        end
    end
end

function BuffRoutine()
    if mq.TLO.Target.ID() > 0 then
        spell_routines.Cast(BuffGem1, CASTMODE)
        spell_routines.Cast(BuffGem2, CASTMODE)
        spell_routines.Cast(BuffGem3, CASTMODE)
    end
end

function DebuffRoutine()
    if mq.TLO.Target.ID() > 0 and mq.TLO.Target.TargetOfTarget() ~= nil then
        if mq.TLO.Target.TargetOfTarget.PctHPs() == 100 then
            mq.cmdf('/target id %d', mq.TLO.Target.TargetOfTarget.ID())
            spell_routines.Cast(DebuffGem1, CASTMODE)
            spell_routines.Cast(DebuffGem2, CASTMODE)
            spell_routines.Cast(DebuffGem3, CASTMODE)
            mq.cmdf('/target id %d', mq.TLO.Target.ID())
        end
    end
end

function CheckBuffs()
    if BuffCheckTimer <= 0 then
        if not mq.TLO.Me.Buff('BuffName1').ID() and RebuffTimer <= 0 then spell_routines.Cast(BuffGem1, CASTMODE) end
        if not mq.TLO.Me.Buff('BuffName2').ID() and RebuffTimer <= 0 then spell_routines.Cast(BuffGem2, CASTMODE) end
        if not mq.TLO.Me.Buff('BuffName3').ID() and RebuffTimer <= 0 then spell_routines.Cast(BuffGem3, CASTMODE) end
        BuffCheckTimer = 60
        RebuffTimer = 300
    end
end

function AutoRez()
    if mq.TLO.Target() ~= nil and mq.TLO.Target.Type() == 'Corpse' and mq.TLO.Me.AltAbilityReady('Blessings of Resurrection')() then
        spell_routines.Cast('Blessings of Resurrection', 'alt')
    end
end

function HandleDeath()
    mq.delay(5000)
    if mq.TLO.Me.Hovering() then
        mq.cmdf('/target id %d', mq.TLO.Target.ID())
        mq.delay(5000)
        if mq.TLO.Target.Distance() <= 70 then
            spell_routines.Cast('Blessings of Resurrection', 'alt')
        end
    end
end

function DragCorpse()
    -- use Target TLO since thats what you are naving to and not xtarget
      if mq.TLO.Target() ~= nil and mq.TLO.Target.Type() == 'Corpse' then
          mq.cmd('/nav target')
          local corpseLoc = mq.TLO.Target.Loc()
          while mq.TLO.Math.Distance(corpseLoc)() > 10 do
              mq.delay(10)
          end
          mq.cmd('/multiline : /corpsedrag, timed 5, /nav camp')
      end
  end

function StartCamp()
    if not mq.TLO.Me.Following() then
        SetCampLocation()
    end
end

function SetCampLocation()
    print("Setting camp location as the starting point.")
end

local function init()
    mq.imgui.init('GUI_Cleric', SetupGUI)
end

function Main()
    print("Starting Main function")
    SetupGUI()
    while drawGUI do
        HealRoutine()
        BuffRoutine()
        DebuffRoutine()
        CheckBuffs()
        AutoRez()
        DragCorpse()
        HandleDeath()
        mq.delay(100) -- Adjust delay as needed
    end
end
init()
StartCamp()
Main()
