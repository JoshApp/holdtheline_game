require( "ai_core" )

if BossTreant == nil then
	BossTreant = class({})
end

behaviorSystem = {} -- create the global so we can assign to it

testcount = 0
scoreshowed = false
entBossUnit = nil
fBossArenaDesire = 0.0
entBossArena = nil
fBossArenaRange = 900.0
strBossArenaName = "bossarena1"
bossTimePhase3 = 10

vecBossArenaPos = nil

function BossTreant:Init(handler, gameRound)
	self._bossHandler = handler
	self._gameRound = gameRound
	self._strBossUnit = "boss_treant" 
	self._strSpawner = "spawnerBoss"
	self._strRoundTitle = "Boss Treant"
	self._nPhase = 1
	entBossUnit = nil
	self.bFreezeBoss = false
	self.bLocReached = false
	self.bPhaseSwitch = true
	--self.abilityPhase2 = "boss_treant_phase_2"
	self.bOrbLeftReachedGoal = false
	self.bOrbRightReachedGoal = false
	
	self:SetArena()

	print("bosshandlerinit")
	print(fBossArenaDesire)
end

function BossTreant:SetArena()
	entBossArena = Entities:FindByName(nil, strBossArenaName)
	print(strBossArenaName)
	if entBossArena ~= nil then
		print ("bossarenafound")
		vecBossArenaPos = entBossArena:GetOrigin()
		vecBossArenaPos.z = 0
	end
end


function BossTreant:Begin()
	print("begin")
	self:Spawn()
end


function BossTreant:Prepare()
	print("prepare")
	PrecacheUnitByNameAsync( self._strBossUnit, function( sg ) self._sg = sg end )
end


function BossTreant:Spawn()
	print("spawn")
	local entSpawner = Entities:FindByName( nil, self._strSpawner)
	local vecSpawnLocation = nil
	
	if not entSpawner then
			print( string.format( "Failed to find spawner named %s" , self._strSpawner) )
	end
	
	vecSpawnLocation = entSpawner:GetAbsOrigin()
	entBossUnit = CreateUnitByName( self._strBossUnit, vecSpawnLocation, true, nil, nil, DOTA_TEAM_BADGUYS )
	self._bossOriginalHealth = entBossUnit:GetMaxHealth()
	entBossUnit.difficultyApplier = nil
	self:ApplyDifficultyBuff(entBossUnit)
	behaviorSystem = AICore:CreateBehaviorSystem( { BehaviorMoveToArena, BehaviorAttack, BehaviorIdle } ) --( { BehaviorRootHero, BehaviorSpawnFlowers, BehaviorSpawnMushrooms, BehaviorSpawnTrees, BehaviorRaiseNature, BehaviorMoveToArena, BehaviorAttack } )
	
	self._entQuest = SpawnEntityFromTableSynchronous( "quest", {
		name = self._strRoundTitle,
		title =  self._strRoundTitle
	})
	self._entQuest:SetTextReplaceValue( QUEST_TEXT_REPLACE_VALUE_ROUND, 1 )
	--self._entQuest:SetTextReplaceString( self._gameMode:GetDifficultyString() )
	
	self._entKillCountSubquest = SpawnEntityFromTableSynchronous( "subquest_base", {
		show_progress_bar = true,
		progress_bar_hue_shift = -119
	} )
	self._entQuest:AddSubquest( self._entKillCountSubquest )
	self._entKillCountSubquest:SetTextReplaceValue( SUBQUEST_TEXT_REPLACE_VALUE_TARGET_VALUE, entBossUnit:GetMaxHealth())
	
end

function BossTreant:UpdateBossDifficulty()
	self:ApplyDifficultyBuff(entBossUnit)
end

function BossTreant:ApplyDifficultyBuff(u)
	local nDifficultyStacks = self._gameRound._gameMode._entAncient:GetMana()
	if u.difficultyApplier == nil then
		local difficultyApplier = CreateItem("item_boss_difficulty_modifier_applier", u, u)
		u.difficultyApplier = difficultyApplier
		difficultyApplier:ApplyDataDrivenModifier(u, u, "modifier_boss_difficulty_passive", {duration=-1})
	end
	
	u:SetModifierStackCount("modifier_boss_difficulty_passive", nil, nDifficultyStacks)
	local hpPercent = u:GetHealth() / u:GetMaxHealth()
	u:SetMaxHealth(self._bossOriginalHealth * (1 + nDifficultyStacks / 100))
	u:SetHealth(u:GetMaxHealth() * hpPercent)
	--entBossUnit:AddNewModifier(entBossUnit, nil, "modifier_boss_difficulty" ,nil)
	--entBossUnit:SetModifierStackCount("modifier_boss_difficulty", nil, nDifficultyStacks)
end

function SetPhasing(unit, bool)
	if bool then
		local phasingApplier = CreateItem("item_phasing_applier", unit, unit)
		phasingApplier:ApplyDataDrivenModifier(unit, unit, "modifier_phasing_passive", {duration=-1})
	else
		unit:RemoveModifierByName("modifier_phasing_passive")
	end
end


function BossTreant:End()
	if self._sg ~= nil then
		UnloadSpawnGroupByHandle( self._sg )
		self._sg = nil
	end
end


function BossTreant:Think()

	if entBossUnit:IsAlive() or not entBossUnit:IsNull() then
		
		self:AIThink()
		
		if testcount == 5 and entBossUnit:GetHealth() >= entBossUnit:GetMaxHealth()/2 then
			entBossUnit:SetHealth(entBossUnit:GetMaxHealth()/2)
			GameRules:SetRuneSpawnTime(testcount)
			
		end
	
		if self._entKillCountSubquest then
			self._entKillCountSubquest:SetTextReplaceValue( QUEST_TEXT_REPLACE_VALUE_CURRENT_VALUE, entBossUnit:GetHealth())
		end
	 
		testcount = testcount + 1
		
	else
		if not scoreshowed then
			self:ShowScoreboard()
			scoreshowed = true
		end
	end
end


function BossTreant:ShowScoreboard()
	local roundEndSummary = {
		nRoundNumber = 1,
		nRoundDifficulty = 1,
		roundName = self._strRoundTitle,
		nTowers = 0,
		nTowersStanding = 0,
		nTowersStandingGoldReward = 0,
		nGoldBagsExpired = 0
	}

	local playerSummaryCount = 0
		
	for i = 1, DOTA_MAX_TEAM_PLAYERS do
		local nPlayerID = i-1
			
		if PlayerResource:HasSelectedHero( nPlayerID ) then
			local szPlayerPrefix = string.format( "Player_%d_", playerSummaryCount)
			playerSummaryCount = playerSummaryCount + 1
			roundEndSummary[ szPlayerPrefix .. "HeroName" ] = PlayerResource:GetSelectedHeroName( nPlayerID )
			roundEndSummary[ szPlayerPrefix .. "CreepKills" ] = 1
			roundEndSummary[ szPlayerPrefix .. "GoldBagsCollected" ] = 1
			roundEndSummary[ szPlayerPrefix .. "Deaths" ] = 0
			roundEndSummary[ szPlayerPrefix .. "PlayersResurrected" ] = 0
		end
			
	end
		
	FireGameEvent( "holdout_show_round_end_summary", roundEndSummary )	
end


function BossTreant:IsFinished()
end


function BossTreant:PhaseThink()
		print (string.format( "phasethink: %d", self._nPhase))
		
	if self._nPhase == 1 then
		if self._fBossHpPercent <= 0.66 then
			self._nPhase = 2
		end
		
		print("phase1think")
		
		local bossPos = entBossUnit:GetAbsOrigin()
		bossPos.z = 0
		
		local distArena = ( vecBossArenaPos - bossPos ):Length()
		print (string.format( "dist arena: %d", distArena))
		local distDiff = distArena - fBossArenaRange
		print (string.format( "dist diff: %d", distDiff))
		print(distDiff)
		
		if distDiff > 0 then
			fBossArenaDesire = 5.0 + 0.01 * distDiff
			print("distdiff > 0")
		else
			fBossArenaDesire = 0.0
		end
	elseif self._nPhase == 2 then
	
		if self.bPhaseSwitch then
			self.bFreezeBoss = true
			SetPhasing(entBossUnit, true)
			entBossUnit:AddNewModifier( entBossUnit, nil, "modifier_invulnerable", {} )
			self.bLocReached = false
			self.bPhaseSwitch = false
		end
		
		print("Phase2")
		if self.bLocReached == false then
		print("moving in position")
		
		
		
			local order =
				{
					UnitIndex = entBossUnit:entindex(),
					OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
				Position = vecBossArenaPos,
				}
			ExecuteOrderFromTable( order )
			
			local bossPos = entBossUnit:GetAbsOrigin()
			bossPos.z = 0
		
			local distArena = ( vecBossArenaPos - bossPos ):Length()
			
			if distArena <= 10 then
				self.bLocReached = true
				--entBossUnit:AddAbility(self.abilityPhase2)
				--[[local ability = entBossUnit:FindAbilityByName(self.abilityPhase2)
				print(ability)
				local order =
				{
					UnitIndex = entBossUnit:entindex(),
					OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
					AbilityIndex = ability:entindex(),
				}]]
				local bossMaxHP = entBossUnit:GetMaxHealth()
				local orbHP = bossMaxHP * 0.1
				ExecuteOrderFromTable( order )
				self.entOrbLeft = CreateUnitByName( "treant_phase_2_orb", entBossUnit:GetOrigin() + Vector(-100, 200, 0), true, nil, nil, entBossUnit:GetTeamNumber() )
				SetPhasing(self.entOrbLeft, true)
				self.entOrbLeft:SetMaxHealth(orbHP)
				self.entOrbLeft:SetHealth(orbHP)
				self.entOrbRight = CreateUnitByName( "treant_phase_2_orb", entBossUnit:GetOrigin() + Vector(100, 200, 0), true, nil, nil, entBossUnit:GetTeamNumber() )
				SetPhasing(self.entOrbRight, true)
				self.entOrbRight:SetMaxHealth(orbHP)
				self.entOrbRight:SetHealth(orbHP)
				
				entBossUnit:RemoveModifierByName("modifier_invulnerable")
				entBossUnit:SetHealth(entBossUnit:GetHealth() - orbHP * 2)
				entBossUnit:AddNewModifier( entBossUnit, nil, "modifier_invulnerable", {} )
				
				local shield_size = 150
				
				local entWp = Entities:FindByName(nil, "path_invader1_4")
				self.entOrbLeft:SetInitialGoalEntity( entWp)
				self.entOrbLeft:SetMustReachEachGoalEntity(false)
				
				
				self.entOrbLeft.particle = ParticleManager:CreateParticle( "particles/units/heroes/hero_abaddon/abaddon_aphotic_shield.vpcf", PATTACH_ABSORIGIN_FOLLOW, self.entOrbLeft )
				ParticleManager:SetParticleControl(self.entOrbLeft.particle, 1, Vector(shield_size,0,shield_size))
				ParticleManager:SetParticleControl(self.entOrbLeft.particle, 2, Vector(shield_size,0,shield_size))
				ParticleManager:SetParticleControl(self.entOrbLeft.particle, 4, Vector(shield_size,0,shield_size))
				ParticleManager:SetParticleControl(self.entOrbLeft.particle, 5, Vector(shield_size,0,0))
				ParticleManager:SetParticleControlEnt(self.entOrbLeft.particle, 0, self.entOrbLeft, PATTACH_POINT_FOLLOW, "attach_hitloc", self.entOrbLeft:GetAbsOrigin(), true)
				
				
				entWp = Entities:FindByName(nil, "path_invader2_4")
				self.entOrbRight:SetInitialGoalEntity( entWp)
				self.entOrbRight:SetMustReachEachGoalEntity(false)
				
				self.entOrbRight.particle = ParticleManager:CreateParticle( "particles/units/heroes/hero_abaddon/abaddon_aphotic_shield.vpcf", PATTACH_ABSORIGIN_FOLLOW, self.entOrbRight )
				ParticleManager:SetParticleControl(self.entOrbRight.particle, 1, Vector(shield_size,0,shield_size))
				ParticleManager:SetParticleControl(self.entOrbRight.particle, 2, Vector(shield_size,0,shield_size))
				ParticleManager:SetParticleControl(self.entOrbRight.particle, 4, Vector(shield_size,0,shield_size))
				ParticleManager:SetParticleControl(self.entOrbRight.particle, 5, Vector(shield_size,0,0))
				ParticleManager:SetParticleControlEnt(self.entOrbRight.particle, 0, self.entOrbRight, PATTACH_POINT_FOLLOW, "attach_hitloc", self.entOrbRight:GetAbsOrigin(), true)
				
				strBossArenaName = "bossarena2"
				self:SetArena()
			end
		end
		
		if self.bLocReached then
			print("reached position")
			
			local orbDistArenaLeft
			local orbDistArenaRight
			
			local orbHPPool = 0
			
			if not self.bOrbLeftReachedGoal or self.entOrbLeft:IsAlive() or not self.entOrbLeft:IsNull() then
				local orbPos
				local orbHP
				
				orbPos = self.entOrbLeft:GetAbsOrigin()
				orbPos.z = 0
		
				orbDistArenaLeft = ( vecBossArenaPos - orbPos):Length()
				orbHP = self.entOrbLeft:GetHealth()
				orbHPPool = orbHPPool + orbHP
				
				if orbDistArenaLeft <= 900 then
					print("setleftarenagoal")
					self.bOrbLeftReachedGoal = true
				end
				
			else
				orbDistArenaLeft = 0
			end
			
			if not self.bOrbRightReachedGoal or self.entOrbRight:IsAlive() or not self.entOrbRight:IsNull() then
				local orbPos
				local orbHP
				
				orbPos = self.entOrbRight:GetAbsOrigin()
				orbPos.z = 0
		
				orbDistArenaRight = ( vecBossArenaPos - orbPos ):Length()
				
				orbHP = self.entOrbRight:GetHealth()
				orbHPPool = orbHPPool + orbHP
				
				if orbDistArenaRight <= 900 then
					print("setrightarenagoal")
					self.bOrbRightReachedGoal = true
				end
			else
				orbDistArenaRight = 0
			end
			
			print(orbDistArenaRight)
			print(orbDistArenaLeft)
		
			if self.bOrbLeftReachedGoal and self.bOrbRightReachedGoal then
				print("orbs rached arena 2")
				self._nPhase = 3
				entBossUnit:SetHealth(entBossUnit:GetHealth() + orbHPPool)
				
				if self.entOrbLeft:IsAlive() or not self.entOrbLeft:IsNull() then
					UTIL_RemoveImmediate(self.entOrbLeft)
				end
				
				if self.entOrbRight:IsAlive() or not self.entOrbRight:IsNull() then
					UTIL_RemoveImmediate(self.entOrbRight)
				end
				
				local point = entBossArena:GetAbsOrigin()
				entBossUnit:SetAbsOrigin(point)
				FindClearSpaceForUnit(entBossUnit, point, false)
				entBossUnit:Stop()
				
				entBossUnit:RemoveModifierByName("modifier_invulnerable")
				self.bFreezeBoss = false
			end

		end
		
	elseif self._nPhase == 3 then
		print("phase 3 think")
		local ancient = self._gameRound._gameMode._entAncient
		local vecAncientPos = ancient:GetOrigin()
		vecAncientPos.z = 0
		local distToAncient = (vecAncientPos - vecBossArenaPos):Length()
		local distIncr = distToAncient / bossTimePhase3 * 0.25
		
		vecBossArenaPos = vecBossArenaPos + Vector(0, distIncr, 0)
	end
end


function BossTreant:GetDistanceFromPos(vec)
	local bossPos = entBossUnit:GetAbsOrigin()
	bossPos.z = 0
		
	return ( vec - bossPos ):Length()

end

 
function BossTreant:AIThink()
	self._fBossHpPercent = entBossUnit:GetHealth() / entBossUnit:GetMaxHealth()
	
	self:PhaseThink()
	print (string.format( "phase: %d", self._nPhase))
	
	if not self.bFreezeBoss then
		behaviorSystem:Think()
	end
	
end


--------------------------------------------------------------------------------------------------------





--------------------------------------------------------------------------------------------------------


BehaviorRootHero = {}

function BehaviorRootHero:Evaluate()
	self.ability = entBossUnit:FindAbilityByName("treant_root_hero")
	local target
	local desire = 0
	
	if self.ability and self.ability:IsFullyCastable() then
		local allEnemies = FindUnitsInRadius( entBossUnit:GetTeamNumber(), entBossUnit:GetOrigin(), nil, 700.0, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, 0, 0, false )
		if #allEnemies > 0 then
			target = allEnemies[RandomInt( 1, #allEnemies )]
		end
	end

	if target then
		desire = 4
		self.order =
		{
			OrderType = DOTA_UNIT_ORDER_CAST_TARGET,
			UnitIndex = entBossUnit:entindex(),
			TargetIndex = target:entindex(),
			AbilityIndex = self.ability:entindex()
		}
	end
	print (string.format( "root Desire: %d", desire))
	return desire
end


function BehaviorRootHero:Begin()
	self.endTime = GameRules:GetGameTime() + 2
end

BehaviorRootHero.Continue = BehaviorRootHero.Begin --if we re-enter this ability, we might have a different target; might as well do a full reset

function BehaviorRootHero:Think(dt)
	if not self.ability:IsFullyCastable() and not self.ability:IsInAbilityPhase() then
		self.endTime = GameRules:GetGameTime()
	end
end


--------------------------------------------------------------------------------------------------------


BehaviorSpawnFlowers = {}

function BehaviorSpawnFlowers:Evaluate()
	self.ability = entBossUnit:FindAbilityByName("treant_spawn_flowers")
	local desire = 0
	
	if self.ability and self.ability:IsFullyCastable() then
		desire = 2
		self.order =
		{
			OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
			UnitIndex = entBossUnit:entindex(),
			AbilityIndex = self.ability:entindex()
		}
		print (string.format( "flowers Desire: %d", desire))
	end
	return desire
end


function BehaviorSpawnFlowers:Begin()
	self.endTime = GameRules:GetGameTime() + 1
end

BehaviorSpawnFlowers.Continue = BehaviorSpawnFlowers.Begin --if we re-enter this ability, we might have a different target; might as well do a full reset

function BehaviorSpawnFlowers:Think(dt)
	if not self.ability:IsFullyCastable() and not self.ability:IsInAbilityPhase() then
		self.endTime = GameRules:GetGameTime()
	end
end


--------------------------------------------------------------------------------------------------------


BehaviorSpawnMushrooms = {}

function BehaviorSpawnMushrooms:Evaluate()
	self.ability = entBossUnit:FindAbilityByName("treant_spawn_mushrooms")
	local desire = 0
	
	if self.ability and self.ability:IsFullyCastable() then
	desire = 3
		self.order =
		{
			OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
			UnitIndex = entBossUnit:entindex(),
			AbilityIndex = self.ability:entindex()
		}
	
	print (string.format( "mushroom Desire: %d", desire))
	end
	return desire
end


function BehaviorSpawnMushrooms:Begin()
	self.endTime = GameRules:GetGameTime() + 1
end

BehaviorSpawnMushrooms.Continue = BehaviorSpawnMushrooms.Begin --if we re-enter this ability, we might have a different target; might as well do a full reset

function BehaviorSpawnMushrooms:Think(dt)
	if not self.ability:IsFullyCastable() and not self.ability:IsInAbilityPhase() then
		self.endTime = GameRules:GetGameTime()
	end
end


--------------------------------------------------------------------------------------------------------


BehaviorSpawnTrees = {}

function BehaviorSpawnTrees:Evaluate()
	self.ability = entBossUnit:FindAbilityByName("treant_spawn_trees")
	local desire = 0
	
	if self.ability and self.ability:IsFullyCastable() then
	desire = 1
		self.order =
		{
			OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
			UnitIndex = entBossUnit:entindex(),
			AbilityIndex = self.ability:entindex()
		}
		print (string.format( "tree Desire: %d", desire))
	end
	return desire
end


function BehaviorSpawnTrees:Begin()
	self.endTime = GameRules:GetGameTime() + 1
end

BehaviorSpawnTrees.Continue = BehaviorSpawnTrees.Begin --if we re-enter this ability, we might have a different target; might as well do a full reset

function BehaviorSpawnTrees:Think(dt)
	if not self.ability:IsFullyCastable() and not self.ability:IsInAbilityPhase() then
		self.endTime = GameRules:GetGameTime()
	end
end


--------------------------------------------------------------------------------------------------------


BehaviorRaiseNature = {}

function BehaviorRaiseNature:Evaluate()
	self.ability = entBossUnit:FindAbilityByName("treant_raise_nature")
	local desire = 0
	
	if self.ability and self.ability:IsFullyCastable() then
		local allTargets = FindUnitsInRadius( entBossUnit:GetTeamNumber(), entBossUnit:GetOrigin(), nil, 700.0, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL, 0, 0, false )
		for n, u in pairs(allTargets) do
			local uName = u:GetUnitName()
			if not (uName == "treant_flower" or uName == "treant_mushroom" or uName == "ent_dota_tree" or uName == "dota_temp_tree") then
				table.remove(allTargets, n)
			end
		end
		desire = 1 * #allTargets

		self.order =
		{
			OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
			UnitIndex = entBossUnit:entindex(),
			AbilityIndex = self.ability:entindex()
		}
		print (string.format( "raise Desire: %d", desire))
	end
	return desire
end


function BehaviorRaiseNature:Begin()
	self.endTime = GameRules:GetGameTime() + 2
end

BehaviorRaiseNature.Continue = BehaviorRaiseNature.Begin --if we re-enter this ability, we might have a different target; might as well do a full reset

function BehaviorRaiseNature:Think(dt)
	if not self.ability:IsFullyCastable() and not self.ability:IsInAbilityPhase() then
		self.endTime = GameRules:GetGameTime()
	end
end


--------------------------------------------------------------------------------------------------------


BehaviorMoveToArena = {}

function BehaviorMoveToArena:Evaluate()
	local desire = 0
	desire = fBossArenaDesire
	print (string.format( "arenadesire: %d", fBossArenaDesire))
	if desire > 0 then
		self.order =
		{
			UnitIndex = entBossUnit:entindex(),
			OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
			Position = vecBossArenaPos,
		}
		print (string.format( "move to arena Desire: %d", desire))
	end
	return desire
end


function BehaviorMoveToArena:Begin()
	self.endTime = GameRules:GetGameTime() + 0.9
end

BehaviorMoveToArena.Continue = BehaviorMoveToArena.Begin --if we re-enter this ability, we might have a different target; might as well do a full reset

function BehaviorMoveToArena:Think(dt)

end


--------------------------------------------------------------------------------------------------------


BehaviorAttack = {}

function BehaviorAttack:Evaluate()
	local desire = 0
	
	local target = AICore:WeakestEnemyHeroInRange( entBossUnit, 700 )
	
	if target ~= nil then
		desire = 0.5
		self.order =
		{
			UnitIndex = entBossUnit:entindex(),
			OrderType = DOTA_UNIT_ORDER_ATTACK,
			TargetEntindex = target:entindex(),
		}
		print (string.format( "attack desire: %d", desire))
	end
	return desire
end


function BehaviorAttack:Begin()
	self.endTime = GameRules:GetGameTime() + 0.9
end

BehaviorAttack.Continue = BehaviorAttack.Begin --if we re-enter this ability, we might have a different target; might as well do a full reset

function BehaviorAttack:Think(dt)

end
--------------------------------------------------------------------------------------------------------


BehaviorIdle = {}

function BehaviorIdle:Evaluate()
	local desire = 0.1
	
	print (string.format( "idle desire: %d", desire))
		self.order =
		{
			UnitIndex = entBossUnit:entindex(),
			OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
			Position = vecBossArenaPos + Vector(RandomInt(-(fBossArenaRange), fBossArenaRange), RandomInt(-(fBossArenaRange), fBossArenaRange) , 0),
		}
	return desire
end


function BehaviorIdle:Begin()
	self.endTime = GameRules:GetGameTime() + 0.9
end

BehaviorIdle.Continue = BehaviorIdle.Begin --if we re-enter this ability, we might have a different target; might as well do a full reset

function BehaviorIdle:Think(dt)

end