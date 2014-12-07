public Action:Command_Help( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	PrintToConsole( client, "\n\nCommands:\n!respawn/!spawn/!restart/!start/!r/!re - Respawn\n!normal/!sideways/!w - Changes your mode accordingly.\n!spectate/!spec <name> - Spectate a player. Or, go spectator.\n!fov/!fieldofview <number> - Change your field of view.\n!hud/!showhud/!hidehud - Toggle HUD elements.\n!commands - This ;)\n!wr/!records/!times - Show top 5 times.\n!printrecords <type> - Shows a detailed version. Max. 16 times.\n!practise/!practice/!prac - Use practice mode.\n!saveloc/!save - Save point for practice mode.\n!gotocp/!cp - Teleport into the saved point.\n!choosemap - Vote for a map! (All players required.)\n\n" );
	
	PrintColorChat( client, client, "%s Printed all used commands to your console!\nShort version:\x05 !restart/!respawn, !fov <number>, !hud, !viewmodel, !prac, !spec <name>, !wr, !printrecords <type>, !choosemap", CHAT_PREFIX );
	
	return Plugin_Handled;
}

public Action:Command_AutoHop( client, args )
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
}

public Action:Command_Spawn( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( GetClientTeam( client ) == CS_TEAM_SPECTATOR )
		ChangeClientTeam( client, iPreferedTeam );
	else if ( !IsPlayerAlive( client ) || !bIsLoaded )
		CS_RespawnPlayer( client );
	else
		TeleportEntity( client, vecSpawnPos, angSpawnAngles, vecNull );
	
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
	
	if ( !bIsLoaded )
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
	
	if ( !bIsLoaded )
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
		
		if ( StrEqual( Text, "normal", false ) )
			PrintRecords( client, true, 0 );
		else if ( StrEqual( Text, "sideways", false ) || StrEqual( Text, "sw", false ) )
			PrintRecords( client, true, 1 );
		else if ( StrEqual( Text, "w-only", false ) || StrEqual( Text, "w", false ) )
			PrintRecords( client, true, 2 );
	}
	
	return Plugin_Handled;
}

public Action:Command_Mode_Normal( client, args ) {
	if ( client < 1 ) return Plugin_Handled;
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, vecSpawnPos, angSpawnAngles, vecNull );
		iClientMode[client] = MODE_NORMAL;
		
		PrintColorChat( client, client, "%s Your mode is now \x05%s%s!", CHAT_PREFIX, ModeName[MODENAME_LONG][MODE_NORMAL], COLOR_WHITE );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your mode!", CHAT_PREFIX );
		
	return Plugin_Handled;
}

public Action:Command_Mode_Sideways( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, vecSpawnPos, angSpawnAngles, vecNull );
		iClientMode[client] = MODE_SIDEWAYS;
		
		PrintColorChat( client, client, "%s Your mode is now \x05%s%s!", CHAT_PREFIX, ModeName[MODENAME_LONG][MODE_SIDEWAYS], COLOR_WHITE );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your mode!", CHAT_PREFIX );
		
	return Plugin_Handled;
}

public Action:Command_Mode_W( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( IsPlayerAlive( client ) )
	{
		TeleportEntity( client, vecSpawnPos, angSpawnAngles, vecNull );
		iClientMode[client] = MODE_W;
		
		PrintColorChat( client, client, "%s Your mode is now \x05%s%s!", CHAT_PREFIX, ModeName[MODENAME_LONG][MODE_W], COLOR_WHITE );
	}
	else PrintColorChat( client, client, "%s You must be alive to change your mode!", CHAT_PREFIX );

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
	
	if ( !bIsLoaded )
	{
		PrintColorChat( client, client, "%s This map doesn't have records enabled!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	bIsClientPractising[client] = !bIsClientPractising[client];
	
	if ( bIsClientPractising[client] )
		PrintColorChat( client, client, "%s You're now in practice mode!", CHAT_PREFIX );
	else
		PrintColorChat( client, client, "%s You're now in normal mode!", CHAT_PREFIX );
	
	iClientState[client] = STATE_START;
	flClientStartTime[client] = 0.0;
	bIsClientRecording[client] = false;
	
	TeleportEntity( client, vecSpawnPos, angSpawnAngles, vecNull );
	
	return Plugin_Handled;
}

public Action:Command_Practise_SavePoint( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !bIsClientPractising[client] )
	{
		PrintColorChat( client, client, "%s You have to be in practise mode! (\x05!practise\x03)", CHAT_PREFIX );
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
		PrintColorChat( client, client, "%s You have to be in practice mode! (\x05!practise/practice/prac\x03)", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You have to be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( flClientSaveTime[client] == 0.0 )
	{
		PrintColorChat( client, client, "%s You must save a location first! (\x05!save/!saveloc\x03)", CHAT_PREFIX );
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
public Action:Command_Admin_Block( client, args )
{
	bNoBlock = !bNoBlock;
	
	if ( bNoBlock )
	{
		for ( new target = 1; target <= MaxClients; target++ )
			if ( IsClientInGame( target ) && IsPlayerAlive( target ) )
				SetEntProp( target, Prop_Data, "m_CollisionGroup", 5 );

		PrintToChatAll( "%s Player collisions are on!", CHAT_PREFIX );
	}
	else
	{
		for ( new target = 1; target <= MaxClients; target++ )
			if ( IsClientInGame( target ) && IsPlayerAlive( target ) )
				SetEntProp( target, Prop_Data, "m_CollisionGroup", 2 );

		PrintToChatAll( "%s Player collisions are off!", CHAT_PREFIX );
	}
	
	return Plugin_Handled;
}

new const Float:angDown[] = { 90.0, 0.0, 0.0 };
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
	
	vecMapBoundsMax[iBuilderZone][0] = vecClientPos[0] - ( RoundFloat( vecClientPos[0] ) % iBuilderGridSize );
	vecMapBoundsMax[iBuilderZone][1] = vecClientPos[1] - ( RoundFloat( vecClientPos[1] ) % iBuilderGridSize );
	vecMapBoundsMax[iBuilderZone][2] = float( RoundFloat( vecClientPos[2] ) );
	
	TR_TraceRay( vecMapBoundsMin[iBuilderZone], angDown, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite );
	
	/*if ( TR_DidHit( INVALID_HANDLE ) )
		if ( TR_GetEntityIndex( INVALID_HANDLE ) != client )
			TR_GetEndPosition( vecMapBoundsMin[iBuilderZone], INVALID_HANDLE );*/


	if ( SaveMapCoords( iBuilderZone ) ) PrintColorChat( client, client, "%s Saved the zone!", CHAT_PREFIX );
	else PrintColorChat( client, client, "%s Couldn't save the zone!", CHAT_PREFIX );
	
	iBuilderIndex = 0;
	iBuilderZone = -1;
	
	if ( bZoneExists[BOUNDS_START] && bZoneExists[BOUNDS_END] )
	{
		bIsLoaded = true;
		PrintColorChatAll( client, false, "%s All zones are back and map is ready!", CHAT_PREFIX );
		
		DoMapStuff();
	}
	
	return Plugin_Handled;
}
