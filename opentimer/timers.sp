// Every 3600 seconds we check if there are any players around. If not, we restart the map for performance reasons.
public Action Timer_RestartMap( Handle hTimer )
{
	for ( int i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) && !IsFakeClient( i ) ) return Plugin_Continue;
	
	PrintToServer( "%s Restarting map for performance!", CONSOLE_PREFIX );
	
	ServerCommand( "changelevel %s", g_szCurrentMap );
	
	return Plugin_Handled;
}

public Action Timer_Connected( Handle hTimer, any client )
{
	if ( ( client = GetClientOfUserId( client ) ) < 1 || !IsClientInGame( client ) ) return Plugin_Handled;
	
	if ( g_ConVar_AirAccelerate != null )
	{
		char szTxt[14];
		
		if ( g_bAutoHop )
		{
			Format( szTxt, sizeof( szTxt ), ", AutoHop" );
		}
		
		if ( g_bEZHop )
		{
			Format( szTxt, sizeof( szTxt ), "%s, EZHop", szTxt );
		}
		
		// ", Auto, EZHop" - [14]
		PrintColorChat( client, client, "%sServer settings: %.0ftick, %iaa%s.", COLOR_TEAL, 1 / GetTickInterval(), GetConVarInt( g_ConVar_AirAccelerate ), szTxt );
	}
	
	PrintColorChat( client, client, "%s Type \x03!commands%s for more info.", CHAT_PREFIX, COLOR_TEXT );
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PrintColorChat( client, client, "%s No records are available for this map!", CHAT_PREFIX );
	}
	
	return Plugin_Handled;
}

// Main component of the HUD timer.
public Action Timer_ShowClientInfo( Handle hTimer, any client )
{
	if ( !IsClientInGame( client ) ) return Plugin_Stop;
	
	
	int target = client;
	
	
	// Dead? Find the player we're spectating.
	if ( !IsPlayerAlive( client ) )
	{
		target = GetEntPropEnt( client, Prop_Data, "m_hObserverTarget" );
		
		// Invalid spec target?
		// -1 = No spec target.
		if ( target < 1 || target > MaxClients || !IsPlayerAlive( target ) )
			return Plugin_Continue;
	}
	
	
	
	if ( !( g_iClientHideFlags[client] & HIDEHUD_SIDEINFO ) )
	{
		// Show side info if not a bot.
		
		if ( !IsFakeClient( target ) ) ShowKeyHintText( client, target );
		
	}
	
	
	if ( !( g_iClientHideFlags[client] & HIDEHUD_TIMER ) )
	{
		if ( IsFakeClient( target ) )
		{
			// Replay bot
			
			
			PrintHintText( client, "Replay Bot\n[%s|%s]\n \nSpeed\n%.0f",
				g_szRunName[NAME_LONG][ g_iClientRun[target] ],
				g_szStyleName[NAME_LONG][ g_iClientStyle[target] ],
				/*g_iClientTick[target] / float( g_iMimicTickMax[ g_iClientRun[target] ][ g_iClientStyle[target] ] ) * 100.0*/
				GetClientVelocity( target ) );
				
			return Plugin_Continue;
		}
		
		if ( !g_bIsLoaded[ g_iClientRun[client] ] )
		{
			// No zones were found.
			PrintHintText( client, "Speed\n%.0f", GetClientVelocity( target ) );
			return Plugin_Continue;
		}
		
		if ( g_iClientState[target] == STATE_START )
		{
			// We are in the start zone.
			PrintHintText( client, "Starting Zone\n \nSpeed\n%.0f", GetClientVelocity( target ) );
			return Plugin_Continue;
		}
		
		static float flSeconds;
		static float flBestSeconds;
		
		if ( g_iClientState[target] == STATE_END ) 
		{
			// Show our finish time if we're at the ending
			flSeconds = g_flClientFinishTime[target];
		}
		else
		{
			// Else, we show our current time.
			flSeconds = GetEngineTime() - g_flClientStartTime[target];
		}
		
		
		static char		szMyTime[11];
		FormatSeconds( flSeconds, szMyTime, sizeof( szMyTime ), false );
		
		// We don't have a map best time! We don't need to show anything else.
		if ( g_flMapBestTime[ g_iClientRun[target] ][ g_iClientStyle[target] ] <= TIME_INVALID )
		{
			PrintHintText( client, "%s\n \nSpeed\n%.0f",
				szMyTime,
				GetClientVelocity( target ) );
			
			return Plugin_Continue;
		}
		
		
		int prefix = '-';
		
		if ( g_flMapBestTime[ g_iClientRun[target] ][ g_iClientStyle[target] ] > flSeconds )
		{
			// We currently have "better" time than the map's best time.
			flBestSeconds = g_flMapBestTime[ g_iClientRun[target] ][ g_iClientStyle[target] ] - flSeconds;
		}
		else
		{
			// Else, we have worse, so let's show the difference.
			flBestSeconds = flSeconds - g_flMapBestTime[ g_iClientRun[target] ][ g_iClientStyle[target] ];
			prefix = '+';
		}
		
		static char szBestTime[11];
		FormatSeconds( flBestSeconds, szBestTime, sizeof( szBestTime ), false );
		
		// WARNING: Each line has to have something (e.g space), or it will break.
		// "00:00:00.0C(+00:00:00.0)C CSpeedC1000" - [37]
		PrintHintText( client, "%s\n(%c%s)\n \nSpeed\n%.0f",
			szMyTime,
			prefix,
			szBestTime,
			GetClientVelocity( target ) );
	}
	
	return Plugin_Continue;
}

public Action Timer_DoMapStuff( Handle hTimer )
{
	// Spawn the block zones.
	// Instead of looping through block zones in the main think function, we let the engine handle it.
	CreateBlockZoneEntity( BOUNDS_BLOCK_1 );
	CreateBlockZoneEntity( BOUNDS_BLOCK_2 );
	CreateBlockZoneEntity( BOUNDS_BLOCK_3 );
	
#if defined DELETE_ENTS
	int ent = -1;

	while ( ( ent = FindEntityByClassname( ent, "func_tracktrain" ) ) != -1 )
		AcceptEntityInput( ent, "kill" );
		
	while ( ( ent = FindEntityByClassname( ent, "func_movelinear" ) ) != -1 )
		AcceptEntityInput( ent, "kill" );
	
	while ( ( ent = FindEntityByClassname( ent, "func_door" ) ) != -1 )
		AcceptEntityInput( ent, "kill" );
		
	while ( ( ent = FindEntityByClassname( ent, "logic_timer" ) ) != -1 )
		AcceptEntityInput( ent, "kill" );
		
	while ( ( ent = FindEntityByClassname( ent, "logic_relay" ) ) != -1 )
		AcceptEntityInput( ent, "kill" );
		
	while ( ( ent = FindEntityByClassname( ent, "func_brush" ) ) != -1 )
		AcceptEntityInput( ent, "enable" );
#endif
}

static const int BeamColor[MAX_BOUNDS][4] = {
	{ 0, 255, 0, 255 },
	{ 255, 0, 0, 255 },
	{ 255, 0, 255, 255 },
	{ 255, 0, 0, 255 },
	{ 255, 0, 255, 255 },
	{ 255, 0, 0, 255 },
	{ 255, 128, 0, 255 },
	{ 255, 128, 0, 255 },
	{ 255, 128, 0, 255 },
	{ 0, 255, 255, 255 },
	{ 0, 255, 255, 255 },
	{ 0, 255, 255, 255 }
};

public Action Timer_DrawZoneBeams( Handle hTimer )
{
	static float	flPoint4Min[3], flPoint4Max[3];
	static float	flPoint3Min[3];
	static float	flPoint2Min[3], flPoint2Max[3];
	static float	flPoint1Max[3];
	
	for ( int i; i < MAX_BOUNDS; i++ )
	{
		if ( !g_bZoneExists[i] ) continue;
		
		flPoint4Min[0] = g_vecBoundsMin[i][0]; flPoint4Min[1] = g_vecBoundsMax[i][1]; flPoint4Min[2] = g_vecBoundsMin[i][2] + BOUNDS_WIDTH;
		flPoint4Max[0] = g_vecBoundsMin[i][0]; flPoint4Max[1] = g_vecBoundsMax[i][1]; flPoint4Max[2] = g_vecBoundsMax[i][2] - BOUNDS_WIDTH;
		
		flPoint3Min[0] = g_vecBoundsMax[i][0]; flPoint3Min[1] = g_vecBoundsMax[i][1]; flPoint3Min[2] = g_vecBoundsMin[i][2] + BOUNDS_WIDTH;
		
		flPoint2Min[0] = g_vecBoundsMax[i][0]; flPoint2Min[1] = g_vecBoundsMin[i][1]; flPoint2Min[2] = g_vecBoundsMin[i][2] + BOUNDS_WIDTH;
		flPoint2Max[0] = g_vecBoundsMax[i][0]; flPoint2Max[1] = g_vecBoundsMin[i][1]; flPoint2Max[2] = g_vecBoundsMax[i][2] - BOUNDS_WIDTH;
		
		flPoint1Max[0] = g_vecBoundsMin[i][0]; flPoint1Max[1] = g_vecBoundsMin[i][1]; flPoint1Max[2] = g_vecBoundsMax[i][2] - BOUNDS_WIDTH;
		
		
		TE_SetupBeamPoints( g_vecBoundsMin[i], flPoint1Max, g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecBoundsMin[i], flPoint4Min, g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecBoundsMin[i], flPoint2Min, g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint3Min, g_vecBoundsMax[i], g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint3Min, flPoint4Min, g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint3Min, flPoint2Min, g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint2Max, flPoint2Min, g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint2Max, flPoint1Max, g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint2Max, g_vecBoundsMax[i], g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint4Max, flPoint4Min, g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint4Max, flPoint1Max, g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint4Max, g_vecBoundsMax[i], g_iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
	}
	
	return Plugin_Continue;
}

public Action Timer_DrawBuildZoneBeams( Handle hTimer, any client )
{
	if ( g_iBuilderZone == INVALID_ZONE_INDEX || g_iBuilderIndex == INVALID_INDEX || !IsClientInGame( client ) || !IsPlayerAlive( client ) )
	{
		g_iBuilderIndex = INVALID_INDEX;
		g_iBuilderZone = INVALID_ZONE_INDEX;
		
		return Plugin_Stop;
	}
	
	static float vecClientPos[3];
	GetClientAbsOrigin( client, vecClientPos );
	
	vecClientPos[0] = vecClientPos[0] - ( RoundFloat( vecClientPos[0] ) % g_iBuilderGridSize );
	vecClientPos[1] = vecClientPos[1] - ( RoundFloat( vecClientPos[1] ) % g_iBuilderGridSize );
	
	float flDif = vecClientPos[2] - g_vecBoundsMin[g_iBuilderZone][2];
	
	if ( flDif <= 4.0 && flDif >= -4.0 )
		vecClientPos[2] += BOUNDS_DEF_HEIGHT;
	
	static float flPoint4Min[3], flPoint4Max[3], flPoint3Min[3], flPoint2Min[3], flPoint2Max[3], flPoint1Max[3];
	
	flPoint4Min[0] = g_vecBoundsMin[g_iBuilderZone][0]; flPoint4Min[1] = vecClientPos[1]; flPoint4Min[2] = g_vecBoundsMin[g_iBuilderZone][2];
	flPoint4Max[0] = g_vecBoundsMin[g_iBuilderZone][0]; flPoint4Max[1] = vecClientPos[1]; flPoint4Max[2] = vecClientPos[2];
	
	flPoint3Min[0] = vecClientPos[0]; flPoint3Min[1] = vecClientPos[1]; flPoint3Min[2] = g_vecBoundsMin[g_iBuilderZone][2];
	
	flPoint2Min[0] = vecClientPos[0]; flPoint2Min[1] = g_vecBoundsMin[g_iBuilderZone][1]; flPoint2Min[2] = g_vecBoundsMin[g_iBuilderZone][2];
	flPoint2Max[0] = vecClientPos[0]; flPoint2Max[1] = g_vecBoundsMin[g_iBuilderZone][1]; flPoint2Max[2] = vecClientPos[2];
	
	flPoint1Max[0] = g_vecBoundsMin[g_iBuilderZone][0]; flPoint1Max[1] = g_vecBoundsMin[g_iBuilderZone][1]; flPoint1Max[2] = vecClientPos[2];
	
	TE_SetupBeamPoints( g_vecBoundsMin[g_iBuilderZone], flPoint1Max, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( g_vecBoundsMin[g_iBuilderZone], flPoint4Min, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( g_vecBoundsMin[g_iBuilderZone], flPoint2Min, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint3Min, vecClientPos, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint3Min, flPoint4Min, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint3Min, flPoint2Min, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint2Max, flPoint2Min, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint2Max, flPoint1Max, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint2Max, vecClientPos, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint4Max, flPoint4Min, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint4Max, flPoint1Max, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint4Max, vecClientPos, g_iBeam, 0, 0, 0, BOUNDS_BUILD_INTERVAL, BOUNDS_WIDTH, BOUNDS_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	return Plugin_Continue;
}
///////////////
// RECORDING //
///////////////
#if defined RECORD
public Action Timer_Rec_Start( Handle hTimer, any mimic )
{
	if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) || g_hMimicRecording[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ] == null )
		return Plugin_Handled;
	
	g_iClientTick[mimic] = 0;
	g_bIsClientMimicing[mimic] = true;
	
	return Plugin_Handled;
}

// WAIT TIME BETWEEN RECORDS
public Action Timer_Rec_Restart( Handle hTimer, any mimic )
{
	if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) || g_hMimicRecording[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ] == null )
		return Plugin_Handled;
	
	g_iClientTick[mimic] = TICK_PRE_PLAYBLACK;
	TeleportEntity( mimic, g_vecInitMimicPos[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ], g_angInitMimicAngles[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ], g_vecNull );
	SetEntProp( mimic, Prop_Data, "m_nButtons", 0 );
	
	CreateTimer( 2.0, Timer_Rec_Start, mimic, TIMER_FLAG_NO_MAPCHANGE );
	
	return Plugin_Handled;
}

/*public Action Timer_Rec_Stop( Handle hTimer, any mimic )
{
	if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) )
		return Plugin_Handled;
	
	delete g_hMimicRecording[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ];
	AcceptEntityInput( mimic, "Kill" );
	
	return Plugin_Handled;
}*/
#endif

#if defined VOTING
public Action Timer_ChangeMap( Handle hTimer )
{
	ServerCommand( "changelevel %s", g_szNextMap );
	return Plugin_Handled;
}
#endif