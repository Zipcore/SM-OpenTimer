public Action Command_Version( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	PrintColorChat( client, client, "%s Running version \x03%s%s made by \x03%s%s.", CHAT_PREFIX, PLUGIN_VERSION, COLOR_TEXT, PLUGIN_AUTHOR, COLOR_TEXT );
	
	return Plugin_Handled;
}

public Action Command_Help( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, "%s Please don't spam this command, thanks.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	PrintToConsole( client, "--------------------" );
	PrintToConsole( client, ">> Type the given command into the chat." );
	PrintToConsole( client, ">> Prefix \'/\' can be used to suppress the message. sm_<command> can be used in console." );
	
	// This is more messy, but a lot more readible and easier to edit.
	PrintToConsole( client, ">> GENERAL" );
	PrintToConsole( client, "!respawn/!spawn/!restart/!start/!r/!re - Respawn or go back to start if not dead." );
	PrintToConsole( client, "!spectate/!spec/!s <name> - Spectate a specific player or go to spectate mode." );
	PrintToConsole( client, "!fov/!fieldofview <number> - Change your field of view." );
	PrintToConsole( client, "!hud/!showhud/!hidehud/!h - Toggle HUD elements." );
	PrintToConsole( client, "!commands - This ;)" );
	PrintToConsole( client, "!ds - Show info about client-side autobhop doublestepping." );
	PrintToConsole( client, "!version - What version of OpenTimer are we running?" );
	
	PrintToConsole( client, ">> RECORDS" );
	PrintToConsole( client, "!wr/!records/!times - Show top 5 times." );
	PrintToConsole( client, "!printrecords <type> - Shows a detailed version of records. (m/b1/b2 n/w/sw/rhsw/hsw) Max. %i times.", RECORDS_PRINT_MAXPLAYERS );
	
	PrintToConsole( client, ">> PRACTICE" );
	PrintToConsole( client, "!practise/!practice/!prac/!p - Toggle practice mode." );
	PrintToConsole( client, "!saveloc/!save - Save a checkpoint for practice mode." );
	PrintToConsole( client, "!gotocp/!cp <num> - Checkpoint menu or specific one." );
	PrintToConsole( client, "!lastcp/!last - Teleport to latest checkpoint." );
	PrintToConsole( client, "!no-clip/!fly - Typical noclip." );
	
	PrintToConsole( client, ">> RUNS/MODES/STYLES" );
	PrintToConsole( client, "!style/!normal/!sideways/!w/!rhsw/!hsw - Changes your style accordingly." );
	PrintToConsole( client, "!main - Go back to main run." );
	PrintToConsole( client, "!b 1/2 - Go to bonus 1/2 runs." );
	
#if defined VOTING
	PrintToConsole( client, ">> VOTING" );
	PrintToConsole( client, "!choosemap - Vote for a map!" );
#endif

	PrintToConsole( client, ">> ADMIN" );
	PrintToConsole( client, "!zone/!zones/!zonemenu - Zone menu." );
	PrintToConsole( client, "!startzone - Start a zone." );
	PrintToConsole( client, "!endzone - End the zone you were building." );
	PrintToConsole( client, "!deletezone - Delete a specific zone." );
	PrintToConsole( client, "--------------------" );
	
	PrintColorChat( client, client, "%s Printed all used commands to your console!", CHAT_PREFIX );
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	return Plugin_Handled;
}

public Action Command_Doublestep( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, "%s Please don't spam this command, thanks.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	ShowMOTDPanel( client, "Doublestep Info", "For players that use client-side autobhop and suffer from doublestepping:\n\nBind your hold key to \'+ds\' to disable doublestepping completely.", MOTDPANEL_TYPE_TEXT );
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	return Plugin_Handled;
}

public Action Command_Spawn( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	
	if ( GetClientTeam( client ) == CS_TEAM_SPECTATOR )
	{
		ChangeClientTeam( client, g_iPreferedTeam );
	}
	else if ( !IsPlayerAlive( client ) || !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		CS_RespawnPlayer( client );
	}
	else
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
	}
	
	return Plugin_Handled;
}

public Action Command_Spectate( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	
	if ( args == 0 ) ChangeClientTeam( client, CS_TEAM_SPECTATOR );
	else
	{
		char szTarget[MAX_NAME_LENGTH];
		
		if ( GetCmdArgString( szTarget, sizeof( szTarget ) ) < 1 )
			return Plugin_Handled;
		
		
		int target = FindTarget( client, szTarget, false, false );
		
		if ( target < 1 || target > MaxClients || !IsClientInGame( target ) || !IsPlayerAlive( client ) )
		{
			ChangeClientTeam( client, CS_TEAM_SPECTATOR );
			PrintColorChat( client, client, "%s Couldn't find the player you were looking for.", CHAT_PREFIX );
			
			return Plugin_Handled;
		}
		
		
		ChangeClientTeam( client, CS_TEAM_SPECTATOR );
		
		SetEntPropEnt( client, Prop_Send, "m_hObserverTarget", target );
		SetEntProp( client, Prop_Send, "m_iObserverMode", 2 );
	}

	return Plugin_Handled;
}

public Action Command_FieldOfView( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	
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
		
		
		PrintColorChat( client, client, "%s Your field of view is now \x03%i%s!", CHAT_PREFIX, fov, COLOR_TEXT );
	
		SetClientFOV( client, fov );
		g_iClientFOV[client] = fov;
		
		
		if ( !SaveClientData( client ) )
			PrintColorChat( client, client, "%s Couldn't save your option to database!", CHAT_PREFIX );
	}
	else
		PrintColorChat( client, client, "%s Usage: sm_fov <number> (value between 70 and 150)", CHAT_PREFIX );
	
	return Plugin_Handled;
}

public Action Command_RecordsMOTD( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, "%s Please don't spam this command, thanks.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have zones! No records can be found.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	PrintRecords( client, false );
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	return Plugin_Handled;
}

public Action Command_RecordsPrint( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have zones! No records can be found.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	if ( args < 1 ) PrintRecords( client, true );
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
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_NORMAL;
		
		PrintColorChat( client, client, "%s Your style is now \x03%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_NORMAL], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );
		
	return Plugin_Handled;
}

public Action Command_Style_Sideways( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_SIDEWAYS;
		
		PrintColorChat( client, client, "%s Your style is now \x03%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_SIDEWAYS], COLOR_TEXT );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );
		
	return Plugin_Handled;
}

public Action Command_Style_W( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_W;
		
		PrintColorChat( client, client, "%s Your style is now \x03%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_W], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );

	return Plugin_Handled;
}

public Action Command_Style_RealHSW( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_REAL_HSW;
		
		PrintColorChat( client, client, "%s Your style is now \x03%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_REAL_HSW], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );

	return Plugin_Handled;
}

public Action Command_Style_HSW( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, "%s Unable to comply.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		g_iClientStyle[client] = STYLE_HSW;
		
		PrintColorChat( client, client, "%s Your style is now \x03%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][STYLE_HSW], COLOR_TEXT );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );

	return Plugin_Handled;
}

public Action Command_Practise( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You must be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s This map doesn't have records enabled!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	g_bIsClientPractising[client] = !g_bIsClientPractising[client];
	
	if ( g_bIsClientPractising[client] )
	{
		PrintColorChat( client, client, "%s You're now in \x03practice%s mode! Type \x03!prac%s to toggle.", CHAT_PREFIX, COLOR_TEXT, COLOR_TEXT );
	}
	else
	{
		PrintColorChat( client, client, "%s You're now in \x03normal%s running mode!", CHAT_PREFIX, COLOR_TEXT );
		
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
		
		g_iClientState[client] = STATE_START;
		g_flClientStartTime[client] = TIME_INVALID;
	}
	
#if defined RECORD
	g_bIsClientRecording[client] = false;
	
	if ( g_hClientRecording[client] != null )
	{
		delete g_hClientRecording[client];
		g_hClientRecording[client] = null;
	}
#endif
	
	return Plugin_Handled;
}

public Action Command_Practise_SavePoint( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsClientPractising[client] )
	{
		PrintColorChat( client, client, "%s You have to be in \x03practice%s mode! (\x03!prac%s)", CHAT_PREFIX, COLOR_TEXT, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You must be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	g_iClientCurSave[client]++;
	
	if ( g_iClientCurSave[client] >= PRAC_MAX_SAVES )
	{
		g_iClientCurSave[client] = 0;
	}
	
	// Save the difference instead of the the engine time. If you don't do that, multiple cps won't work correctly.
	g_flClientSaveDif[client][ g_iClientCurSave[client] ] = GetEngineTime() - g_flClientStartTime[client];
	
	GetClientEyeAngles( client, g_vecClientSaveAng[client][ g_iClientCurSave[client] ] );
	GetClientAbsOrigin( client, g_vecClientSavePos[client][ g_iClientCurSave[client] ] );
	GetEntPropVector( client, Prop_Data, "m_vecAbsVelocity", g_vecClientSaveVel[client][ g_iClientCurSave[client] ] );
	
	PrintColorChat( client, client, "%s Saved the location!", CHAT_PREFIX );
	
	return Plugin_Handled;
}

public Action Command_Practise_GotoLastPoint( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsClientPractising[client] )
	{
		PrintColorChat( client, client, "%s You have to be in \x03practice%s mode! (\x03!prac%s)", CHAT_PREFIX, COLOR_TEXT, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You must be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( g_iClientCurSave[client] == -1 || g_flClientSaveDif[client][ g_iClientCurSave[client] ] == TIME_INVALID )
	{
		PrintColorChat( client, client, "%s You must save a location first! (\x03!save%s)", CHAT_PREFIX, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	
	// A valid save!
	g_flClientStartTime[client] = GetEngineTime() - g_flClientSaveDif[client][ g_iClientCurSave[client] ];
	
	TeleportEntity( client, g_vecClientSavePos[client][ g_iClientCurSave[client] ], g_vecClientSaveAng[client][ g_iClientCurSave[client] ], g_vecClientSaveVel[client][ g_iClientCurSave[client] ] );

	return Plugin_Handled;
}

public Action Command_Practise_Noclip( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You must be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	
	if ( GetEntityMoveType( client ) == MOVETYPE_WALK )
	{	
		if ( !g_bIsClientPractising[client] )
		{
			g_bIsClientPractising[client] = true;
			
			PrintColorChat( client, client, "%s You're now in \x03practice%s mode! Type \x03!prac%s to toggle.", CHAT_PREFIX, COLOR_TEXT, COLOR_TEXT );
		}
		
		SetEntityMoveType( client, MOVETYPE_NOCLIP );
	}
	else SetEntityMoveType( client, MOVETYPE_WALK );
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	
	if ( args == 0 )
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
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
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
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
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
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
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