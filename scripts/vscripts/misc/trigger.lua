function OnEnterEnergyGate(trigger)
	local u = trigger.activator
	GameRules.holdOut:OnUnitEntersEnergyGate(u)
	--print("Cleansing Water")
end

function OnLeaveCleansingWater(trigger)
	local u = trigger.activator
	GameRules.holdOut:OnUnitLeavesCleansingWater(u)
end

function OnRadiantGoalEnter(trigger)
	print(trigger.activator)
	local u = trigger.activator
	GameRules.holdOut:OnUnitEntersGoal(u, DOTA_TEAM_GOODGUYS)
end

function OnRadiantTeleportLeft(event)
	local unit = event.activator
	local ent = Entities:FindByName( nil, "RadiantTeleportMarkLeft")
	local point = ent:GetAbsOrigin() 

	UnitTeleportToPosition(unit, point, true)
end

function OnRadiantTeleportLeftFar(event)
	local unit = event.activator
	local ent = Entities:FindByName( nil, "RadiantTeleportMarkLeftFar")
	local point = ent:GetAbsOrigin() 
	
	UnitTeleportToPosition(unit, point, true)
end

function OnRadiantTeleportRight(event)
	local unit = event.activator
	local ent = Entities:FindByName( nil, "RadiantTeleportMarkRight")
	local point = ent:GetAbsOrigin() 

	UnitTeleportToPosition(unit, point, true)
end

function OnRadiantTeleportRightFar(event)
	local unit = event.activator
	local ent = Entities:FindByName( nil, "RadiantTeleportMarkRightFar")
	local point = ent:GetAbsOrigin() 

	UnitTeleportToPosition(unit, point, true)
end


function TeleportStart(event)
	local unit = event.activator
	local teleporter = thisEntity
	local mark = Entities:FindByName(nil, teleporter:GetName() .. "Mark")
	local point = mark:GetAbsOrigin()
	local time = 2.75

	if unit.TeleportTime == nil then
		unit.TeleportTime = GameRules:GetGameTime() + time

		if unit.teleportApplier == nil then
			unit.teleportApplier = CreateItem("item_teleport_effect_applier", unit, unit)
		end

		unit.teleportApplier:ApplyDataDrivenModifier(unit, unit, "modifier_teleport_start_fx", {duration=time + 0.8})

		unit.teleportApplier:ApplyDataDrivenModifier(unit, unit, "modifier_teleport_end_fx", {duration=time + 0.8})
		unit:EmitSound("Portal.Loop_Appear")

		Timers:CreateTimer(function()
			if unit.TeleportTime == nil then
				Timers:CreateTimer(0.2, function()
					if unit.TeleportTime == nil then
						unit:RemoveModifierByName("modifier_teleport_start_fx")
						unit:RemoveModifierByName("modifier_teleport_end_fx")
						unit:StopSound("Portal.Loop_Appear")
					end
				end
				)
				return nil
			end

			if GameRules:GetGameTime() >= unit.TeleportTime then
				unit:StopSound("Portal.Loop_Appear")
				unit:EmitSound("Portal.Hero_Disappear")
				Timers:CreateTimer(0.1, function()
					UnitTeleportToPosition(unit, point, true)
				end
				)

				Timers:CreateTimer(0.5, function()
					unit:EmitSound("Portal.Hero_Appear")
				end
				)
				unit.TeleportTime = nil
				return nil
			else
				return 0.25
			end
		end
		)
	end
end


function TeleportEnd(event)
	local unit = event.activator

	unit.TeleportTime = nil
end


function BottleWaterEnter(event)
	local unit = event.activator
	local trigger = thisEntity
	
	print(trigger:GetName())
	
	--print(string.format("moonwellid: %d", moonwell))
	if unit ~= nil and unit:IsRealHero() then
		if trigger.Moonwell ~= nil then
			print("moonwell enter")
			trigger.Moonwell:AddBottleUnit(unit)
		end
	end
end

function BottleWaterLeave(event)
	local unit = event.activator
	local trigger = thisEntity
	
	if unit ~= nil and unit:IsRealHero() then
		if trigger.Moonwell ~= nil then
			print("moonwell leave")
			trigger.Moonwell:RemoveBottleUnit(unit)
		end
	end
end