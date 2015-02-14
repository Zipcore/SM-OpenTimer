public Action Command_Help( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;	
	
	PrintToConsole( client, "Commands:\n-------------------" );
	
	PrintToConsole( client, "!respawn/!spawn/!restart/!start/!r/!re - Respawn\n!normal/!sideways/!w/!rhsw/!hsw/!style - Changes your style accordingly.\n!spectate/!spec <name> - Spectate a player. Or, go spectator.\n!fov/!fieldofview <number> - Change your field of view.\n!hud/!showhud/!hidehud - Toggle HUD elements.\n!commands - This ;)\n!wr/!records/!times - Show top 5 times.\n!printrecords <type> - Shows a detailed version. b1/b2/w/sw/n/rhsw/hsw Max. 16 times.\n!practise/!practice/!prac - Use practice mode.\n!saveloc/!save - Save point for practice mode.\n!gotocp/!cp - Teleport into the saved point.\n!main - Go back to main run.\n!b 1/2 - Go to bonus 1/2 runs." );
	
#if defined VOTING
	PrintToConsole( client, "!choosemap - Vote for a map! (All players required.)" );
#endif
	
	PrintToConsole( client, "-------------------" );
	
	PrintColorChat( client, client, "%s Printed all used commands to your console!\nShort version:\x05 !restart/!respawn, !fov <number>, !hud, !viewmodel, !prac, !spec <name>, !wr, !printrecords <type>, !choosemap", CHAT_PREFIX );
	
	return Plugin_Handled;
}

/*public Action Command_AutoHop( int client, int args )
{
	if ( GetConVarBool( g_ConVar_AutoHop ) )
	{
		g_bClientAutoHop[client] = !g_bClientAutoHop[client];
		
		if ( g_bClientAutoHop[client] )
			PrintColorChat( client, client, "%s Autobhop is enabled!", CHAT_PREFIX );
		else
			PrintColorChat( client, client, "%s Autobhop is disabled!", CHAT_PREFIX );
	}
	else PrintColorChat( client, client, "%s Access denied.", CHAT_PREFIX );
}*/

public Action Command_Spawn( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( GetClientTeam( client ) == CS_TEAM_SPECTATOR )
		ChangeClientTeam( client, g_iPreferedTeam );
	else if ( !IsPlayerAlive( client ) || !g_bIsLoaded[ g_iClientRun[client] ] )
		CS_RespawnPlayer( client );
	else
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
	
	return Plugin_Handled;
}

public Action Command_Spectate( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( args == 0 ) ChangeClientTeam( client, CS_TEAM_SPECTATOR );
	else
	{
		char szTarget[MAX_NAME_LENGTH];
		if ( GetCmdArgString( szTarget, sizeof( szTarget ) ) < 1 )
		{
			ChangeClientTeam( client, CS_TEAM_SPECTATOR );
			
			PrintColorChat( client, client, "%s Couldn't find the player you were looking for.", CHAT_PREFIX );
			
			return Plugin_Handled;
		}
		
		int target = FindTarget( client, szTarget, false, false );
		
		if ( target < 1 || !IsClientInGame( target ) || !IsPlayerAlive( client ) )
			return Plugin_Handled;
		
		ChangeClientTeam( client, CS_TEAM_SPECTATOR );
		
		SetEntPropEnt( client, Prop_Send, "m_hObserverTarget", target );
		SetEntProp( client, Prop_Send, "m_iObserverMode", 2 );
	}

	return Plugin_Handled;
}

public Action Command_FieldOfView( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( args == 1 )
	{
		char szNum[4];
		GetCmdArgString( szNum, sizeof( szNum ) );
		
		int fov = StringToInt( szNum );
		
		if ( fov > 150 )
		{
			PrintColorChat( client, client, "%s Your desired field of view is too damn high! Max. 150", CHAT_PREFIX );	
			return Plugin_Handled;
		}
		else if ( fov < 70 )
		{
			PrintColorChat( client, client, "%s Your desired field of view is too low! Min. 70", CHAT_PREFIX );
			return Plugin_Handled;
		}
		
		SetClientFOV( client, fov, true );
		g_iClientFOV[client] = fov;
		
		if ( !SaveClientInfo( client ) )
			PrintColorChat( client, client, "%s Couldn't save your option to database!", CHAT_PREFIX );
	}
	else
		PrintColorChat( client, client, "%s Usage: sm_fov <number> (value between 70 and 150)", CHAT_PREFIX );
	
	return Plugin_Handled;
}

public Action Command_RecordsMOTD( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have map bounds! No records can be found.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	PrintRecords( client, false );
	
	return Plugin_Handled;
}

public Action Command_RecordsPrint( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have map bounds! No records can be found.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( args < 1 )
		PrintRecords( client, true );
	else
	{
		char szArg[12];
		GetCmdArgString( szArg, sizeof( szArg ) );
		
		StripQuotes( szArg );
		
		if ( StrEqual( szArg, "b", false ) || StrEqual( szArg, "b1", false ) || StrEqual( szArg, "bonus1", false ) )
		{
			if ( !g_bZoneExists[RUN_BONUS_1] )
			{
				PrintColorChat( client, client, "%s \x03%s%s records do not exist!", CHAT_PREFIX, g_szRunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
				return Plugin_Handled;
			}
			
			PrintRecords( client, true, STYLE_NORMAL, RUN_BONUS_1 );
		}
		else if ( StrEqual( szArg, "b2", false ) || StrEqual( szArg, "bonus2", false ) )
		{
			if ( !g_bZoneExists[RUN_BONUS_2] )
			{
				PrintColorChat( client, client, "%s \x03%s%s records do not exist!", CHAT_PREFIX, g_szRunName[NAME_LONG][RUN_BONUS_2], COLOR_TEXT );
				return Plugin_Handled;
			}
			
			PrintRecords( client, true, STYLE_NORMAL, RUN_BONUS_2 );
		}
		else if ( StrEqual( szArg, "normal", false ) || StrEqual( szArg, "n", false ) )
		{
			PrintRecords( client, true, STYLE_NORMAL );
		}
		else if ( StrEqual( szArg, "sideways", false ) || StrEqual( szArg, "sw", false ) )
		{
			PrintRecords( client, true, STYLE_SIDEWAYS );
		}
		else if ( StrEqual( szArg, "w-only", false ) || StrEqual( szArg, "w", false ) )
		{
			PrintRecords( client, true, STYLE_W );
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Style_Normal( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_NORMAL;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_NORMAL], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );
		
	return Plugin_Handled;
}

public Action Command_Style_Sideways( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_SIDEWAYS;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_SIDEWAYS], COLOR_TEXT );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );
		
	return Plugin_Handled;
}

public Action Command_Style_W( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_W;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_W], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );

	return Plugin_Handled;
}

public Action Command_Style_RealHSW( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_REAL_HSW;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_REAL_HSW], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );

	return Plugin_Handled;
}

public Action Command_Style_HSW( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_HSW;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_HSW], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );

	return Plugin_Handled;
}

public Action Command_Practise( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You have to be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have records enabled!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	g_bIsClientPractising[client] = !g_bIsClientPractising[client];
	
	if ( g_bIsClientPractising[client] )
		PrintColorChat( client, client, "%s You're now in \x03practice%s mode! Type \x03!prac%s to toggle.", CHAT_PREFIX, COLOR_TEXT, COLOR_TEXT );
	else
		PrintColorChat( client, client, "%s You're now in \x03normal%s running mode!", CHAT_PREFIX, COLOR_TEXT );
	
	g_iClientState[client] = STATE_START;
	g_flClientStartTime[client] = TIME_INVALID;
	
#if defined RECORD
	g_bIsClientRecording[client] = false;
#endif
	
	return Plugin_Handled;
}

public Action Command_Practise_SavePoint( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsClientPractising[client] )
	{
		PrintColorChat( client, client, "%s You have to be in practice mode! (\x03!practise/!practice/!prac%s)", CHAT_PREFIX, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You have to be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	g_flClientSaveTime[client] = GetEngineTime();
	
	GetClientAbsAngles( client, g_vecClientSaveAng[client] );
	GetClientAbsOrigin( client, g_vecClientSavePos[client] );
	GetEntPropVector( client, Prop_Data, "m_vecAbsVelocity", g_vecClientSaveVel[client] );
	
	PrintColorChat( client, client, "Saved location!" );
	
	return Plugin_Handled;
}

public Action Command_Practise_GotoPoint( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsClientPractising[client] )
	{
		PrintColorChat( client, client, "%s You have to be in practice mode! (\x03!practise/!practice/!prac%s)", CHAT_PREFIX, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You have to be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( g_flClientSaveTime[client] == TIME_INVALID )
	{
		PrintColorChat( client, client, "%s You must save a location first! (\x03!save/!saveloc%s)", CHAT_PREFIX, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	g_flClientStartTime[client] += GetEngineTime() - g_flClientSaveTime[client];
	g_flClientSaveTime[client] = GetEngineTime();
	
	TeleportEntity( client, g_vecClientSavePos[client], g_vecClientSaveAng[client], g_vecClientSaveVel[client] );

	return Plugin_Handled;
}

////////////////////
// ADMIN COMMANDS //
////////////////////
public Action Command_Admin_ZoneEnd( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( g_iBuilderIndex != client )
	{
		PrintColorChat( client, client, "%s Somebody else is building the zone!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( g_iBuilderZone < 0 )
	{
		PrintColorChat( client, client, "%s You haven't even started a zone! (!startzone start/end)", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	static float vecClientPos[3];
	GetClientAbsOrigin( client, vecClientPos );
	
	g_vecBoundsMax[g_iBuilderZone][0] = vecClientPos[0] - ( RoundFloat( vecClientPos[0] ) % g_iBuilderGridSize );
	g_vecBoundsMax[g_iBuilderZone][1] = vecClientPos[1] - ( RoundFloat( vecClientPos[1] ) % g_iBuilderGridSize );
	
	
	float flDif = g_vecBoundsMin[g_iBuilderZone][2] - g_vecBoundsMax[g_iBuilderZone][2];
	
	// If player built the mins on the ground and just walks to the other side, we will then automatically make it 72 units high.
	g_vecBoundsMax[g_iBuilderZone][2] = ( flDif <= 2.0 && flDif >= -2.0 ) ? ( vecClientPos[2] + 72.0 ) : float( RoundFloat( vecClientPos[2] ) );
	
	
	
	// This was used for precise min bounds that would always be on the ground, so our origin cannot be under the mins.
	// E.g Player is standing on ground but our mins are higher than player's origin meaning that the player is outside of the bounds.
	// It is unneccesary now because our bounds are rounded. The player will always be 0.1 - 2.0 units higher.
	
	/*
	static const float angDown[] = { 90.0, 0.0, 0.0 };
	
	TR_TraceRay( g_vecBoundsMin[g_iBuilderZone], angDown, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite );
	
	if ( TR_DidHit( null ) )
		if ( TR_GetEntityIndex( null ) != client )
			TR_GetEndPosition( g_vecBoundsMin[g_iBuilderZone], null );
	*/
	
	if ( SaveMapCoords( g_iBuilderZone ) ) PrintColorChat( client, client, "%s Saved the zone!", CHAT_PREFIX );
	else PrintColorChat( client, client, "%s Couldn't save the zone!", CHAT_PREFIX );
	
	if ( ( g_iBuilderZone == BOUNDS_START || g_iBuilderZone == BOUNDS_END ) && ( g_bZoneExists[BOUNDS_START] && g_bZoneExists[BOUNDS_END] ) )
	{
		DoMapStuff();
		
		g_bIsLoaded[RUN_MAIN] = true;
		PrintColorChatAll( client, false, "%s Main zones are back!", CHAT_PREFIX );
	}
	
	if ( ( g_iBuilderZone == BOUNDS_BONUS_1_START || g_iBuilderZone == BOUNDS_BONUS_1_END ) && ( g_bZoneExists[BOUNDS_BONUS_1_START] && g_bZoneExists[BOUNDS_BONUS_1_END] ) )
	{
		DoMapStuff();
		
		g_bIsLoaded[RUN_BONUS_1] = true;
		PrintColorChatAll( client, false, "%s \x03%s%s is now back!", CHAT_PREFIX, g_szRunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
	}
	
	if ( ( g_iBuilderZone == BOUNDS_BONUS_2_START || g_iBuilderZone == BOUNDS_BONUS_2_END ) && ( g_bZoneExists[BOUNDS_BONUS_2_START] && g_bZoneExists[BOUNDS_BONUS_2_END] ) )
	{
		DoMapStuff();
		
		g_bIsLoaded[RUN_BONUS_2] = true;
		PrintColorChatAll( client, false, "%s \x03%s%s is now back!", CHAT_PREFIX, g_szRunName[NAME_LONG][RUN_BONUS_2], COLOR_TEXT );
	}
	
	g_iBuilderIndex = 0;
	g_iBuilderZone = -1;
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( args < 1 )
	{
		if ( !g_bIsLoaded[RUN_BONUS_1] )
		{
			PrintColorChat( client, client, "%s This map doesn't have \x03%s%s", CHAT_PREFIX, g_szRunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
			return Plugin_Handled;
		}
	
		g_iClientRun[client] = RUN_BONUS_1;
	
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		UpdateScoreboard( client );
		
		PrintColorChat( client, client, "%s You are now in \x03%s%s! Use \x03!main%s to go back.", CHAT_PREFIX, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	char szArg[2];
	GetCmdArgString( szArg, sizeof( szArg ) );
	
	if ( szArg[0] == '1' )
	{
		if ( !g_bIsLoaded[RUN_BONUS_1] )
		{
			PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, g_szRunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
			return Plugin_Handled;
		}
		
		g_iClientRun[client] = RUN_BONUS_1;
	
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		UpdateScoreboard( client );
		
		PrintColorChat( client, client, "%s You are now in \x03%s%s! Use \x03!main%s to go back.", CHAT_PREFIX, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT, COLOR_TEXT );
	}
	else if ( szArg[0] == '2' )
	{
		if ( !g_bIsLoaded[RUN_BONUS_2] )
		{
			PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, g_szRunName[NAME_LONG][ RUN_BONUS_2 ], COLOR_TEXT );
			return Plugin_Handled;
		}
		
		g_iClientRun[client] = RUN_BONUS_2;
	
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		UpdateScoreboard( client );
		
		PrintColorChat( client, client, "%s You are now in \x03%s%s! Use \x03!main%s to go back.", CHAT_PREFIX, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT, COLOR_TEXT );
	}
	
	return Plugin_Handled;
}

public Action Command_Run_Main( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, g_szRunName[NAME_LONG][RUN_MAIN], COLOR_TEXT );
		return Plugin_Handled;
	}
	
	g_iClientRun[client] = RUN_MAIN;
	
	TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
	UpdateScoreboard( client );
	
	PrintColorChat( client, client, "%s You are now in \x03%s%s!", CHAT_PREFIX, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT );
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus_1( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_BONUS_1] )
	{
		PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, g_szRunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
		return Plugin_Handled;
	}
	
	g_iClientRun[client] = RUN_BONUS_1;
	
	TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
	UpdateScoreboard( client );
	
	PrintColorChat( client, client, "%s You are now in \x03%s%s!", CHAT_PREFIX, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT );
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus_2( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_BONUS_2] )
	{
		PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, g_szRunName[NAME_LONG][RUN_BONUS_2], COLOR_TEXT );
		return Plugin_Handled;
	}
	
	g_iClientRun[client] = RUN_BONUS_2;
	
	TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
	UpdateScoreboard( client );
	
	PrintColorChat( client, client, "%s You are now in \x03%s%s!", CHAT_PREFIX, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT );
	
	return Plugin_Handled;
}