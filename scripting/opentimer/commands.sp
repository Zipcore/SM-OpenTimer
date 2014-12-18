public Action:Command_Help( client, args )
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

/*public Action:Command_AutoHop( client, args )
{
	if ( GetConVarBool( ConVar_AutoHop ) )
	{
		bClientAutoHop[client] = !bClientAutoHop[client];
		
		if ( bClientAutoHop[client] )
			PrintColorChat( client, client, "%s Autobhop is enabled!", CHAT_PREFIX );
		else
			PrintColorChat( client, client, "%s Autobhop is disabled!", CHAT_PREFIX );
	}
	else PrintColorChat( client, client, "%s Access denied.", CHAT_PREFIX );
}*/

public Action:Command_Spawn( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( GetClientTeam( client ) == CS_TEAM_SPECTATOR )
		ChangeClientTeam( client, iPreferedTeam );
	else if ( !IsPlayerAlive( client ) || !bIsLoaded[ iClientRun[client] ] )
		CS_RespawnPlayer( client );
	else
		TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
	
	return Plugin_Handled;
}

public Action:Command_Spectate( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( args == 0 ) ChangeClientTeam( client, CS_TEAM_SPECTATOR );
	else
	{
		decl String:Target[MAX_NAME_LENGTH];
		if ( GetCmdArgString( Target, sizeof( Target ) ) < 1 )
		{
			ChangeClientTeam( client, CS_TEAM_SPECTATOR );
			
			PrintColorChat( client, client, "%s Couldn't find the player you were looking for.", CHAT_PREFIX );
			
			return Plugin_Handled;
		}
		
		new target = FindTarget( client, Target, false, false );
		
		if ( target < 1 || !IsClientInGame( target ) || !IsPlayerAlive( client ) )
			return Plugin_Handled;
		
		ChangeClientTeam( client, CS_TEAM_SPECTATOR );
		
		SetEntPropEnt( client, Prop_Send, "m_hObserverTarget", target );
		SetEntProp( client, Prop_Send, "m_iObserverMode", 2 );
	}

	return Plugin_Handled;
}

public Action:Command_FieldOfView( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( args == 1 )
	{
		decl String:Number[4];
		GetCmdArgString( Number, sizeof( Number ) );
		
		new fov = StringToInt( Number );
		
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
		iClientFOV[client] = fov;
		
		if ( !SaveClientInfo( client ) )
			PrintColorChat( client, client, "%s Couldn't save your option to database!", CHAT_PREFIX );
	}
	else
		PrintColorChat( client, client, "%s Usage: sm_fov <number> (value between 70 and 150)", CHAT_PREFIX );
	
	return Plugin_Handled;
}

public Action:Command_RecordsMOTD( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have map bounds! No records can be found.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	PrintRecords( client, false );
	
	return Plugin_Handled;
}

public Action:Command_RecordsPrint( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have map bounds! No records can be found.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( args < 1 )
		PrintRecords( client, true );
	else
	{
		decl String:Text[12];
		GetCmdArgString( Text, sizeof( Text ) );
		
		StripQuotes( Text );
		
		if ( StrEqual( Text, "b", false ) || StrEqual( Text, "b1", false ) || StrEqual( Text, "bonus1", false ) )
		{
			if ( !bZoneExists[RUN_BONUS_1] )
			{
				PrintColorChat( client, client, "%s \x03%s%s records do not exist!", CHAT_PREFIX, RunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
				return Plugin_Handled;
			}
			
			PrintRecords( client, true, STYLE_NORMAL, RUN_BONUS_1 );
		}
		else if ( StrEqual( Text, "b2", false ) || StrEqual( Text, "bonus2", false ) )
		{
			if ( !bZoneExists[RUN_BONUS_2] )
			{
				PrintColorChat( client, client, "%s \x03%s%s records do not exist!", CHAT_PREFIX, RunName[NAME_LONG][RUN_BONUS_2], COLOR_TEXT );
				return Plugin_Handled;
			}
			
			PrintRecords( client, true, STYLE_NORMAL, RUN_BONUS_2 );
		}
		else if ( StrEqual( Text, "normal", false ) || StrEqual( Text, "n", false ) )
			PrintRecords( client, true, STYLE_NORMAL );
		else if ( StrEqual( Text, "sideways", false ) || StrEqual( Text, "sw", false ) )
			PrintRecords( client, true, STYLE_SIDEWAYS );
		else if ( StrEqual( Text, "w-only", false ) || StrEqual( Text, "w", false ) )
			PrintRecords( client, true, STYLE_W );
	}
	
	return Plugin_Handled;
}

public Action:Command_Style_Normal( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[ iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
		iClientStyle[client] = STYLE_NORMAL;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, StyleName[NAME_LONG][STYLE_NORMAL], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );
		
	return Plugin_Handled;
}

public Action:Command_Style_Sideways( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[ iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
		iClientStyle[client] = STYLE_SIDEWAYS;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, StyleName[NAME_LONG][STYLE_SIDEWAYS], COLOR_TEXT );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );
		
	return Plugin_Handled;
}

public Action:Command_Style_W( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[ iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
		iClientStyle[client] = STYLE_W;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, StyleName[NAME_LONG][STYLE_W], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );

	return Plugin_Handled;
}

public Action:Command_Style_RealHSW( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[ iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
		iClientStyle[client] = STYLE_REAL_HSW;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, StyleName[NAME_LONG][STYLE_REAL_HSW], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );

	return Plugin_Handled;
}

public Action:Command_Style_HSW( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[ iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
		iClientStyle[client] = STYLE_HSW;
		
		PrintColorChat( client, client, "%s Your style is now \x05%s%s!", CHAT_PREFIX, StyleName[NAME_LONG][STYLE_HSW], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );

	return Plugin_Handled;
}

public Action:Command_Practise( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You have to be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( !bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have records enabled!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	bIsClientPractising[client] = !bIsClientPractising[client];
	
	if ( bIsClientPractising[client] )
		PrintColorChat( client, client, "%s You're now in \x03practice%s mode! Type \x03!prac%s to toggle.", CHAT_PREFIX, COLOR_TEXT );
	else
		PrintColorChat( client, client, "%s You're now in \x03normal%s running mode!", CHAT_PREFIX, COLOR_TEXT );
	
	iClientState[client] = STATE_START;
	flClientStartTime[client] = 0.0;
	
#if defined RECORD
	bIsClientRecording[client] = false;
#endif
	
	return Plugin_Handled;
}

public Action:Command_Practise_SavePoint( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsClientPractising[client] )
	{
		PrintColorChat( client, client, "%s You have to be in practice mode! (\x03!practise/!practice/!prac%s)", CHAT_PREFIX, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You have to be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	flClientSaveTime[client] = GetEngineTime();
	
	GetClientAbsAngles( client, vecClientSaveAng[client] );
	GetClientAbsOrigin( client, vecClientSavePos[client] );
	GetEntPropVector( client, Prop_Data, "m_vecAbsVelocity", vecClientSaveVel[client] );
	
	PrintColorChat( client, client, "Saved location!" );
	
	return Plugin_Handled;
}

public Action:Command_Practise_GotoPoint( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsClientPractising[client] )
	{
		PrintColorChat( client, client, "%s You have to be in practice mode! (\x03!practise/!practice/!prac%s)", CHAT_PREFIX, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You have to be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( flClientSaveTime[client] == 0.0 )
	{
		PrintColorChat( client, client, "%s You must save a location first! (\x03!save/!saveloc%s)", CHAT_PREFIX, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	flClientStartTime[client] += GetEngineTime() - flClientSaveTime[client];
	flClientSaveTime[client] = GetEngineTime();
	
	TeleportEntity( client, vecClientSavePos[client], vecClientSaveAng[client], vecClientSaveVel[client] );

	return Plugin_Handled;
}

////////////////////
// ADMIN COMMANDS //
////////////////////
public Action:Command_Admin_ZoneEnd( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( iBuilderIndex != client )
	{
		PrintColorChat( client, client, "%s Somebody else is building the zone!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( iBuilderZone < 0 )
	{
		PrintColorChat( client, client, "%s You haven't even started a zone! (!startzone start/end)", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	decl Float:vecClientPos[3];
	GetClientAbsOrigin( client, vecClientPos );
	
	vecBoundsMax[iBuilderZone][0] = vecClientPos[0] - ( RoundFloat( vecClientPos[0] ) % iBuilderGridSize );
	vecBoundsMax[iBuilderZone][1] = vecClientPos[1] - ( RoundFloat( vecClientPos[1] ) % iBuilderGridSize );
	vecBoundsMax[iBuilderZone][2] = float( RoundFloat( vecClientPos[2] ) );
	
	//static const Float:angDown[] = { 90.0, 0.0, 0.0 };
	
	/*TR_TraceRay( vecBoundsMin[iBuilderZone], angDown, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite );
	
	if ( TR_DidHit( INVALID_HANDLE ) )
		if ( TR_GetEntityIndex( INVALID_HANDLE ) != client )
			TR_GetEndPosition( vecBoundsMin[iBuilderZone], INVALID_HANDLE );*/


	if ( SaveMapCoords( iBuilderZone ) ) PrintColorChat( client, client, "%s Saved the zone!", CHAT_PREFIX );
	else PrintColorChat( client, client, "%s Couldn't save the zone!", CHAT_PREFIX );
	
	if ( ( iBuilderZone == BOUNDS_START || iBuilderZone == BOUNDS_END ) && ( bZoneExists[BOUNDS_START] && bZoneExists[BOUNDS_END] ) )
	{
		DoMapStuff();
		
		bIsLoaded[RUN_MAIN] = true;
		PrintColorChatAll( client, false, "%s Main zones are back!", CHAT_PREFIX );
	}
	
	if ( ( iBuilderZone == BOUNDS_BONUS_1_START || iBuilderZone == BOUNDS_BONUS_1_END ) && ( bZoneExists[BOUNDS_BONUS_1_START] && bZoneExists[BOUNDS_BONUS_1_END] ) )
	{
		DoMapStuff();
		
		bIsLoaded[RUN_BONUS_1] = true;
		PrintColorChatAll( client, false, "%s \x03%s%s is now back!", CHAT_PREFIX, RunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
	}
	
	if ( ( iBuilderZone == BOUNDS_BONUS_2_START || iBuilderZone == BOUNDS_BONUS_2_END ) && ( bZoneExists[BOUNDS_BONUS_2_START] && bZoneExists[BOUNDS_BONUS_2_END] ) )
	{
		DoMapStuff();
		
		bIsLoaded[RUN_BONUS_2] = true;
		PrintColorChatAll( client, false, "%s \x03%s%s is now back!", CHAT_PREFIX, RunName[NAME_LONG][RUN_BONUS_2], COLOR_TEXT );
	}
	
	iBuilderIndex = 0;
	iBuilderZone = -1;
	
	return Plugin_Handled;
}

public Action:Command_Run_Bonus( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( args < 1 )
	{
		if ( !bIsLoaded[RUN_BONUS_1] )
		{
			PrintColorChat( client, client, "%s This map doesn't have \x03%s%s", CHAT_PREFIX, RunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
			return Plugin_Handled;
		}
	
		iClientRun[client] = RUN_BONUS_1;
	
		TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
		UpdateScoreboard( client );
		
		PrintColorChat( client, client, "%s You are now in \x03%s%s! Use \x03!main%s to go back.", CHAT_PREFIX, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	decl String:Arg[2];
	GetCmdArgString( Arg, sizeof( Arg ) );
	
	if ( Arg[0] == '1' )
	{
		if ( !bIsLoaded[RUN_BONUS_1] )
		{
			PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, RunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
			return Plugin_Handled;
		}
		
		iClientRun[client] = RUN_BONUS_1;
	
		TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
		UpdateScoreboard( client );
		
		PrintColorChat( client, client, "%s You are now in \x03%s%s! Use \x03!main%s to go back.", CHAT_PREFIX, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT, COLOR_TEXT );
	}
	else if ( Arg[0] == '2' )
	{
		if ( !bIsLoaded[RUN_BONUS_2] )
		{
			PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, RunName[NAME_LONG][ RUN_BONUS_2 ], COLOR_TEXT );
			return Plugin_Handled;
		}
		
		iClientRun[client] = RUN_BONUS_2;
	
		TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
		UpdateScoreboard( client );
		
		PrintColorChat( client, client, "%s You are now in \x03%s%s! Use \x03!main%s to go back.", CHAT_PREFIX, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT, COLOR_TEXT );
	}
	
	return Plugin_Handled;
}

public Action:Command_Run_Main( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, RunName[NAME_LONG][RUN_MAIN], COLOR_TEXT );
		return Plugin_Handled;
	}
	
	iClientRun[client] = RUN_MAIN;
	
	TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
	UpdateScoreboard( client );
	
	PrintColorChat( client, client, "%s You are now in \x03%s%s!", CHAT_PREFIX, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT );
	
	return Plugin_Handled;
}

public Action:Command_Run_Bonus_1( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[RUN_BONUS_1] )
	{
		PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, RunName[NAME_LONG][RUN_BONUS_1], COLOR_TEXT );
		return Plugin_Handled;
	}
	
	iClientRun[client] = RUN_BONUS_1;
	
	TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
	UpdateScoreboard( client );
	
	PrintColorChat( client, client, "%s You are now in \x03%s%s!", CHAT_PREFIX, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT );
	
	return Plugin_Handled;
}

public Action:Command_Run_Bonus_2( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsLoaded[RUN_BONUS_2] )
	{
		PrintColorChat( client, client, "%s This map doesn't have \x03%s%s!", CHAT_PREFIX, RunName[NAME_LONG][RUN_BONUS_2], COLOR_TEXT );
		return Plugin_Handled;
	}
	
	iClientRun[client] = RUN_BONUS_2;
	
	TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
	UpdateScoreboard( client );
	
	PrintColorChat( client, client, "%s You are now in \x03%s%s!", CHAT_PREFIX, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT );
	
	return Plugin_Handled;
}