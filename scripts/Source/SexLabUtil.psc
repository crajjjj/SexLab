scriptname SexLabUtil hidden

bool function SexLabIsActive() global
	bool active
	int i
	while i < Game.GetModCount() && !active
		active = Game.GetModName(i) == "SexLab.esm"
		i += 1
	endWhile
	return active
endFunction

SexLabFramework function GetAPI() global
	if !SexLabIsActive()
		return none
	endIf
	return (Game.GetFormFromFile(0x0D62, "SexLab.esm") as Quest) as SexLabFramework
endFunction

int function StartSex(actor[] sexActors, sslBaseAnimation[] anims, actor victim = none, ObjectReference centerOn = none, bool allowBed = true, string hook = "") global
	SexLabFramework SexLab = GetAPI()
	if SexLab == none
		return -1
	endIf
	return SexLab.StartSex(sexActors, anims, victim, centerOn, allowBed, hook)
endFunction

sslThreadModel function NewThread(float timeout = 5.0) global
	SexLabFramework SexLab = GetAPI()
	if SexLab == none
		return none
	endIf
	return SexLab.NewThread(timeout)
endFunction

function Log(string msg, string source, string type = "NOTICE", string display = "trace", bool minimal = false) global
	int severity = 0
	if type == "ERROR" || type == "FATAL"
		severity = 2
	elseif type == "NOTICE" || type == "DEBUG"
		severity = 1
	endIf
	if StringUtil.Find(display, "trace") != -1
		if minimal
			Debug.Trace("-- SexLab "+type+"-- "+source+": "+msg, severity)
		else
			Debug.Trace("--- SexLab "+source+" --------------------------------", severity)
			Debug.Trace(" "+type+":", severity)
			Debug.Trace("   "+msg, severity)
			Debug.Trace("-----------------------------------------------------------", severity)
		endIf
	endIf
	if StringUtil.Find(display, "box") != -1
		Debug.MessageBox(type+" "+source+": "+msg)
	endIf
	if StringUtil.Find(display, "notif") != -1
		Debug.Notification(type+": "+msg)
	endIf
	if StringUtil.Find(display, "stack") != -1
		Debug.TraceStack("-- SexLab "+type+"-- "+source+": "+msg, severity)
	endIf
endFunction