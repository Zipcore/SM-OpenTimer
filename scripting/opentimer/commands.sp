public Action Command_Version( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	PrintColorChat( client, client, CHAT_PREFIX ... "Running version \x03" ... PLUGIN_VERSION...CLR_TEXT..." made by \x03" ... PLUGIN_AUTHOR...CLR_TEXT..."." );
	
	return Plugin_Handled;
}

public Action Command_Help( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	
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
	PrintToConsole( client, "!version - What version of "...PLUGIN_NAME..." are we running?" );
	
	PrintToConsole( client, ">> RECORDS" );
	PrintToConsole( client, "!wr/!records/!times - Show top 5 times." );
	PrintToConsole( client, "!printrecords <type> - Shows a detailed version of records. (m/b1/b2 n/w/sw/rhsw/hsw/vel) Max. %i times.", RECORDS_PRINT_MAXPLAYERS );
	
	PrintToConsole( client, ">> PRACTICE" );
	PrintToConsole( client, "!practise/!practice/!prac/!p - Toggle practice mode." );
	PrintToConsole( client, "!saveloc/!save - Save a checkpoint for practice mode." );
	PrintToConsole( client, "!gotocp/!cp <num> - Checkpoint menu or specific one." );
	PrintToConsole( client, "!lastcp/!last - Teleport to latest checkpoint." );
	PrintToConsole( client, "!no-clip/!fly - Typical noclip." );
	
	PrintToConsole( client, ">> RUNS/MODES/STYLES" );
	PrintToConsole( client, "!style/!normal/!sideways/!w/!rhsw/!hsw/!vel - Changes your style accordingly." );
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
	
	PrintColorChat( client, client, CHAT_PREFIX ... "Printed all used commands to your console!" );
	
	return Plugin_Handled;
}

public Action Command_Doublestep( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	
	ShowMOTDPanel( client, "Doublestep Info", "For players that use client-side autobhop and suffer from doublestepping:\n\nBind your hold key to \'+ds\' to disable doublestepping completely.", MOTDPANEL_TYPE_TEXT );
	
	return Plugin_Handled;
}

public Action Command_Spawn( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	
	if ( GetClientTeam( client ) == CS_TEAM_SPECTATOR )
	{
		ChangeClientTeam( client, g_iPreferredTeam );
	}
	else if ( !IsPlayerAlive( client ) || !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		CS_RespawnPlayer( client );
	}
	else
	{
		TeleportPlayerToStart( client );
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
			PrintColorChat( client, client, CHAT_PREFIX ... "Couldn't find the player you were looking for." );
			
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
			PrintColorChat( client, client, CHAT_PREFIX ... "Your desired field of view is too damn high! Max. 150" );	
			return Plugin_Handled;
		}
		else if ( fov < 70 )
		{
			PrintColorChat( client, client, CHAT_PREFIX ... "Your desired field of view is too low! Min. 70" );
			return Plugin_Handled;
		}
		
		
		PrintColorChat( client, client, CHAT_PREFIX ... "Your field of view is now \x03%i"...CLR_TEXT..."!", fov );
	
		SetClientFOV( client, fov );
		g_iClientFOV[client] = fov;
		
		
		if ( !DB_SaveClientData( client ) )
			PrintColorChat( client, client, CHAT_PREFIX ... "Couldn't save your option to database!" );
	}
	else
		PrintColorChat( client, client, CHAT_PREFIX ... "Usage: sm_fov <number> (value between 70 and 150)" );
	
	return Plugin_Handled;
}

public Action Command_RecordsMenu( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "This map doesn't have zones! No records can be found." );
		return Plugin_Handled;
	}
	
	
	DB_PrintRecords( client, false );
	
	return Plugin_Handled;
}

public Action Command_RecordsPrint( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "This map doesn't have zones! No records can be found." );
		return Plugin_Handled;
	}
	
	
	if ( args < 1 ) DB_PrintRecords( client, true );
	else
	{
		char szArg[12];
		GetCmdArgString( szArg, sizeof( szArg ) );
		
		StripQuotes( szArg );
		
		
		if ( StrEqual( szArg, "b", false ) || StrEqual( szArg, "b1", false ) || StrEqual( szArg, "bonus1", false ) )
		{
			if ( !g_bZoneExists[RUN_BONUS_1] )
			{
				PrintColorChat( client, client, CHAT_PREFIX ... "\x03%s"...CLR_TEXT..." records do not exist!", g_szRunName[NAME_LONG][RUN_BONUS_1] );
				return Plugin_Handled;
			}
			
			DB_PrintRecords( client, true, STYLE_NORMAL, RUN_BONUS_1 );
		}
		else if ( StrEqual( szArg, "b2", false ) || StrEqual( szArg, "bonus2", false ) )
		{
			if ( !g_bZoneExists[RUN_BONUS_2] )
			{
				PrintColorChat( client, client, CHAT_PREFIX ... "\x03%s"...CLR_TEXT..." records do not exist!", g_szRunName[NAME_LONG][RUN_BONUS_2] );
				return Plugin_Handled;
			}
			
			DB_PrintRecords( client, true, STYLE_NORMAL, RUN_BONUS_2 );
		}
		else if ( StrEqual( szArg, "normal", false ) || StrEqual( szArg, "n", false ) )
		{
			DB_PrintRecords( client, true, STYLE_NORMAL );
		}
		else if ( StrEqual( szArg, "sideways", false ) || StrEqual( szArg, "sw", false ) )
		{
			DB_PrintRecords( client, true, STYLE_SIDEWAYS );
		}
		else if ( StrEqual( szArg, "w-only", false ) || StrEqual( szArg, "w", false ) )
		{
			DB_PrintRecords( client, true, STYLE_W );
		}
		else if ( StrEqual( szArg, "vel", false ) || StrEqual( szArg, "v", false ) || StrEqual( szArg, "400", false ) || StrEqual( szArg, "400vel", false ) || StrEqual( szArg, "400v", false ) )
		{
			DB_PrintRecords( client, true, STYLE_VEL );
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Style_Normal( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Unable to comply." );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportPlayerToStart( client );
		g_iClientStyle[client] = STYLE_NORMAL;
		
		PrintColorChat( client, client, CHAT_PREFIX ... "Your style is now \x03%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][STYLE_NORMAL] );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to change your style!" );
		
	return Plugin_Handled;
}

public Action Command_Style_Sideways( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Unable to comply." );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	if ( !GetConVarBool( g_ConVar_Allow_SW ) )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "That mode is not allowed!" );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportPlayerToStart( client );
		g_iClientStyle[client] = STYLE_SIDEWAYS;
		
		PrintColorChat( client, client, CHAT_PREFIX ... "Your style is now \x03%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][STYLE_SIDEWAYS] );
	}
	else PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to change your style!" );
		
	return Plugin_Handled;
}

public Action Command_Style_W( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Unable to comply." );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	if ( !GetConVarBool( g_ConVar_Allow_W ) )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "That mode is not allowed!" );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportPlayerToStart( client );
		g_iClientStyle[client] = STYLE_W;
		
		PrintColorChat( client, client, CHAT_PREFIX ... "Your style is now \x03%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][STYLE_W] );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to change your style!" );

	return Plugin_Handled;
}

public Action Command_Style_HSW( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Unable to comply." );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	if ( !GetConVarBool( g_ConVar_Allow_HSW ) )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "That mode is not allowed!" );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportPlayerToStart( client );
		g_iClientStyle[client] = STYLE_HSW;
		
		PrintColorChat( client, client, CHAT_PREFIX ... "Your style is now \x03%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][STYLE_HSW] );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to change your style!" );

	return Plugin_Handled;
}

public Action Command_Style_RealHSW( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Unable to comply." );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	if ( !GetConVarBool( g_ConVar_Allow_RHSW ) )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "That mode is not allowed!" );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportPlayerToStart( client );
		g_iClientStyle[client] = STYLE_REAL_HSW;
		
		PrintColorChat( client, client, CHAT_PREFIX ... "Your style is now \x03%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][STYLE_REAL_HSW] );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to change your style!" );

	return Plugin_Handled;
}

public Action Command_Style_VelCap( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Unable to comply." );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	if ( !GetConVarBool( g_ConVar_Allow_Vel ) )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "That mode is not allowed!" );
		return Plugin_Handled;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportPlayerToStart( client );
		g_iClientStyle[client] = STYLE_VEL;
		
		PrintColorChat( client, client, CHAT_PREFIX ... "Your style is now \x03%.0fvel"...CLR_TEXT..."!", g_flVelCap );
		
		UpdateScoreboard( client );
	}
	else PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to change your style!" );

	return Plugin_Handled;
}

public Action Command_Practise( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to use this command!" );
		return Plugin_Handled;
	}
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "This map doesn't have records enabled!" );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	
	g_bIsClientPractising[client] = !g_bIsClientPractising[client];
	
	if ( g_bIsClientPractising[client] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "You're now in \x03practice"...CLR_TEXT..." mode! Type \x03!prac"...CLR_TEXT..." to toggle." );
	}
	else
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "You're now in \x03normal"...CLR_TEXT..." running mode!" );
		
		TeleportPlayerToStart( client );
		
		SetEntityMoveType( client, MOVETYPE_WALK );
	}
	
#if defined RECORD
	g_bClientRecording[client] = false;
	
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
		PrintColorChat( client, client, CHAT_PREFIX ... "You have to be in \x03practice"...CLR_TEXT..." mode! (\x03!prac"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to use this command!" );
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
	
	PrintColorChat( client, client, CHAT_PREFIX ... "Saved location!" );
	
	return Plugin_Handled;
}

public Action Command_Practise_GotoLastPoint( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsClientPractising[client] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "You have to be in \x03practice"...CLR_TEXT..." mode! (\x03!prac"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to use this command!" );
		return Plugin_Handled;
	}
	
	if ( g_iClientCurSave[client] == -1 || g_flClientSaveDif[client][ g_iClientCurSave[client] ] == TIME_INVALID )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "You must save a location first! (\x03!save"...CLR_TEXT...")" );
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
		PrintColorChat( client, client, CHAT_PREFIX ... "You must be alive to use this command!" );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	
	if ( GetEntityMoveType( client ) == MOVETYPE_WALK )
	{	
		if ( !g_bIsClientPractising[client] )
		{
			g_bIsClientPractising[client] = true;
			
			PrintColorChat( client, client, CHAT_PREFIX ... "You're now in \x03practice"...CLR_TEXT..." mode! Type \x03!prac"...CLR_TEXT..." to toggle." );
		}
		
		SetEntityMoveType( client, MOVETYPE_NOCLIP );
	}
	else SetEntityMoveType( client, MOVETYPE_WALK );
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	
	if ( args == 0 )
	{
		if ( !g_bIsLoaded[RUN_BONUS_1] )
		{
			PrintColorChat( client, client, CHAT_PREFIX ... "This map doesn't have \x03%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][RUN_BONUS_1] );
			return Plugin_Handled;
		}
	
		
		g_iClientRun[client] = RUN_BONUS_1;
	
		TeleportPlayerToStart( client );
		UpdateScoreboard( client );
		
		PrintColorChat( client, client, CHAT_PREFIX ... "You are now in \x03%s"...CLR_TEXT..."! Use \x03!main"...CLR_TEXT..." to go back.", g_szRunName[NAME_LONG][ g_iClientRun[client] ] );
		return Plugin_Handled;
	}
	
	char szArg[2];
	GetCmdArgString( szArg, sizeof( szArg ) );
	
	if ( szArg[0] == '1' )
	{
		if ( !g_bIsLoaded[RUN_BONUS_1] )
		{
			PrintColorChat( client, client, CHAT_PREFIX ... "This map doesn't have \x03%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][RUN_BONUS_1] );
			return Plugin_Handled;
		}
		
		
		g_iClientRun[client] = RUN_BONUS_1;
	
		TeleportPlayerToStart( client );
		UpdateScoreboard( client );
		
		PrintColorChat( client, client, CHAT_PREFIX ... "You are now in \x03%s"...CLR_TEXT..."! Use \x03!main"...CLR_TEXT..." to go back.", g_szRunName[NAME_LONG][ g_iClientRun[client] ] );
	}
	else if ( szArg[0] == '2' )
	{
		if ( !g_bIsLoaded[RUN_BONUS_2] )
		{
			PrintColorChat( client, client, CHAT_PREFIX ... "This map doesn't have \x03%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][ RUN_BONUS_2 ] );
			return Plugin_Handled;
		}
		
		
		g_iClientRun[client] = RUN_BONUS_2;
	
		TeleportPlayerToStart( client );
		UpdateScoreboard( client );
		
		PrintColorChat( client, client, CHAT_PREFIX ... "You are now in \x03%s"...CLR_TEXT..."! Use \x03!main"...CLR_TEXT..." to go back.", g_szRunName[NAME_LONG][ g_iClientRun[client] ] );
	}
	
	return Plugin_Handled;
}

public Action Command_Run_Main( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "This map doesn't have \x03%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][RUN_MAIN] );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	
	g_iClientRun[client] = RUN_MAIN;
	
	TeleportPlayerToStart( client );
	UpdateScoreboard( client );
	
	PrintColorChat( client, client, CHAT_PREFIX ... "You are now in \x03%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][ g_iClientRun[client] ] );
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus_1( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_BONUS_1] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "This map doesn't have \x03%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][RUN_BONUS_1] );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	
	g_iClientRun[client] = RUN_BONUS_1;
	
	TeleportPlayerToStart( client );
	UpdateScoreboard( client );
	
	PrintColorChat( client, client, CHAT_PREFIX ... "You are now in \x03%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][ g_iClientRun[client] ] );
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus_2( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_BONUS_2] )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "This map doesn't have \x03%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][RUN_BONUS_2] );
		return Plugin_Handled;
	}
	
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return Plugin_Handled;
	}
	
	
	g_iClientRun[client] = RUN_BONUS_2;
	
	TeleportPlayerToStart( client );
	UpdateScoreboard( client );
	
	PrintColorChat( client, client, CHAT_PREFIX ... "You are now in \x03%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][ g_iClientRun[client] ] );
	
	return Plugin_Handled;
}