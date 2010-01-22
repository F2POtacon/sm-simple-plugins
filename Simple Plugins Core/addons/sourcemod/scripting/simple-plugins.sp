/************************************************************************
*************************************************************************
Simple Plugins
Description:
	Core plugin for Simple Plugins project
*************************************************************************
*************************************************************************
This file is part of Simple Plugins project.

This plugin is free software: you can redistribute 
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or
later version. 

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************
File Information
$Id$
$Author$
$Revision$
$Date$
$LastChangedBy$
$LastChangedDate$
$URL$
$Copyright: (c) Simple Plugins 2008-2009$
*************************************************************************
*************************************************************************
*/

#define CORE_PLUGIN_VERSION "1.1.$Rev$"

#include <simple-plugins>

enum	e_PlayerInfo
{
	Handle:hForcedTeamPlugin = INVALID_HANDLE,
	iForcedTeam = 0,
	iBuddy = 0,
	bool:bBuddyLocked = false
};

new 	Handle:g_fwdPlayerMoved;

new 	g_aPlayers[MAXPLAYERS + 1][e_PlayerInfo];

new 	bool:g_bTeamsSwitched = false;
new 	bool:g_bBuddyEnabled = true;
new 	bool:g_bBuddyRestriction = false;

new		String:g_sAdminFlag[16];

/**
Setting our plugin information.
*/
public Plugin:myinfo =
{
	name = "Simple Plugins Core Plugin",
	author = "Simple Plugins",
	description = "Core plugin for Simple Plugins",
	version = CORE_PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
};

public bool:AskPluginLoad(Handle:myself, bool:late, String:error[], err_max)
{

	/**
	Register natives for other plugins
	*/
	CreateNative("SM_MovePlayer", Native_SM_MovePlayer);
	CreateNative("SM_SetForcedTeam", Native_SM_SetForcedTeam);
	CreateNative("SM_GetForcedTeam", Native_SM_GetForcedTeam);
	CreateNative("SM_ClearForcedTeam", Native_SM_ClearForcedTeam);
	CreateNative("SM_GetForcedPlayer", Native_SM_GetForcedPlayer);
	CreateNative("SM_AssignBuddy", Native_SM_AssignBuddy);
	CreateNative("SM_GetClientBuddy", Native_SM_GetClientBuddy);
	CreateNative("SM_LockBuddy", Native_SM_LockBuddy);
	CreateNative("SM_IsBuddyLocked", Native_SM_IsBuddyLocked);
	CreateNative("SM_ClearBuddy", Native_SM_ClearBuddy);
	RegPluginLibrary("simpleplugins");
	return true;
}

public OnPluginStart()
{
	
	CreateConVar("ssm_core_pl_ver", CORE_PLUGIN_VERSION, "Simple Plugins Core Plugin Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("ssm_core_inc_ver", CORE_INC_VERSION, "Simple Plugins Core Include Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("ssm_core_l4d_ver", CORE_SM_INC_VERSION, "Simple Plugins Core SM Include Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("ssm_core_tf2_ver", CORE_TF2_INC_VERSION, "Simple Plugins Core TF2 Include Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("ssm_core_l4d_ver", CORE_L4D_INC_VERSION, "Simple Plugins Core L4D Include Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	/**
	Get game type and load the team numbers
	*/
	g_CurrentMod = GetCurrentMod();
	LoadCurrentTeams();
	
	/**
	Hook some events to control forced players and check extensions
	*/
	decl String:sExtError[256];
	LogMessage("[SSM] Hooking events for [%s].", g_sGameName[g_CurrentMod]);
	HookEvent("player_team", HookPlayerChangeTeam, EventHookMode_Pre);
	switch (g_CurrentMod)
	{
		case GameType_CSS:
		{
			HookEvent("round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("round_end", HookRoundEnd, EventHookMode_PostNoCopy);
			new iExtStatus = GetExtensionFileStatus("game.cstrike.ext", sExtError, sizeof(sExtError));
			if (iExtStatus == -2)
			{
				LogMessage("[SSM] Required extension was not found.");
				LogMessage("[SSM] Plugin FAILED TO LOAD.");
				SetFailState("Required extension was not found.");
			}
			if (iExtStatus == -1 || iExtStatus == 0)
			{
				LogMessage("[SSM] Required extension is loaded with errors.");
				LogMessage("[SSM] Status reported was [%s].", sExtError);
				LogMessage("[SSM] Plugin FAILED TO LOAD.");
				SetFailState("Required extension is loaded with errors.");
			}
			if (iExtStatus == 1)
			{
				LogMessage("[SSM] Required extension is loaded.");
			}
		}
		case GameType_TF:
		{
			HookEvent("teamplay_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("teamplay_round_win", HookRoundEnd, EventHookMode_PostNoCopy);
			HookUserMessage(GetUserMessageId("TextMsg"), UserMessageHook_Class, true);
			new iExtStatus = GetExtensionFileStatus("game.tf2.ext", sExtError, sizeof(sExtError));
			if (iExtStatus == -2)
			{
				LogMessage("[SSM] Required extension was not found.");
				LogMessage("[SSM] Plugin FAILED TO LOAD.");
				SetFailState("Required extension was not found.");
			}
			if (iExtStatus == -1 || iExtStatus == 0)
			{
				LogMessage("[SSM] Required extension is loaded with errors.");
				LogMessage("[SSM] Status reported was [%s].", sExtError);
				LogMessage("[SSM] Plugin FAILED TO LOAD.");
				SetFailState("Required extension is loaded with errors.");
			}
			if (iExtStatus == 1)
			{
				LogMessage("[SSM] Required extension is loaded.");
			}
		}
		case GameType_DOD:
		{
			HookEvent("dod_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("dod_round_win", HookRoundEnd, EventHookMode_PostNoCopy);
		}
		default:
		{
			HookEvent("round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("round_end", HookRoundEnd, EventHookMode_PostNoCopy);
		}
	}
	
	/**
	Create console commands
	*/
	RegConsoleCmd("sm_buddy", Command_AddBalanceBuddy, "Add a balance buddy");
	RegConsoleCmd("sm_lockbuddy", Command_LockBuddy, "Locks your balance buddy selection");
	
	/**
	Load common translations
	*/
	LoadTranslations ("common.phrases");
	
	/**
	Create the global forward
	*/
	g_fwdPlayerMoved = CreateGlobalForward("SM_OnPlayerMoved", ET_Event, Param_Cell, Param_Cell, Param_Cell);
}

public OnClientDisconnect(client)
{

	/**
	Cleanup clients/players buddy list
	*/
	if (!IsFakeClient(client))
	{
		SM_ClearBuddy(client, true);
		SM_LockBuddy(client, false);
	}
	SM_ClearForcedTeam(client);
}


public Action:Command_AddBalanceBuddy(client, args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %T", "PlayerLevelCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	if (!g_bBuddyEnabled) 
	{
		ReplyToCommand(client, "[SM] %T", "CmdDisabled", LANG_SERVER);
		return Plugin_Handled;
	}
	if (g_bBuddyRestriction) 
	{
		if (!IsValidAdmin(client, g_sAdminFlag)) 
		{
			ReplyToCommand(client, "[SM] %T", "RestrictedBuddy", LANG_SERVER);
			return Plugin_Handled;
		}
	}
	decl String:sPlayerUserId[24];
	GetCmdArg(1, sPlayerUserId, sizeof(sPlayerUserId));
	new iPlayer = GetClientOfUserId(StringToInt(sPlayerUserId));
	if (!iPlayer || !IsClientInGame(iPlayer) || client == iPlayer) 
	{
		if (client == iPlayer) 
		{
			PrintHintText(client, "%T", "SelectSelf", LANG_SERVER);
		}
		ReplyToCommand(client, "[SM] Usage: buddy <userid>");
		DisplayPlayerMenu(client);
	} 
	else 
	{
		decl String:cName[128];
		decl String:bName[128];
		GetClientName(client, cName, sizeof(cName));
		GetClientName(iPlayer, bName, sizeof(bName));
		if (SM_IsBuddyLocked(iPlayer)) 
		{
			ReplyToCommand(client, "[SM] %T", "PlayerLockedBuddyMsg", LANG_SERVER, bName);
			return Plugin_Handled;
		}
		SM_AssignBuddy(client, iPlayer);
		PrintHintText(client, "%T", "BuddyMsg", LANG_SERVER, bName);
		PrintHintText(iPlayer, "%T", "BuddyMsg", LANG_SERVER, cName);
	}
	return Plugin_Handled;	
}

public Action:Command_LockBuddy(client, args)
{
	if (client == 0) 
	{
		ReplyToCommand(client, "[SM] %T", "PlayerLevelCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	if (g_bBuddyRestriction)
	{
		if (!IsValidAdmin(client, g_sAdminFlag)) 
		{
			ReplyToCommand(client, "[SM] %T", "RestrictedBuddy", LANG_SERVER);
			return Plugin_Handled;
		}
	}
	if (SM_IsBuddyLocked(client)) 
	{
		SM_LockBuddy(client, false);
		PrintHintText(client, "%T", "BuddyLockMsgDisabled", LANG_SERVER);
	} 
	else 
	{
		SM_LockBuddy(client, true);
		PrintHintText(client, "%T", "BuddyLockMsgEnabled", LANG_SERVER);
	}
	return Plugin_Handled;
}


public HookRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	/**
	See if the teams have been switched
	*/
	if (g_bTeamsSwitched)
	{
		
		/**
		Switch the teams the players are forced to
		*/
		for (new i = 1; i <= MaxClients; i++) 
		{
			if (g_aPlayers[i][iForcedTeam] != 0)
			{
				if (g_aPlayers[i][iForcedTeam] == g_aCurrentTeams[Team1])
				{
					g_aPlayers[i][iForcedTeam] = g_aCurrentTeams[Team2];
				}
				else
				{
					g_aPlayers[i][iForcedTeam] = g_aCurrentTeams[Team1];
				}
			}
		}
	}
}

public HookRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bTeamsSwitched = false;
}

public Action:HookPlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Get our event variables
	*/
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new iTeam = GetEventInt(event, "team");
	
	/**
	See if the player is on the wrong team
	*/
	if (g_aPlayers[iClient][iForcedTeam] != 0 && g_aPlayers[iClient][iForcedTeam] != iTeam)
	{
	
		/**
		Move the player back to the forced team
		*/
		CreateTimer(1.0, Timer_ForcePlayerMove, iClient, TIMER_FLAG_NO_MAPCHANGE);
		
		/**
		If the event was going to be broadcasted, we refire it so it is not broadcasted and stop this one
		*/
		if (!dontBroadcast)
		{
			new Handle:hEvent = CreateEvent("player_team");
			SetEventInt(hEvent, "userid", GetEventInt(event, "userid"));
			SetEventInt(hEvent, "team", GetEventInt(event, "team"));
			SetEventInt(hEvent, "oldteam", GetEventInt(event, "oldteam"));
			SetEventBool(hEvent, "disconnect", GetEventBool(event, "disconnect"));
		
			if (g_CurrentMod == GameType_DOD || g_CurrentMod == GameType_L4D || g_CurrentMod == GameType_TF)
			{
				new String:sClientName[MAX_NAME_LENGTH + 1];
				GetClientName(iClient, sClientName, sizeof(sClientName));
				SetEventBool(hEvent, "autoteam", GetEventBool(event, "autoteam"));
				SetEventBool(hEvent, "silent", true);
				SetEventString(hEvent, "name", sClientName);
				FireEvent(hEvent, true);
			}
			else
			{
				FireEvent(hEvent, true);
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:UserMessageHook_Class(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	new String:sMessage[120];
	BfReadString(bf, sMessage, sizeof(sMessage), true);
	if (StrContains(sMessage, "#TF_TeamsSwitched", false) != -1)
	{
		g_bTeamsSwitched = true;
	}
	return Plugin_Continue;
}

public Native_SM_MovePlayer(Handle:plugin, numParams)
{

	/**
	Get and check the client and team
	*/
	new iClient = GetNativeCell(1);
	new iTeam = GetNativeCell(2);
	new bool:bRespawn = GetNativeCell(3) ? true : false;
	if (iClient < 1 || iClient > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid client index (%d)", iClient);
	}
	if (!IsClientConnected(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not connected", iClient);
	}
	if (!IsClientInGame(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in the game", iClient);
	}
	if (iTeam != g_aCurrentTeams[Spectator] && iTeam != g_aCurrentTeams[Team1] && iTeam != g_aCurrentTeams[Team2])
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid team %d", iTeam);
	}
	
	MovePlayer(iClient, iTeam);
	if (!IsClientObserver(iClient) && bRespawn)
	{
		RespawnPlayer(iClient);
	}
	
	new fResult;
	
	Call_StartForward(g_fwdPlayerMoved);
	Call_PushCell(plugin);
	Call_PushCell(iClient);
	Call_PushCell(iTeam);
	Call_Finish(fResult);
	
	if (fResult != SP_ERROR_NONE)
	{
		return ThrowNativeError(fResult, "Forward failed");
	}

	return fResult;
}

public Native_SM_SetForcedTeam(Handle:plugin, numParams)
{

	/**
	Get and check the client and team
	*/
	new iClient = GetNativeCell(1);
	new iTeam = GetNativeCell(2);
	if (iClient < 1 || iClient > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid client index (%d)", iClient);
	}
	if (!IsClientConnected(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not connected", iClient);
	}
	if (!IsClientInGame(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in the game", iClient);
	}
	if (iTeam != g_aCurrentTeams[Spectator] && iTeam != g_aCurrentTeams[Team1] && iTeam != g_aCurrentTeams[Team2] && iTeam != g_aCurrentTeams[Unknown])
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid team %d", iTeam);
	}
	
	new bool:bOverRide = GetNativeCell(3) ? true : false;
	
	if (!bOverRide && g_aPlayers[iClient][hForcedTeamPlugin] != INVALID_HANDLE && plugin != g_aPlayers[iClient][hForcedTeamPlugin])
	{
		return false;
	}
	
	g_aPlayers[iClient][hForcedTeamPlugin] = plugin;
	g_aPlayers[iClient][iForcedTeam] = iTeam;
	return true;
}

public Native_SM_GetForcedTeam(Handle:plugin, numParams)
{

	/**
	Get and check the client
	*/
	new iClient = GetNativeCell(1);
	if (iClient < 1 || iClient > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid client index (%d)", iClient);
	}
	if (!IsClientConnected(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not connected", iClient);
	}
	if (!IsClientInGame(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in the game", iClient);
	}
	
	/**
	Get and set the plugin if they want it
	*/
	new Handle:hPlugin = GetNativeCell(2);
	if (hPlugin != INVALID_HANDLE)
	{
		SetNativeCellRef(2, g_aPlayers[iClient][hForcedTeamPlugin]);
	}
	
	/**
	Return the forced team, this could be 0
	*/
	return g_aPlayers[iClient][iForcedTeam];
}

public Native_SM_ClearForcedTeam(Handle:plugin, numParams)
{

	/**
	Get and check the client and team
	*/
	new iClient = GetNativeCell(1);
	if (iClient < 1 || iClient > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid client index (%d)", iClient);
	}
	if (!IsClientConnected(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not connected", iClient);
	}
	
	g_aPlayers[iClient][hForcedTeamPlugin] = INVALID_HANDLE;
	g_aPlayers[iClient][iForcedTeam] = 0;
	
	return true;
}

public Native_SM_GetForcedPlayer(Handle:plugin, numParams)
{
	
	/**
	Get and check the team
	*/
	new iTeam = GetNativeCell(1);
	if (iTeam != g_aCurrentTeams[Spectator] && iTeam != g_aCurrentTeams[Team1] && iTeam != g_aCurrentTeams[Team2])
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid team %d", iTeam);
	}
	
	/**
	Start a loop to check for a player on the wrong team
	Also make sure the plugin that set the forced team is the plugin that asked
	*/
	new iPlayer = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) 
		&& GetClientTeam(i) != g_aPlayers[i][iForcedTeam] 
		&& g_aPlayers[i][iForcedTeam] == iTeam
		&& g_aPlayers[i][hForcedTeamPlugin] == plugin)
		{
			iPlayer = i;
			break;
		}
	}
	
	/**
	Return the player we found, this could be 0
	*/
	return iPlayer;
}

public Native_SM_AssignBuddy(Handle:plugin, numParams)
{

	/**
	Get and check the client and player
	*/
	new iClient = GetNativeCell(1);
	new iPlayer = GetNativeCell(2);
	if (iClient < 1 || iClient > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid client index (%d)", iClient);
	}
	if (!IsClientConnected(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not connected", iClient);
	}
	if (!IsClientInGame(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in the game", iClient);
	}
	if (iPlayer < 0 || iPlayer > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid player index (%d)", iPlayer);
	}
	if (!IsClientConnected(iPlayer))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Player %d is not connected", iPlayer);
	}
	if (!IsClientInGame(iPlayer))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Player %d is not in the game", iClient);
	}
	if (IsFakeClient(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Bots are not supported");
	}
	
	/**
	See if we can override his setting
	*/
	new bool:bOverRide = GetNativeCell(3) ? true : false;
	if (!bOverRide)
	{
	
		/**
		We can't override, so check if they are locked
		*/
		if (g_aPlayers[iClient][bBuddyLocked] || g_aPlayers[iPlayer][bBuddyLocked])
		{
		
			/**
			We detected at least 1 lock, so we bug out
			*/
			return false;
		}
	}
	
	/**
	Ready to set the buddies
	*/
	g_aPlayers[iClient][iBuddy] = iPlayer;
	g_aPlayers[iPlayer][iBuddy] = iClient;
	return true;
}

public Native_SM_GetClientBuddy(Handle:plugin, numParams)
{

	/**
	Get and check the client 
	*/
	new iClient = GetNativeCell(1);
	if (iClient < 1 || iClient > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid client index (%d)", iClient);
	}
	if (!IsClientConnected(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not connected", iClient);
	}
	if (!IsClientInGame(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in the game", iClient);
	}
	if (IsFakeClient(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Bots are not supported");
	}
	
	/**
	Return the players buddy, this could be 0
	*/
	return g_aPlayers[iClient][iBuddy];	
}

public Native_SM_LockBuddy(Handle:plugin, numParams)
{

	/**
	Get and check the client 
	*/
	new iClient = GetNativeCell(1);
	new bool:bSetting = GetNativeCell(2) ? true : false;
	if (iClient < 1 || iClient > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid client index (%d)", iClient);
	}
	if (!IsClientConnected(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not connected", iClient);
	}
	if (IsFakeClient(iClient))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Bots are not supported");
	}
	
	g_aPlayers[iClient][bBuddyLocked] = bSetting;
	return true;
}

public Native_SM_IsBuddyLocked(Handle:plugin, numParams)
{

	/**
	Get and check the client 
	*/
	new iClient = GetNativeCell(1);
	if (iClient < 1 || iClient > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Invalid client index (%d)", iClient);
	}
	if (!IsClientConnected(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not connected", iClient);
	}
	if (!IsClientInGame(iClient))
	{
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in the game", iClient);
	}
	if (IsFakeClient(iClient))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Bots are not supported");
	}
	
	return g_aPlayers[iClient][bBuddyLocked];
}

public Native_SM_ClearBuddy(Handle:plugin, numParams)
{

	/**
	Get and check the client
	*/
	new iClient = GetNativeCell(1);
	if (iClient < 1 || iClient > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", iClient);
	}
	if (!IsClientConnected(iClient))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is not connected", iClient);
	}
	if (IsFakeClient(iClient))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Bots are not supported");
	}
	
	/**
	Get the clients buddy and see if we can override his setting
	*/
	new bool:bOverRide = GetNativeCell(2) ? true : false;
	new iPlayer = g_aPlayers[iClient][iBuddy];
	
	/**
	There is no buddy, we don't care about anything else so bug out
	*/
	if (iPlayer == 0)
	{
		return true;
	}
	
	/**
	We determined he had a buddy, check the override setting
	*/
	if (!bOverRide)
	{
	
		/**
		We can't override, so check if they are locked
		*/
		if (g_aPlayers[iClient][bBuddyLocked] || g_aPlayers[iPlayer][bBuddyLocked])
		{
		
			/**
			We detected at least 1 lock, so we bug out
			*/
			return false;
		}
	}
	
	/**
	Ready to clear the buddies
	*/
	g_aPlayers[iClient][iBuddy] = 0;
	g_aPlayers[iPlayer][iBuddy] = 0;
	return true;
}

public Native_SM_IsValidTeam(Handle:plugin, numParams)
{

	/**
	Get the team
	*/
	new iTeam = GetNativeCell(1);
	
	/**
	Check the team
	*/
	if (iTeam == g_aCurrentTeams[Spectator] || iTeam == g_aCurrentTeams[Team1] || iTeam == g_aCurrentTeams[Team2])
	{
		return true;
	}
	return false;
}

public Action:Timer_ForcePlayerMove(Handle:timer, any:iClient)
{

	MovePlayer(iClient, g_aPlayers[iClient][iForcedTeam]);
	
	if (g_aPlayers[iClient][iForcedTeam] != g_aCurrentTeams[Spectator])
	{
		RespawnPlayer(iClient);
	}
	
	PrintToChat(iClient, "\x01\x04----------------------------------");
	PrintToChat(iClient, "\x01\x04You have been forced to this team.");
	PrintToChat(iClient, "\x01\x04----------------------------------");
	
	return Plugin_Handled;
}

stock DisplayPlayerMenu(client, time = MENU_TIME_FOREVER)
{
	new Handle:hMenu = CreateMenu(Menu_SelectPlayer);
	AddTargetsToMenu(hMenu, 0, true, false);
	SetMenuTitle(hMenu, "Select A Player:");
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, client, time);
}

public Menu_SelectPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sSelection[24];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		new buddy = GetClientOfUserId(StringToInt(sSelection));
		new client = param1;
		if (client == buddy) 
		{
			PrintHintText(client, "%t", "SelectSelf");
		}
		else if (!IsClientInGame(buddy)) 
		{
			PrintHintText(client, "%t", "BuddyGone");
		}
		else 
		{
			decl String:cName[128];
			decl String:bName[128];
			GetClientName(client, cName, sizeof(cName));
			GetClientName(buddy, bName, sizeof(bName));
			if (!SM_IsBuddyLocked(buddy)) 
			{
				SM_AssignBuddy(client, buddy);
				PrintHintText(client, "%t", "BuddyMsg", bName);
				PrintHintText(buddy, "%t", "BuddyMsg", cName);
			} 
			else
			{
				PrintHintText(client, "%t", "PlayerLockedBuddyMsg", bName);
			}
		}
	} 
	else if (action == MenuAction_End) 
	{
		CloseHandle(menu);
	}
}

stock MovePlayer(iClient, iTeam)
{

	/**
	Change the client's team based on the mod
	*/
	switch (g_CurrentMod)
	{
		case GameType_CSS:
		{
			CS_SwitchTeam(iClient, iTeam);
		}
		default:
		{
			ChangeClientTeam(iClient, iTeam);
		}
	}
}

stock RespawnPlayer(iClient)
{

	/**
	Respawn the client based on the mod
	*/
	switch (g_CurrentMod)
	{
		case GameType_CSS:
		{
			CS_RespawnPlayer(iClient);
		}
		case GameType_TF:
		{
			TF2_RespawnPlayer(iClient);
		}
		case GameType_INS:
		{
			FakeClientCommand(iClient, "kill");
		}
		default:
		{
			//
		}
	}
}
