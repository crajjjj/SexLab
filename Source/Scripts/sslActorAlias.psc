scriptname sslActorAlias extends ReferenceAlias
{
	Alias Script for Actors which are animated by a SexLab Thread
	There is no reason for you to be here, please use the API Functions defined 
	in sslThreadController.psc if you wish to access or write alias data
}

; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-* ;
; ----------------------------------------------------------------------------- ;
;        ██╗███╗   ██╗████████╗███████╗██████╗ ███╗   ██╗ █████╗ ██╗            ;
;        ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗████╗  ██║██╔══██╗██║            ;
;        ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝██╔██╗ ██║███████║██║            ;
;        ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██║╚██╗██║██╔══██║██║            ;
;        ██║██║ ╚████║   ██║   ███████╗██║  ██║██║ ╚████║██║  ██║███████╗       ;
;        ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝       ;
; ----------------------------------------------------------------------------- ;
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-* ;

;/ Notice about cleanup Architecture:
- Initialize() 		hard reset the Alias and underlying reference. Clears the alias & resets all alias data
- UnplaceActor() 	soft reset the underlying reference. May only be used while the reference is placed. Use to escape animating state
- Clear() 				soft reset the Alias. Will fail while the underlying reference is animating
/;

sslThreadModel Thread
sslSystemConfig Config
sslActorStats Stats

Faction AnimatingFaction
Actor PlayerRef

int vanilla_sex

; ------------------------------------------------------- ;
; --- API Related Functions & Data                    --- ;
; ------------------------------------------------------- ;

Actor Property ActorRef Auto Hidden
int Property Position
	int Function Get()
		return Thread.Positions.Find(ActorRef)
	EndFunction
EndProperty

int _ActorData
int Function GetActorData()
	return _ActorData
EndFunction

String Function GetActorName()
	If(!ActorRef)
		return "EMPTY"
	EndIf
	return ActorRef.GetLeveledActorBase().GetName()
EndFunction

Function SetStripping(int aiSlots, bool abStripWeapons)
	StripOverride = new int[2]
	StripOverride[0] = aiSlots
	StripOverride[1] = abStripWeapons as int
EndFunction

bool Function IsAggressor()
	return Thread.IsAggressive && !IsVictim()
EndFunction

bool function IsVictim()
	return sslActorData.IsVictim(_ActorData)
endFunction

function AdjustEnjoyment(int AdjustBy)
	BaseEnjoyment += AdjustBy
endfunction

; ------------------------------------------------------- ;
; --- Still under constructions                       --- ;
; ------------------------------------------------------- ;

float StartWait
string StartAnimEvent
bool NoOrgasm

; Voice
sslBaseVoice Voice
VoiceType ActorVoice
float BaseDelay
float VoiceDelay
float ExpressionDelay
bool IsForcedSilent

; Expression
sslBaseExpression Expression
sslBaseExpression[] Expressions

; Storage
Form[] Equipment
Form LeftHand
Form RightHand

int[] StripOverride
float[] Skills
float[] OwnSkills

float StartedAt
float ActorScale
float AnimScale
float NioScale
float LastOrgasm
int BestRelation
int BaseEnjoyment
int QuitEnjoyment
int FullEnjoyment
int Orgasms

Sound OrgasmFX

Spell HDTHeelSpell

; Animation Position/Stage flags
bool property ForceOpenMouth auto hidden
bool property OpenMouth hidden
	bool function get()
		return Thread.Animation.UseOpenMouth(Position, Thread.Stage) || ForceOpenMouth
	endFunction
endProperty

bool property IsSilent hidden
	bool function get()
		return !Voice || IsForcedSilent || OpenMouth || Thread.Animation.UseOpenMouth(Position, Thread.Stage)
	endFunction
endProperty

bool property UseStrapon hidden
	bool function get()
		bool flag = Thread.Animation.UseStrapon(Position, Thread.Stage)
		int gender = Thread.Animation.GetGenderEx(Position)
		return sslActorData.IsFemale(_ActorData) && flag && gender != 1
	endFunction
endProperty

int property Schlong hidden
	int function get()
		return Thread.Animation.GetSchlong(Thread.AdjustKey, Position, Thread.Stage)
	endFunction
endProperty

bool property MalePosition hidden
	bool function get()
		return Thread.Animation.GetGender(Position) == 0
	endFunction
endProperty

; ------------------------------------------------------- ;
; --- Load Alias For Use                              --- ;
; ------------------------------------------------------- ;

; Default Sate for an unused Alias. While in here, the Alias is empty and can be used for animation
; The Script will leave this State once an Actor has been properly filled in
Auto State Empty
	bool function SetActorEx(Actor akReference, bool abIsVictim, sslBaseVoice akVoice, bool abSilent)
		ForceRefTo(akReference)
		ActorRef = akReference
		_ActorData = sslActorData.BuildDataKey(akReference, abIsVictim)
		vanilla_sex = ActorRef.GetLeveledActorBase().GetSex()
		; ActorVoice = BaseRef.GetVoiceType()
		Stats.SeedActor(ActorRef)
		NioScale = 1.0
		float TempScale
		String Node = "NPC"
		if NetImmerse.HasNode(ActorRef, Node, False)
			TempScale = NetImmerse.GetNodeScale(ActorRef, Node, False)
			if TempScale > 0
				NioScale = NioScale * TempScale
			endIf
		endIf
		Node = "NPC Root [Root]"
		if NetImmerse.HasNode(ActorRef, Node, False)
			TempScale = NetImmerse.GetNodeScale(ActorRef, Node, False)
			if TempScale > 0
				NioScale = NioScale * TempScale
			endIf
		endIf

		if Config.HasNiOverride && !sslActorData.IsCreature(_ActorData)
			string[] MOD_OVERRIDE_KEY = NiOverride.GetNodeTransformKeys(ActorRef, False, vanilla_sex == 1, "NPC")
			int idx = 0
			While idx < MOD_OVERRIDE_KEY.Length
				if MOD_OVERRIDE_KEY[idx] != "SexLab.esm"
					TempScale = NiOverride.GetNodeTransformScale(ActorRef, False, vanilla_sex == 1, "NPC", MOD_OVERRIDE_KEY[idx])
					if TempScale > 0
						NioScale = NioScale * TempScale
					endIf
				else ; Remove SexLab Node if present by error
					if NiOverride.RemoveNodeTransformScale(ActorRef, False, vanilla_sex == 1, "NPC", MOD_OVERRIDE_KEY[idx])
						NiOverride.UpdateNodeTransform(ActorRef, False, vanilla_sex == 1, "NPC")
					endIf
				endIf
				idx += 1
			endWhile
		endIf
		; Set base voice/loop delay
		If(sslActorData.IsCreature(_ActorData))
			BaseDelay = 3.0
		ElseIf(vanilla_sex == 1)
			BaseDelay = Config.FemaleVoiceDelay
		Else
			BaseDelay = Config.MaleVoiceDelay
		EndIf
		VoiceDelay = BaseDelay
		ExpressionDelay = Config.ExpressionDelay * BaseDelay
		; Ready
		RegisterEvents()
		TrackedEvent("Added")
		GoToState("Ready")
		Log("Completed Actor Setup")
		return true
	endFunction

	; No Actor to get a key/data from
	String function GetActorKey()
		return ""
	EndFunction
	int Function GetActorData()
		return 0
	EndFunction
EndState

; ------------------------------------------------------- ;
; --- Actor Prepartion                                --- ;
; ------------------------------------------------------- ;

; This State is invoked after an Actor has been picked up by this Alias
; This state acts as an "preparing" instance, the only way out of it is to either stop the
; animation in its entirety or properly begin the animation
State Ready
	; Declare all animation related variables for this Actor & move into position
	; This does NOT have any influence on the underlying actor instance
	; The alias is considered "ready for animating" when done
	Event PrepareActor()
		SetData()
		; Position
		If(ActorRef.GetActorValue("Paralysis") > 0)
			ActorRef.SetActorValue("Paralysis", 0.0)
			SendDefaultAnimEvent()
		EndIf
		If(DoPathToCenter)
			PathToCenter()
		EndIf
		Thread.SyncEventDone()
	EndEvent

	; Have the Actor path towards center. Latent
	function PathToCenter()
		ObjectReference _center = Thread.CenterRef
		If(ActorRef == _center)
			return
		EndIf
		If(ActorRef.GetDistance(_center) > 6144.0)
			return
		EndIf
		float t = SexLabUtil.GetCurrentGameRealTimeEx() + 15.0
		ActorRef.SetFactionRank(AnimatingFaction, 2)
		ActorRef.EvaluatePackage()
		While (ActorRef.GetDistance(_center) > 256.0 && SexLabUtil.GetCurrentGameRealTimeEx() < t)
			Utility.Wait(0.035)
		EndWhile
		ActorRef.SetFactionRank(AnimatingFaction, 1)
		ActorRef.EvaluatePackage()
	EndFunction

	; Called when the main thread wants to start the first animation
	Function PlayAnimation(String asAnimation)
		Log("Playing Animation " + asAnimation)
		Debug.SendAnimationEvent(ActorRef, "SOSFastErect")
		Debug.SendAnimationEvent(ActorRef, asAnimation)
		PlayingAE = asAnimation
		GoToState("Animating")
	EndFunction

	; Can only be called before PrepareActor() is invoked
	Function Clear()
		ClearEvents()
		Parent.Clear()
		GoToState("Empty")
	EndFunction

	Function SetData()
		If(ActorRef == PlayerRef)
			Game.SetPlayerAIDriven()
		Else
			Config.CheckBardAudience(ActorRef, true)
		EndIf
		ActorRef.SetFactionRank(AnimatingFaction, 1)
		ActorRef.EvaluatePackage()
		String LogInfo = ""
		; Voice
		if !Voice && !IsForcedSilent
			if sslActorData.IsCreature(_ActorData)
				Voice = Config.VoiceSlots.PickByRaceKey(sslCreatureAnimationSlots.GetRaceKey(ActorRef.GetRace()))
			else
				Voice = Config.VoiceSlots.PickVoice(ActorRef)
			endIf
		endIf
		If(Voice)
			LogInfo += "Voice[" + Voice.Name + "] "
		EndIf
		; Strapon & Expression (for NPC only)
		If(!sslActorData.IsCreature(_ActorData))
			If(Config.UseStrapons && sslActorData.IsFemale(_ActorData))
				HadStrapon = Config.WornStrapon(ActorRef)
				If(!HadStrapon)
					Strapon = Config.GetStrapon()
				Else
					Strapon = HadStrapon
				EndIf
			EndIf
			LogInfo += "Strapn[" + Strapon + "] "
			if !Expression && Config.UseExpressions
				Expressions = Config.ExpressionSlots.GetByStatus(ActorRef, IsVictim(), Thread.IsType[0] && !IsVictim())
				if Expressions && Expressions.Length > 0
					Expression = Expressions[Utility.RandomInt(0, (Expressions.Length - 1))]
				endIf
			endIf
			If(Expression)
				LogInfo += "Expression[" + Expression.Name + "] "
			EndIf
		EndIf
		
		; COMEBACK: Everything below still needs reviewing
		if !sslActorData.IsCreature(_ActorData) || sslActorStats.IsSkilled(ActorRef)
			; Always use players stats for NPCS if present, so players stats mean something more
			Actor SkilledActor = ActorRef
			If(Thread.HasPlayer && ActorRef != PlayerRef)
				SkilledActor = PlayerRef
			; If a non-creature couple, base skills off partner
			ElseIf(Thread.ActorCount > 1 && !Thread.HasCreature)
				SkilledActor = Thread.Positions[sslUtility.IndexTravel(Position, Thread.ActorCount)]
			EndIf
			; Get sex skills of partner/player
			Skills       = Stats.GetSkillLevels(SkilledActor)
			OwnSkills    = Stats.GetSkillLevels(ActorRef)
			; Try to prevent orgasms on fist stage resting enjoyment
			float FirsStageTime
			if Thread.LeadIn
				FirsStageTime = Config.StageTimerLeadIn[0]
			elseIf Thread.IsType[0]
				FirsStageTime = Config.StageTimerAggr[0]
			else
				FirsStageTime = Config.StageTimer[0]
			endIf
			BaseEnjoyment -= Math.Abs(CalcEnjoyment(Thread.SkillBonus, Skills, Thread.LeadIn, sslActorData.IsFemale(_ActorData), FirsStageTime, 1, Thread.Animation.StageCount)) as int
			if BaseEnjoyment < -5
				BaseEnjoyment += 10
			endIf
			; Add Bonus Enjoyment
			if IsVictim()
				BestRelation = Thread.GetLowestPresentRelationshipRank(ActorRef)
				BaseEnjoyment += ((BestRelation - 3) + PapyrusUtil.ClampInt((OwnSkills[Stats.kLewd]-OwnSkills[Stats.kPure]) as int,-6,6)) * Utility.RandomInt(1, 10)
			else
				BestRelation = Thread.GetHighestPresentRelationshipRank(ActorRef)
				if IsAggressor()
					BaseEnjoyment += (-1*((BestRelation - 4) + PapyrusUtil.ClampInt(((Skills[Stats.kLewd]-Skills[Stats.kPure])-(OwnSkills[Stats.kLewd]-OwnSkills[Stats.kPure])) as int,-6,6))) * Utility.RandomInt(1, 10)
				else
					BaseEnjoyment += (BestRelation + PapyrusUtil.ClampInt((((Skills[Stats.kLewd]+OwnSkills[Stats.kLewd])*0.5)-((Skills[Stats.kPure]+OwnSkills[Stats.kPure])*0.5)) as int,0,6)) * Utility.RandomInt(1, 10)
				endIf
			endIf
		else
			if IsVictim()
				BestRelation = Thread.GetLowestPresentRelationshipRank(ActorRef)
				BaseEnjoyment += (BestRelation - 3) * Utility.RandomInt(1, 10)
			else
				BestRelation = Thread.GetHighestPresentRelationshipRank(ActorRef)
				if IsAggressor()
					BaseEnjoyment += (-1*(BestRelation - 4)) * Utility.RandomInt(1, 10)
				else
					BaseEnjoyment += (BestRelation + 3) * Utility.RandomInt(1, 10)
				endIf
			endIf
		endIf
		LogInfo += "BaseEnjoyment["+BaseEnjoyment+"]"
		Log(LogInfo)
	EndFunction
EndState

; ------------------------------------------------------- ;
; --- Animation Loop       				                    --- ;
; ------------------------------------------------------- ;

string PlayingAE
float LoopDelay
float LoopExpressionDelay

Event OnCellDetach()
	Log("An Alias is out of range and cannot be animated anymore. Stopping Thread...")
	GoToState("Idling")
	Thread.EndAnimation()
EndEvent
Event OnUnload()
	Log("An Alias is out of range and cannot be animated anymore. Stopping Thread...")
	GoToState("Idling")
	Thread.EndAnimation()
EndEvent
Event OnDying(Actor akKiller)
	Log("An Alias is dying and cannot be animated anymore. Stopping Thread...")
	GoToState("Idling")
	Thread.EndAnimation()
EndEvent

; For the entire duration of the Animating State, an Actor is to be "placed"
; ONLY leave this state using "UnplaceActor"
state Animating
	Event OnBeginState()
		TrackedEvent("Start")
		StartedAt = SexLabUtil.GetCurrentGameRealTimeEx()
		LastOrgasm = StartedAt
		SyncThread()
		RegisterForSingleUpdate(Utility.RandomFloat(1.0, 3.0))
	EndEvent

	Function UnplaceActor()
		; Clear SFX & expression & any other animation-exclusive effects
		; Make sure of play the last animation stage to prevet AnimObject issues
		String last_anim = Thread.Animation.FetchPositionStage(Position, Thread.Animation.StageCount)
		If(PlayingAE != last_anim)
			PlayingAE = last_anim
			Debug.SendAnimationEvent(ActorRef, last_anim)
		EndIf
		; Reset Expression
		If(Expression || sslBaseExpression.IsMouthOpen(ActorRef))
			sslBaseExpression.CloseMouth(ActorRef)
		EndIf
		ActorRef.ClearExpressionOverride()
		ActorRef.ResetExpressionOverrides()
		sslBaseExpression.ClearMFG(ActorRef)
		SendDefaultAnimEvent(true)
		GoToState("Idling")
		UnplaceActor()
	EndFunction

	Function Clear()
		Error("Cannot call 'Clear' in Animating State")
	EndFunction

	Event OnUpdate()
		If(Thread.GetState() != "Animating")
			return
		EndIf
		; TODO: Review this block below
		int Strength = CalcReaction()
		if LoopDelay >= VoiceDelay && (Config.LipsFixedValue || Strength > 10)
			LoopDelay = 0.0
			bool UseLipSync = Config.UseLipSync && !sslActorData.IsCreature(_ActorData)
			if OpenMouth && UseLipSync && !Config.LipsFixedValue
				sslBaseVoice.MoveLips(ActorRef, none, 0.3)
				Log("PlayMoan:False; UseLipSync:"+UseLipSync+"; OpenMouth:"+OpenMouth)
			elseIf !IsSilent
				Voice.PlayMoan(ActorRef, Strength, IsVictim(), UseLipSync)
				Log("PlayMoan:True; UseLipSync:"+UseLipSync+"; OpenMouth:"+OpenMouth)
			endIf
		endIf
		if Expressions && Expressions.Length > 0
			if LoopExpressionDelay >= ExpressionDelay && Config.RefreshExpressions
				sslBaseExpression oldExpression = Expression
				Expression = Expressions[Utility.RandomInt(0, (Expressions.Length - 1))]
				Log("Expression["+Expression.Name+"] BaseVoiceDelay["+BaseDelay+"] ExpressionDelay["+ExpressionDelay+"] LoopExpressionDelay["+LoopExpressionDelay+"] ")
				if oldExpression != Expression
					RefreshExpression()
				endIf
				LoopExpressionDelay = 0.0
			endIf
		endIf
		if RefreshExpressionDelay > 8.0
			RefreshExpression()
		endIf
		; Trigger orgasm
		If(!NoOrgasm && Config.SeparateOrgasms && Strength >= 100 && Thread.Stage < Thread.Animation.StageCount)
			int cmp
			If(sslActorData.IsMale(_ActorData))
				cmp = 20
			ElseIf(sslActorData.IsMaleCreature(_ActorData))
				cmp = 30
			EndIf
			If(SexLabUtil.GetCurrentGameRealTimeEx() - LastOrgasm > cmp)
				OrgasmEffect()
			EndIf
		EndIf
		; Loop
		LoopDelay += (VoiceDelay * 0.35)
		LoopExpressionDelay += (VoiceDelay * 0.35)
		RefreshExpressionDelay += (VoiceDelay * 0.35)
		RegisterForSingleUpdate(VoiceDelay * 0.35)
	EndEvent

	; ---- Below Function are called through the Mainthread only ---

	Function PlayAnimation(String asAnimation)
		Log("Playing Animation " + asAnimation)
		; Dont restart the animation, might create some odd stuttering otherwise
		If(PlayingAE == asAnimation)
			Log("Playing Animation is same as current one, abandon")
			return
		EndIf
		Debug.SendAnimationEvent(ActorRef, asAnimation)
		PlayingAE = asAnimation
	EndFunction

	; Unsure why this is here but would theoreitcally solve an issue if someone calls "TranslateTo" on an animating actor, eh
	Event OnTranslationComplete()
		Snap()
	EndEvent

	; Basically just an "update for current animation stage"
	; Update everything stage related here, Flag data, delays, etcpp
	function SyncThread()
		ResolveStrapon()
		VoiceDelay = BaseDelay
		ExpressionDelay = Config.ExpressionDelay * BaseDelay
		if !IsSilent && Thread.Stage > 1
			VoiceDelay -= (Thread.Stage * 0.8) + Utility.RandomFloat(-0.2, 0.4)
		endIf
		if VoiceDelay < 0.8
			VoiceDelay = Utility.RandomFloat(0.8, 1.4) ; Can't have delay shorter than animation update loop
		endIf
		Debug.SendAnimationEvent(ActorRef, "SOSBend"+Schlong)
	endFunction

	; --- TODO: Review & reimplement these
	function OrgasmEffect()
		DoOrgasm()
	endFunction

	function DoOrgasm(bool Forced = false)
		if !ActorRef
			return
		endIf
		int Enjoyment = GetEnjoyment()
		if !Forced && (NoOrgasm || Thread.DisableOrgasms)
			; Orgasm Disabled for actor or whole thread
			return 
		elseIf !Forced && Enjoyment < 1
			; Actor have the orgasm few seconds ago or is in pain and can't orgasm
			return
		elseIf Math.Abs(SexLabUtil.GetCurrentGameRealTimeEx() - LastOrgasm) < 5.0
			Log("Excessive OrgasmEffect Triggered")
			return
		endIf

		; Check if the animation allow Orgasm. By default all the animations with a CumID>0 are type SEX and allow orgasm 
		; But the Lesbian Animations usually don't have CumId assigned and still the orgasm should be allowed at least for Females.
		bool CanOrgasm = Forced || (sslActorData.IsFemale(_ActorData) && (Thread.Animation.HasTag("Lesbian") || Thread.Animation.Females == Thread.Animation.PositionCount))
		int i = Thread.ActorCount
		while !CanOrgasm && i > 0
			i -= 1
			CanOrgasm = Thread.Animation.GetCumID(i, Thread.Stage) > 0 || Thread.Animation.GetCum(i) > 0
		endWhile
		if !CanOrgasm
			; Orgasm Disabled for the animation
			return
		endIf

		; Check Separate Orgasm conditions 
		if !Forced && Config.SeparateOrgasms
			if Enjoyment < 100 && (Thread.Stage < Thread.Animation.StageCount || Orgasms > 0)
				; Prevent the orgasm with low enjoyment at least the last stage be reached without orgasms
				return
			endIf
			bool IsCumSource = False
			i = Thread.ActorCount
			while !IsCumSource && i > 0
				i -= 1
				IsCumSource = Thread.Animation.GetCumSource(i, Thread.Stage) == Position
			endWhile
			if !IsCumSource
				if sslActorData.IsFuta(_ActorData) && !(Thread.Animation.HasTag("Anal") || Thread.Animation.HasTag("Vaginal") || Thread.Animation.HasTag("Pussy") || Thread.Animation.HasTag("Cunnilingus") || Thread.Animation.HasTag("Fisting") || Thread.Animation.HasTag("Handjob") || Thread.Animation.HasTag("Blowjob") || Thread.Animation.HasTag("Boobjob") || Thread.Animation.HasTag("Footjob") || Thread.Animation.HasTag("Penis"))
					return
				elseIf sslActorData.IsMale(_ActorData) && !(Thread.Animation.HasTag("Anal") || Thread.Animation.HasTag("Vaginal") || Thread.Animation.HasTag("Handjob") || Thread.Animation.HasTag("Blowjob") || Thread.Animation.HasTag("Boobjob") || Thread.Animation.HasTag("Footjob") || Thread.Animation.HasTag("Penis"))
					return
				elseIf sslActorData.IsFemale(_ActorData) && !(Thread.Animation.HasTag("Anal") || Thread.Animation.HasTag("Vaginal") || Thread.Animation.HasTag("Pussy") || Thread.Animation.HasTag("Cunnilingus") || Thread.Animation.HasTag("Fisting") || Thread.Animation.HasTag("Breast"))
					return
				endIf
			endIf
		endIf
		UnregisterForUpdate()
		LastOrgasm = SexLabUtil.GetCurrentGameRealTimeEx()
		Orgasms   += 1
		; Send an orgasm event hook with actor and orgasm count
		int eid = ModEvent.Create("SexLabOrgasm")
		ModEvent.PushForm(eid, ActorRef)
		ModEvent.PushInt(eid, FullEnjoyment)
		ModEvent.PushInt(eid, Orgasms)
		ModEvent.Send(eid)
		TrackedEvent("Orgasm")
		Log(GetActorName() + ": Orgasms["+Orgasms+"] FullEnjoyment ["+FullEnjoyment+"] BaseEnjoyment["+BaseEnjoyment+"] Enjoyment["+Enjoyment+"]")
		If(Config.OrgasmEffects)
			; Shake camera for player
			If(ActorRef == PlayerRef && Config.ShakeStrength > 0 && Game.GetCameraState() >= 8 )
				Game.ShakeCamera(none, Config.ShakeStrength, Config.ShakeStrength + 1.0)
			EndIf
			; Play SFX/Voice
			If(!IsSilent)
				PlayLouder(Voice.GetSound(100, false), ActorRef, Config.VoiceVolume)
			EndIf
			PlayLouder(OrgasmFX, ActorRef, Config.SFXVolume)
		EndIf
		; Apply cum to female positions from male position orgasm
		if Thread.ActorCount > 1 && Config.UseCum && (MalePosition || sslActorData.IsCreature(_ActorData)) && (Config.AllowFFCum || !sslActorData.IsFemale(_ActorData) && !sslActorData.IsFemaleCreature(_ActorData))
			if Thread.ActorCount == 2
				Thread.PositionAlias(1 - Position).ApplyCum()
			else
				while i > 0
					i -= 1
					if Position != i && Position < Thread.Animation.PositionCount && Thread.Animation.IsCumSource(Position, i, Thread.Stage)
						Thread.PositionAlias(i).ApplyCum()
					endIf
				endWhile
			endIf
		endIf
		Utility.WaitMenuMode(0.2)
		; Reset enjoyment build up, if using multiple orgasms
		QuitEnjoyment += Enjoyment
		if !sslActorData.IsCreature(_ActorData) || sslActorStats.IsSkilled(ActorRef)
			if IsVictim()
				BaseEnjoyment += ((BestRelation - 3) + PapyrusUtil.ClampInt((OwnSkills[Stats.kLewd]-OwnSkills[Stats.kPure]) as int,-6,6)) * Utility.RandomInt(5, 10)
			else
				if IsAggressor()
					BaseEnjoyment += (-1*((BestRelation - 4) + PapyrusUtil.ClampInt(((Skills[Stats.kLewd]-Skills[Stats.kPure])-(OwnSkills[Stats.kLewd]-OwnSkills[Stats.kPure])) as int,-6,6))) * Utility.RandomInt(5, 10)
				else
					BaseEnjoyment += (BestRelation + PapyrusUtil.ClampInt((((Skills[Stats.kLewd]+OwnSkills[Stats.kLewd])*0.5)-((Skills[Stats.kPure]+OwnSkills[Stats.kPure])*0.5)) as int,0,6)) * Utility.RandomInt(5, 10)
				endIf
			endIf
		else
			if IsVictim()
				BaseEnjoyment += (BestRelation - 3) * Utility.RandomInt(5, 10)
			else
				if IsAggressor()
					BaseEnjoyment += (-1*(BestRelation - 4)) * Utility.RandomInt(5, 10)
				else
					BaseEnjoyment += (BestRelation + 3) * Utility.RandomInt(5, 10)
				endIf
			endIf
		endIf
		; VoiceDelay = 0.8
		RegisterForSingleUpdate(0.8)
	endFunction
endState

; ------------------------------------------------------- ;
; --- Animation Pause		                              --- ;
; ------------------------------------------------------- ;

; Intermediate clear
; In this State, the actor may move around freely without any animation specific status restricting them
; The status can be used to force an actor back into the animating state without having to reset the entire script
State Idling
	Function Clear()
		ClearEvents()
		TrackedEvent("End")
		Parent.Clear()
		GoToState("Empty")
	EndFunction

	Function PlaceActor(ObjectReference akCenter)
		Log("Placing Idling Actor")
		GoToState("Animating")
		PlaceActor(akCenter)
	EndFunction
EndState

; ------------------------------------------------------- ;
; --- Strapon									                        --- ;
; ------------------------------------------------------- ;

Form Strapon		; Strapon used by the animation
Form HadStrapon	; Strapon worn prior to animation start
; assert(HadStrappon => Strappon == HadStrapon)

Form function GetStrapon()
	return Strapon
endFunction

bool function IsUsingStrapon()
	return Strapon && ActorRef.IsEquipped(Strapon)
endFunction

function EquipStrapon()
	if Strapon && !ActorRef.IsEquipped(Strapon)
		ActorRef.EquipItem(Strapon, true, true)
	endIf
endFunction

function UnequipStrapon()
	if Strapon && ActorRef.IsEquipped(Strapon)
		ActorRef.UnequipItem(Strapon, true, true)
	endIf
endFunction

function SetStrapon(Form ToStrapon)
	if Strapon && !HadStrapon && Strapon != ToStrapon
		ActorRef.RemoveItem(Strapon, 1, true)
	endIf
	Strapon = ToStrapon
	if GetState() == "Animating"
		ResolveStrapon()
	endIf
endFunction

Function ResolveStrapon(bool force = false)
	If(!Strapon)
		return
	EndIf
	bool equipped = ActorRef.IsEquipped(Strapon)
	If(UseStrapon)
		If(!equipped)
			ActorRef.EquipItem(Strapon, true, true)
		EndIf
	ElseIf(equipped)
		ActorRef.UnequipItem(Strapon, true, true)
	EndIf
EndFunction

Function RemoveStrapon()
	If(Strapon && !HadStrapon)
		ActorRef.RemoveItem(Strapon, 1, true)
	EndIf
EndFunction

; ------------------------------------------------------- ;
; --- Data Accessors                                  --- ;
; ------------------------------------------------------- ;

int function GetEnjoyment()
	if sslActorData.IsCreature(_ActorData) && !sslActorStats.IsSkilled(ActorRef)
		FullEnjoyment = BaseEnjoyment + (PapyrusUtil.ClampFloat(((SexLabUtil.GetCurrentGameRealTimeEx() - StartedAt) + 1.0) / 5.0, 0.0, 40.0) + ((Thread.Stage as float / Thread.Animation.StageCount as float) * 60.0)) as int
	else
		if Position == 0
			Thread.RecordSkills()
			Thread.SetBonuses()
		endIf
		FullEnjoyment = BaseEnjoyment + CalcEnjoyment(Thread.SkillBonus, Skills, Thread.LeadIn, sslActorData.IsFemale(_ActorData), (SexLabUtil.GetCurrentGameRealTimeEx() - StartedAt), Thread.Stage, Thread.Animation.StageCount)
		; Log("FullEnjoyment["+FullEnjoyment+"] / BaseEnjoyment["+BaseEnjoyment+"] / Enjoyment["+(FullEnjoyment - BaseEnjoyment)+"]")
	endIf

	int Enjoyment = FullEnjoyment - QuitEnjoyment
	if Enjoyment > 0
		return Enjoyment
	endIf
	return 0
endFunction

int function GetPain()
	GetEnjoyment()
	if FullEnjoyment < 0
		return Math.Abs(FullEnjoyment) as int
	endIf
	return 0	
endFunction

int function CalcReaction()
	int Strength = GetEnjoyment()
	; Check if the actor is in pain or too excited to care about pain
	if FullEnjoyment < 0 && Strength < Math.Abs(FullEnjoyment)
		Strength = FullEnjoyment
	endIf
	return PapyrusUtil.ClampInt(Math.Abs(Strength) as int, 0, 100)
endFunction

function ApplyCum()
	if ActorRef && ActorRef.Is3DLoaded()
		Cell ParentCell = ActorRef.GetParentCell()
		int CumID = Thread.Animation.GetCumID(Position, Thread.Stage)
		if CumID > 0 && ParentCell && ParentCell.IsAttached() ; Error treatment for Spells out of Cell
			Thread.ActorLib.ApplyCum(ActorRef, CumID)
		endIf
	endIf
endFunction

function DisableOrgasm(bool bNoOrgasm)
	NoOrgasm = bNoOrgasm
endFunction

bool function IsOrgasmAllowed()
	return !NoOrgasm && !Thread.DisableOrgasms
endFunction

bool function NeedsOrgasm()
	return GetEnjoyment() >= 100 && FullEnjoyment >= 100
endFunction

function SetVoice(sslBaseVoice ToVoice = none, bool ForceSilence = false)
	IsForcedSilent = ForceSilence
	if ToVoice && sslActorData.IsCreature(_ActorData) == ToVoice.Creature
		Voice = ToVoice
	endIf
endFunction

sslBaseVoice function GetVoice()
	return Voice
endFunction

function SetExpression(sslBaseExpression ToExpression)
	if ToExpression
		Expression = ToExpression
	endIf
endFunction

sslBaseExpression function GetExpression()
	return Expression
endFunction

function SetStartAnimationEvent(string EventName, float PlayTime)
	StartAnimEvent = EventName
	StartWait = PapyrusUtil.ClampFloat(PlayTime, 0.1, 10.0)
endFunction

bool function PregnancyRisk()
	int cumID = Thread.Animation.GetCumID(Position, Thread.Stage)
	return cumID > 0 && (cumID == 1 || cumID == 4 || cumID == 5 || cumID == 7) && vanilla_sex == 1 && !MalePosition && Thread.IsVaginal
endFunction

bool _DoUndress
bool property DoUndress hidden
	bool function get()
		return Config.UndressAnimation && _DoUndress && GetState() != "Animating"
	endFunction
	function set(bool value)
		_DoUndress = value
	endFunction
endProperty

bool NoRedress
bool property DoRedress hidden
	bool function get()
		return !NoRedress && (!IsVictim() || Config.RedressVictim)
	endFunction
	function set(bool value)
		NoRedress = !value
	endFunction
endProperty

int PathingFlag
function ForcePathToCenter(bool forced)
	PathingFlag = forced as int
endFunction
function DisablePathToCenter(bool disabling)
	If(disabling)
		PathingFlag = -1
	Else
		PathingFlag = (PathingFlag == 1) as int
	EndIf
endFunction
bool property DoPathToCenter
	bool function get()
		return (PathingFlag == 0 && Config.DisableTeleport) || PathingFlag == 1
	endFunction
endProperty

float RefreshExpressionDelay
function RefreshExpression()
	if !ActorRef || sslActorData.IsCreature(_ActorData) || !ActorRef.Is3DLoaded() || ActorRef.IsDisabled()
		; Do nothing
	elseIf OpenMouth
		sslBaseExpression.OpenMouth(ActorRef)
		Utility.Wait(1.0)
		if Config.RefreshExpressions && Expression && Expression != none && !ActorRef.IsDead() && !ActorRef.IsUnconscious() && ActorRef.GetActorValue("Health") > 1.0
			int Strength = CalcReaction()
			Expression.Apply(ActorRef, Strength, vanilla_sex)
			Log("Expression.Applied("+Expression.Name+") Strength:"+Strength+"; OpenMouth:"+OpenMouth)
		endIf
	else
		if Expression && Expression != none && !ActorRef.IsDead() && !ActorRef.IsUnconscious() && ActorRef.GetActorValue("Health") > 1.0
			int Strength = CalcReaction()
			sslBaseExpression.CloseMouth(ActorRef)
			Expression.Apply(ActorRef, Strength, vanilla_sex)
			Log("Expression.Applied("+Expression.Name+") Strength:"+Strength+"; OpenMouth:"+OpenMouth)
		elseIf sslBaseExpression.IsMouthOpen(ActorRef)
			sslBaseExpression.CloseMouth(ActorRef)			
		endIf
	endIf
	RefreshExpressionDelay = 0.0
endFunction

; ------------------------------------------------------- ;
; --- System Use                                      --- ;
; ------------------------------------------------------- ;

function PlayLouder(Sound SFX, ObjectReference FromRef, float Volume)
	if SFX && FromRef && FromRef.Is3DLoaded() && Volume > 0.0
		if Volume > 0.5
			Sound.SetInstanceVolume(SFX.Play(FromRef), 1.0)
		else
			Sound.SetInstanceVolume(SFX.Play(FromRef), Volume)
		endIf
	endIf
endFunction

; ------------------------------------------------------- ;
; --- State Restricted                                --- ;
; ------------------------------------------------------- ;

int function CalcEnjoyment(float[] XP, float[] SkillsAmounts, bool IsLeadin, bool IsFemaleActor, float Timer, int OnStage, int MaxStage) global native

; ------------------------------------------------------- ;
; ---	Out Animation                                   --- ;
; ------------------------------------------------------- ;

; Prepare this actor for positioning
; Return duration for the pre-placement starting animation, if any
Function PlaceActor(ObjectReference akCenter)
	Log("PlaceActor on " + ActorRef)
	LockActor()
	; ActorRef.SetVehicle(akCenter)
	; If(Config.DisableScale)
	; 	ActorScale = 1.0
	; 	AnimScale = 1.0
	; Else
	; 	float display = ActorRef.GetScale()
	; 	ActorRef.SetScale(1.0)
	; 	float base = ActorRef.GetScale()
	; 	ActorScale = display / base
	; 	AnimScale  = ActorScale
	; 	If(ActorScale > 0.0 && ActorScale != 1.0)
	; 		ActorRef.SetScale(ActorScale)
	; 	EndIf
	; 	If(Thread.ActorCount > 1 && Config.ScaleActors)
	; 		If(Config.HasNiOverride && !sslActorData.IsCreature(_ActorData) && NioScale > 0.0 && NioScale != 1.0)
	; 			float FixNioScale = FixNioScale / NioScale
	; 			NiOverride.AddNodeTransformScale(ActorRef, false, vanilla_sex == 1, "NPC", "SexLab.esm", FixNioScale)
	; 			NiOverride.UpdateNodeTransform(ActorRef, false, vanilla_sex == 1, "NPC")
	; 		EndIf
	; 		AnimScale = 1.0 / base
	; 	EndIf
	; 	If(ActorScale != 1.0 && AnimScale != 1.0)
	; 		ActorRef.SetScale(AnimScale)
	; 	EndIf
	; 	Log("Applying Scale on Actor " + ActorRef + ": ["+display+"/"+base+"/"+ActorScale+"/"+AnimScale+"/"+NioScale+"]")
	; EndIf
EndFunction

float Function HandleStartAnimation()
	If(StartAnimEvent == "")
		If(DoUndress)
			Debug.SendAnimationEvent(ActorRef, "Arrok_Undress_G" + vanilla_sex)
			StartWait = 1.0
		EndIf
	Else
		Debug.SendAnimationEvent(ActorRef, StartAnimEvent)
	EndIf
	return StartWait
EndFunction

; Freeze this actor in place and stop them from moving
Function LockActor()
	ActorRef.StopCombat()
	if ActorRef.IsWeaponDrawn()
		ActorRef.SheatheWeapon()
	endIf
	if ActorRef.IsSneaking()
		ActorRef.StartSneaking()
	endIf
	ActorRef.ClearKeepOffsetFromActor()
	ActorRef.StopTranslation()
	ActorRef.SetFactionRank(AnimatingFaction, 1)
	If(ActorRef == PlayerRef)
		Game.SetPlayerAIDriven()
		If(Game.GetCameraState() == 0)
			Game.ForceThirdPerson()
		EndIf
		If(Config.AutoTFC)
			MiscUtil.SetFreeCameraState(true)
			MiscUtil.SetFreeCameraSpeed(Config.AutoSUCSM)
		EndIf
		; COMEBACK: Not sure if we want this or nah. Its a good way to disable the UI but also stops notifications from displaying
		; UI.SetBool("HUD Menu", "_root.HUDMovieBaseInstance._visible", false)
	Else
		ActorRef.SetRestrained(true)
		ActorUtil.AddPackageOverride(ActorRef, Thread.DoNothingPackage, 100, 1)
		ActorRef.EvaluatePackage()
	EndIf
	ActorRef.SetAnimationVariableBool("bHumanoidFootIKDisable", true)
EndFunction

; ------------------------------------------------------- ;
; ---	In Animation				                            --- ;
; ------------------------------------------------------- ;

; Reset this Actor into a pre-animation state, allowing them to freely move around
; Is overwritten by the Animation State to consider animation exclusive statuses, eg expression
Function UnplaceActor()
	Log("UnplaceActor on " + ActorRef)
	UnlockActor()
	; ActorRef.SetVehicle(none)
	; If(ActorScale != 1.0 || AnimScale != 1.0)
	; 	ActorRef.SetScale(ActorScale)
	; EndIf
	If(Config.HasNiOverride)
		bool UpdateNiOPosition = NiOverride.RemoveNodeTransformPosition(ActorRef, false, vanilla_sex == 1, "NPC", "SexLab.esm")
		bool UpdateNiOScale = NiOverride.RemoveNodeTransformScale(ActorRef, false, vanilla_sex == 1, "NPC", "SexLab.esm")
		If(UpdateNiOPosition || UpdateNiOScale)
			NiOverride.UpdateNodeTransform(ActorRef, false, vanilla_sex == 1, "NPC")
		EndIf
	EndIf
	Debug.SendAnimationEvent(ActorRef, "SOSFlaccid")
EndFunction

; Undo "LockActor"
Function UnlockActor()
	ActorRef.SetFactionRank(AnimatingFaction, -1)
	ActorRef.RemoveFromFaction(AnimatingFaction)
	If(ActorRef == PlayerRef)
		Game.SetPlayerAIDriven(false)
		MiscUtil.SetFreeCameraState(false)
		; COMEBACK: See LockActor()
    ; UI.SetBool("HUD Menu", "_root.HUDMovieBaseInstance._visible", true)
	Else
		ActorUtil.RemovePackageOverride(ActorRef, Thread.DoNothingPackage)
		ActorRef.EvaluatePackage()
		ActorRef.SetRestrained(false)
	endIf
	ActorRef.SetAnimationVariableBool("bHumanoidFootIKDisable", false)
EndFunction

; TODO: Completely overhaul this
Function DoStatistics()
	Actor VictimRef = Thread.VictimRef
	if IsVictim()
		VictimRef = ActorRef
	endIf
	int g = sslActorData.GetLegacyGenderByKey(_ActorData)
	float rt = SexLabUtil.GetCurrentGameRealTimeEx()
	sslActorStats.RecordThread(ActorRef, g, BestRelation, StartedAt, rt, Utility.GetCurrentGameTime(), Thread.HasPlayer, VictimRef, Thread.Genders, Thread.SkillXP)
	Stats.AddPartners(ActorRef, Thread.Positions, Thread.Victims)
	if Thread.IsVaginal
		Stats.AdjustSkill(ActorRef, "VaginalCount", 1)
	endIf
	if Thread.IsAnal
		Stats.AdjustSkill(ActorRef, "AnalCount", 1)
	endIf
	if Thread.IsOral
		Stats.AdjustSkill(ActorRef, "OlCount", 1)
	endIf
EndFunction

; ------------------------------------------------------- ;
; --- Misc Utility					                          --- ;
; ------------------------------------------------------- ;

Function Strip()
	int[] Strip
	If(StripOverride.Length == 2)
		Strip = StripOverride
	Else
		Strip = Config.GetStripSettings(vanilla_sex == 1, Thread.UseLimitedStrip(), Thread.IsType[0], IsVictim())
	EndIf
	; Gear
	If(Strip[1])
		RightHand = ActorRef.GetEquippedObject(1)
		If(RightHand && sslpp.CheckStrip(RightHand) != -1)
			ActorRef.UnequipItemEX(RightHand, ActorRef.EquipSlot_RightHand, false)
		EndIf
		LeftHand = ActorRef.GetEquippedObject(0)
		If(LeftHand && sslpp.CheckStrip(RightHand) != -1)
			ActorRef.UnequipItemEX(LeftHand, ActorRef.EquipSlot_LeftHand, false)
		EndIf
	EndIf
	Form[] gear = sslpp.StripActor(ActorRef, Strip[0])
	Equipment = PapyrusUtil.MergeFormArray(Equipment, gear)
	Log("STRIPPING -> Stripped Items: Weapon (Right):" + RightHand + " / Weapon (Left): " + LeftHand + " / Armor: " + Equipment)
	ActorRef.QueueNiNodeUpdate()
	; NiOverride High Heels
	If(Config.RemoveHeelEffect)
		If(ActorRef.GetWornForm(0x80))
			if Config.HasNiOverride
				bool UpdateNiOPosition = NiOverride.RemoveNodeTransformPosition(ActorRef, false, vanilla_sex == 1, "NPC", "SexLab.esm")
				if NiOverride.HasNodeTransformPosition(ActorRef, false, vanilla_sex == 1, "NPC", "internal")
					float[] pos = NiOverride.GetNodeTransformPosition(ActorRef, false, vanilla_sex == 1, "NPC", "internal")
					Log(pos, "RemoveHeelEffect (NiOverride)")
					pos[0] = -pos[0]
					pos[1] = -pos[1]
					pos[2] = -pos[2]
					NiOverride.AddNodeTransformPosition(ActorRef, false, vanilla_sex == 1, "NPC", "SexLab.esm", pos)
					NiOverride.UpdateNodeTransform(ActorRef, false, vanilla_sex == 1, "NPC")
				elseIf UpdateNiOPosition
					NiOverride.UpdateNodeTransform(ActorRef, false, vanilla_sex == 1, "NPC")
				endIf
			endIf
		EndIf
		HDTHeelSpell = sslpp.GetHDTHeelSpell(ActorRef)
		If(HDTHeelSpell)
			Log("Removing HDT Heel Effect: " + HDTHeelSpell)
			ActorRef.RemoveSpell(HDTHeelSpell)
		EndIf
	EndIf
EndFunction

Function UnStrip()
 	If(!DoRedress)
 		return
	EndIf
	If(LeftHand)
		ActorRef.EquipItemEx(LeftHand, ActorRef.EquipSlot_LeftHand)
	EndIf
	If(RightHand)
		ActorRef.EquipItemEx(RightHand, ActorRef.EquipSlot_RightHand)
	EndIf
 	int i = 0
 	While(i < Equipment.Length)
	 	ActorRef.EquipItemEx(Equipment[i], ActorRef.EquipSlot_Default)
		i += 1
 	EndWhile
	; HDTSpell is null if not removed by this script previously
	If(HDTHeelSpell && ActorRef.GetWornForm(0x00000080) && !ActorRef.HasSpell(HDTHeelSpell))
		ActorRef.AddSpell(HDTHeelSpell)
	EndIf
EndFunction

Function SendDefaultAnimEvent(bool Exit = False)
	PlayingAE = ""
	Debug.SendAnimationEvent(ActorRef, "AnimObjectUnequip")
	If(!sslActorData.IsCreature(_ActorData))
		Debug.SendAnimationEvent(ActorRef, "IdleForceDefaultState")
		return
	EndIf
	String racekey = sslActorData.GetRaceKey(_ActorData)
	If(racekey != "")
		if racekey == "Dragons"
			Debug.SendAnimationEvent(ActorRef, "FlyStopDefault")
			Debug.SendAnimationEvent(ActorRef, "Reset")
		elseIf racekey == "Hagravens"
			Debug.SendAnimationEvent(ActorRef, "ReturnToDefault")
			if Exit
				Debug.SendAnimationEvent(ActorRef, "Reset")
			endIf
		elseIf racekey == "Chaurus" || racekey == "ChaurusReapers"
			Debug.SendAnimationEvent(ActorRef, "FNISDefault")
		elseIf racekey == "DwarvenSpiders"
			Debug.SendAnimationEvent(ActorRef, "ReturnToDefault")
		elseIf racekey == "Draugrs" || racekey == "Seekers" || racekey == "DwarvenBallistas" || racekey == "DwarvenSpheres" || racekey == "DwarvenCenturions"
			Debug.SendAnimationEvent(ActorRef, "ForceFurnExit")
		elseIf racekey == "Trolls"
			Debug.SendAnimationEvent(ActorRef, "ReturnToDefault")
			if Exit
				Debug.SendAnimationEvent(ActorRef, "ForceFurnExit")
			endIf
		elseIf racekey == "Chickens" || racekey == "Rabbits" || racekey == "Slaughterfishes"
			Debug.SendAnimationEvent(ActorRef, "ReturnDefaultState")
			if Exit
				Debug.SendAnimationEvent(ActorRef, "ReturnToDefault")
			endIf
		elseIf racekey == "Werewolves" || racekey == "VampireLords"
			Debug.SendAnimationEvent(ActorRef, "IdleReturnToDefault")
		Else
			Debug.SendAnimationEvent(ActorRef, "ReturnToDefault")
		EndIf
	ElseIf(Exit)
		Debug.SendAnimationEvent(ActorRef, "ReturnDefaultState") 	; chicken, hare and slaughterfish before the "ReturnToDefault"
		Debug.SendAnimationEvent(ActorRef, "ReturnToDefault") 		; rest creature-animal
		Debug.SendAnimationEvent(ActorRef, "FNISDefault") 				; dwarvenspider and chaurus
		Debug.SendAnimationEvent(ActorRef, "IdleReturnToDefault") ; Werewolves and VampirwLords
		Debug.SendAnimationEvent(ActorRef, "ForceFurnExit") 			; Trolls afther the "ReturnToDefault" and draugr, daedras and all dwarven exept spiders
		Debug.SendAnimationEvent(ActorRef, "Reset") 							; Hagravens afther the "ReturnToDefault" and Dragons
	EndIf
EndFunction

; NOTE: Im not very confident that the idea aimed at here is really beneficial, even with the changes o+
; makes to SL this key seems to be contrustred so strictly that it will rarely actually save anything reusable
; users might have to manually readjust things with every animation (unnecessarily) due to this complexity here
String function GetActorKey()
	ActorBase base = ActorRef.GetLeveledActorBase()
	String ActorKey = MiscUtil.GetRaceEditorID(base.GetRace())
	If(!Config.RaceAdjustments)	; Based on RaceKey instead of Race
		If(sslCreatureAnimationSlots.HasRaceID("Canines", ActorKey))
			ActorKey = "Canines"
		Else
			ActorKey = sslActorData.GetRaceKey(_ActorData)
		EndIf
	EndIf
	If(sslActorData.IsCreature(_ActorData))
		ActorKey += "C"
		If(Config.useCreatureGender)
			If(sslActorData.IsFemaleCreature(_ActorData))
				ActorKey += "F"
			Else
				ActorKey += "M"
			EndIf
		EndIf
	ElseIf(sslActorData.IsFemale(_ActorData))
		ActorKey += "F"
	Else
		ActorKey += "M"
	EndIf
	If(!Config.ScaleActors)
		float ActorScalePlus
		If(Config.RaceAdjustments)
			ActorScalePlus = base.GetHeight()
		Else
			ActorScalePlus = ActorRef.GetScale()
		EndIf
		If(NioScale)
			ActorScalePlus = ActorScalePlus * NioScale
		EndIf
		ActorKey += ((ActorScalePlus * 25) + 0.5) as int
	EndIf
	return ActorKey
endFunction

; ------------------------------------------------------- ;
; --- Key Manipulation         				                --- ;
; ------------------------------------------------------- ;

int Function OverwriteMyGender(bool abToFemale)
	_ActorData = sslActorData.AddOverWrite(_ActorData, abToFemale)
	return _ActorData
EndFunction

int Function ResetDataKey()
	_ActorData = sslActorData.BuildDataKey(ActorRef, IsVictim())
	return _ActorData
EndFunction

; ------------------------------------------------------- ;
; --- Thread Events           				                --- ;
; ------------------------------------------------------- ;

function TrackedEvent(string EventName)
	If(Thread.ThreadLib.IsActorTracked(ActorRef))
		Thread.ThreadLib.SendTrackedEvent(ActorRef, EventName, Thread.tid)
	EndIf
endFunction

function RegisterEvents()
	string e = Thread.Key("")
	; Quick Events
	RegisterForModEvent(e+"Orgasm", "OrgasmEffect")
	; Sync Events
	RegisterForModEvent(e+"Prepare", "PrepareActor")
endFunction

function ClearEvents()
	string e = Thread.Key("")
	; Quick Events
	UnregisterForModEvent(e+"Orgasm")
	; Sync Events
	UnregisterForModEvent(e+"Prepare")
endFunction

; ------------------------------------------------------- ;
; --- Thread Setup    								                --- ;
; ------------------------------------------------------- ;

function Log(string msg, string src = "")
	msg = "Thread[" + Thread.tid + "] ActorAlias[" + GetActorName() + "/" + _ActorData + "] " + src + " - " + msg
	Debug.Trace("SEXLAB - " + msg)
	if Config.DebugMode
		SexLabUtil.PrintConsole(msg)
		Debug.TraceUser("SexLabDebug", msg)
	endIf
endFunction

Function Error(String msg)
	msg = "ActorAlias["+GetActorName()+"] - "+msg
	Debug.TraceStack("SEXLAB - " + msg)
	if Config.DebugMode
		SexLabUtil.PrintConsole(msg)
		Debug.TraceUser("SexLabDebug", msg)
	endIf
EndFunction

; Always called from the owning thread
Function Initialize()
	If(GetReference())
		If(GetState() == "Animating")
			UnplaceActor()
		EndIf
		Clear()
	EndIf
	; Forms
	ActorRef = none
	HadStrapon     = none
	Strapon        = none
	HDTHeelSpell   = none
	; Voice
	Voice          = none
	ActorVoice     = none
	IsForcedSilent = false
	; Expression
	Expression     = none
	Expressions    = sslUtility.ExpressionArray(0)
	; Flags
	_DoUndress     = true
	NoRedress      = false
	NoOrgasm       = false
	ForceOpenMouth = false
	; Integers
	Orgasms        = 0
	BestRelation   = 0
	BaseEnjoyment  = 0
	QuitEnjoyment  = 0
	FullEnjoyment  = 0
	PathingFlag    = 0
	_ActorData		 = 0
	; Floats
	LastOrgasm     = 0.0
	ActorScale     = 1.0
	AnimScale      = 1.0
	NioScale       = 1.0
	StartWait      = 0.0
	; Strings
	StartAnimEvent = ""
	PlayingAE      = ""
	; Storage
	StripOverride = Utility.CreateIntArray(0)
	Equipment = Utility.CreateFormArray(0)
	RightHand = none
	LeftHand = none
	GoToState("Empty")
EndFunction

; Only called once when the framework is first initialized
Function Setup()
	Thread = GetOwningQuest() as sslThreadModel
	Config = Thread.Config
	Stats = Thread.Stats

	PlayerRef = Game.GetPlayer()
	OrgasmFX = Config.OrgasmFX
	AnimatingFaction = Config.AnimatingFaction
EndFunction

; ------------------------------------------------------- ;
; --- State Restricted                                --- ;
; ------------------------------------------------------- ;

; Empty
bool Function SetActor(Actor ProspectRef)
	return SetActorEx(ProspectRef, false, none, false)
EndFunction
bool function SetActorEx(Actor akReference, bool abIsVictim, sslBaseVoice akVoice, bool abSilent)
	return false
endFunction
; Ready
Event PrepareActor()
EndEvent
function PathToCenter()
endFunction
Function SetData()
EndFunction
; Animating
function SyncThread()
endFunction
Function PlayAnimation(String asAnimation)
EndFunction
function OrgasmEffect()
endFunction
function DoOrgasm(bool Forced = false)
endFunction

; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*	;
;																																											;
;									██╗     ███████╗ ██████╗  █████╗  ██████╗██╗   ██╗									;
;									██║     ██╔════╝██╔════╝ ██╔══██╗██╔════╝╚██╗ ██╔╝									;
;									██║     █████╗  ██║  ███╗███████║██║      ╚████╔╝ 									;
;									██║     ██╔══╝  ██║   ██║██╔══██║██║       ╚██╔╝  									;
;									███████╗███████╗╚██████╔╝██║  ██║╚██████╗   ██║   									;
;									╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝   ╚═╝   									;
;																																											;
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*--*-*-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-*-*-*	;

Function LogRedundant(String asFunction)
	Debug.MessageBox("[SEXLAB]\nState '" + GetState() + "'; Function '" + asFunction + "' is an internal function made redundant.\nNo mod should ever be calling this. If you see this, the mod starting this scene integrates into SexLab in undesired ways.\n\nPlease report this to Scrab with a Papyrus Log attached")
	Debug.TraceStack("Invoking Legacy Content Function " + asFunction)
EndFunction

; ------------------------------------------------------- ;
; --- Legacy Content Supported                        --- ;
; ------------------------------------------------------- ;

int function GetGender()
	return sslActorData.GetLegacyGenderByKey(_ActorData)
endFunction

function OverrideStrip(bool[] SetStrip)
	if SetStrip.Length != 33
		Thread.Log("Invalid strip override bool[] - Must be length 33 - was "+SetStrip.Length, "OverrideStrip()")
		return
	endif
	StripOverride = new int[2]
	int i = 0
	int ii = 0
	While(i < 32)
		If(SetStrip[i])
			ii += Math.LeftShift(1, i)
		EndIF
		i += 1
	EndWhile
	StripOverride[0] = ii
	StripOverride[1] = SetStrip[32] as int
endFunction

function SetVictim(bool Victimize)
	_ActorData = sslActorData.BuildDataKey(ActorRef, Victimize)
endFunction

event OnOrgasm()
	OrgasmEffect()
endEvent
event OrgasmStage()
	OrgasmEffect()
endEvent

function SetEndAnimationEvent(string EventName)
	; EndAnimEvent = EventName
endFunction

function RefreshLoc()
	Thread.RealignActors()
endFunction

function SyncLocation(bool Force = false)
	Thread.RealignActors()
endFunction

function Snap()
	Thread.RealignActors()
endFunction

bool _DoRagdoll
bool property DoRagdoll hidden
	bool function get()
		return !_DoRagdoll && Config.RagdollEnd
	endFunction
	function set(bool value)
		_DoRagdoll = !value
	endFunction
endProperty

; ------------------------------------------------------- ;
; --- Internal Redundant                              --- ;
; ------------------------------------------------------- ;

function OffsetCoords(float[] Output, float[] CenterCoords, float[] OffsetBy) global native
bool function IsInPosition(Actor CheckActor, ObjectReference CheckMarker, float maxdistance = 30.0) global native

bool function ContinueStrip(Form ItemRef, bool DoStrip = true)
	return sslActorLibrary.ContinueStrip(ItemRef, DoStrip)
endFunction

int function IntIfElse(bool check, int isTrue, int isFalse)
	if check
		return isTrue
	endIf
	return isFalse
endfunction

function SetAdjustKey(string KeyVar)
	LogRedundant("SetAdjustKey")
endfunction
function AttachMarker()
	LogRedundant("AttachMarker")
endFunction
function LoadShares()
	LogRedundant("LoadShares")
endFunction
function GetPositionInfo()
	LogRedundant("GetPositionInfo")
endFunction
function SyncActor()
	LogRedundant("SyncActor")
endFunction
function SyncAll(bool Force = false)
	LogRedundant("SyncAll")
endFunction
function RefreshActor()
	LogRedundant("RefreshActor")
endFunction
function ClearAlias()
	LogRedundant("ClearAlias")
endFunction
function RestoreActorDefaults()
	LogRedundant("RestoreActorDefaults")
endFunction
function SendAnimation()
	LogRedundant("SendAnimation")
endFunction
function StopAnimating(bool Quick = false, string ResetAnim = "IdleForceDefaultState")
	LogRedundant("StopAnimating")
endFunction
function StartAnimating()
	LogRedundant("OnBeginState")
endFunction
event ResetActor()
	LogRedundant("ResetActor")
endEvent
function ClearEffects()
	LogRedundant("ClearEffects")
endFunction