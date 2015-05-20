// Every 3600 seconds we check if there are any players around. If not, we restart the map for performance reasons.
public Action Timer_RestartMap( Handle hTimer )
{
	for ( int i = 1; i <= MaxClients; i++ )
		if ( IsClientConnected( i ) && !IsFakeClient( i ) ) return Plugin_Continue;
	
	
	PrintToServer( CONSOLE_PREFIX ... "No players found, restarting map for performance!" );
	
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
			FormatEx( szTxt, sizeof( szTxt ), ", AutoHop" );
		}
		
		if ( g_bEZHop )
		{
			Format( szTxt, sizeof( szTxt ), "%s, EZHop", szTxt );
		}
		
		// ", Auto, EZHop" - [14]
		PRINTCHATV( client, client, CLR_SETTINGS ... "Server settings: %.0ftick, %iaa%s.", 1 / GetTickInterval(), GetConVarInt( g_ConVar_AirAccelerate ), szTxt );
	}
	
	PRINTCHAT( client, client, CHAT_PREFIX ... "Type \x03!commands"...CLR_TEXT..." for more info." );
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "No records are available for this map!" );
	}
	
	return Plugin_Handled;
}

// Main component of the HUD timer.
public Action Timer_HudTimer( Handle hTimer )
{
	static int client;
	static int target;
	for ( client = 1; client <= MaxClients; client++ )
	{
		if ( !IsClientInGame( client ) ) continue;
		
		
		target = client;
		
		// Dead? Find the player we're spectating.
		if ( !IsPlayerAlive( client ) )
		{
			// Bad observer mode.
			if ( GetEntProp( client, Prop_Data, "m_iObserverMode" ) != OBS_MODE_IN_EYE )
				continue;
			
			
			target = GetEntPropEnt( client, Prop_Data, "m_hObserverTarget" );
			
			// Invalid spec target?
			// -1 = No spec target.
			// No target? No HUD.
			if ( target < 1 || target > MaxClients || !IsPlayerAlive( target ) )
				continue;
		}
		
		// Side info
		// Does not work in CS:GO.
#if !defined CSGO
		if ( !( g_fClientHideFlags[client] & HIDEHUD_SIDEINFO ) )
		{
			ShowKeyHintText( client, target );
		}
#endif
		
		if ( !( g_fClientHideFlags[client] & HIDEHUD_TIMER ) )
		{
#if defined RECORD
			if ( IsFakeClient( target ) )
			{
#if defined CSGO
				// For CS:GO.
				static char szTime[9];
				FormatSeconds( g_flMapBestTime[ g_iClientRun[target] ][ g_iClientStyle[target] ], szTime, sizeof( szTime ), FORMAT_NOHOURS );
				
				PrintHintText( client, "Record Bot [%s|%s]\n%s Name: %s\nSpeed: %4.0f",
					g_szRunName[NAME_LONG][ g_iClientRun[target] ],
					g_szStyleName[NAME_LONG][ g_iClientStyle[target] ],
					szTime,
					g_szRecName[ g_iClientRun[target] ][ g_iClientStyle[target] ],
					GetClientSpeed( target ) );
#else // CSGO
				// For CSS.
				PrintHintText( client, "Record Bot\n[%s|%s]\n \nSpeed\n%.0f",
					g_szRunName[NAME_LONG][ g_iClientRun[target] ],
					g_szStyleName[NAME_LONG][ g_iClientStyle[target] ],
					GetClientSpeed( target ) );
#endif // CSGO
				continue;
			}
#endif // RECORD

			if ( !g_bIsLoaded[ g_iClientRun[client] ] )
			{
				// No zones were found.
#if defined CSGO
				PrintHintText( client, "Speed: %4.0f", GetClientSpeed( target ) );
#else
				PrintHintText( client, "Speed\n%.0f", GetClientSpeed( target ) );
#endif
				continue;
			}
			
			if ( g_iClientState[target] == STATE_START )
			{
				// We are in the start zone.
#if defined CSGO
				PrintHintText( client, "Starting Zone\tSpeed: %4.0f", GetClientSpeed( target ) );
#else
				PrintHintText( client, "Starting Zone\n \nSpeed\n%.0f", GetClientSpeed( target ) );
#endif
				continue;
			}
			
			static float flSeconds;
			
			if ( g_iClientState[target] == STATE_END && g_flClientFinishTime[target] != TIME_INVALID ) 
			{
				// Show our finish time if we're at the ending
				flSeconds = g_flClientFinishTime[target];
			}
			else
			{
				// Else, we show our current time.
				flSeconds = GetEngineTime() - g_flClientStartTime[target];
			}
			
			static char szMyTime[SIZE_TIME_HINT];
			FormatSeconds( flSeconds, szMyTime, sizeof( szMyTime ), FORMAT_DESISECONDS );
			
#if defined CSGO
			if ( g_iClientStyle[client] == STYLE_W || g_iClientStyle[client] == STYLE_A_D )
			{
				PrintHintText( client, "%s\t\tSpeed: %4.0f\n%s%s\nJumps: %04i",
					szMyTime,
					GetClientSpeed( target ),
					g_szRunName[NAME_LONG][ g_iClientRun[ target ] ],
					( g_bIsClientPractising[target] ) ? " (P)" : "", // Practice mode warning
					g_nClientJumpCount[target] );
			}
			else
			{
				PrintHintText( client, "%s\t\tSpeed: %4.0f\n%s\t\tL Sync: %.1f%s\nJumps: %04i\tR Sync: %.1f",
					szMyTime,
					GetClientSpeed( target ),
					g_szRunName[NAME_LONG][ g_iClientRun[ target ] ],
					g_flClientSync[target][STRAFE_LEFT] * 100.0,
					( g_bIsClientPractising[target] ) ? " (P)" : "", // Practice mode warning
					g_nClientJumpCount[target],
					g_flClientSync[target][STRAFE_RIGHT] * 100.0 );
			}
#else
			// We don't have a map best time! We don't need to show anything else.
			if ( g_flMapBestTime[ g_iClientRun[target] ][ g_iClientStyle[target] ] <= TIME_INVALID )
			{
				PrintHintText( client, "%s\n \nSpeed\n%.0f",
					szMyTime,
					GetClientSpeed( target ) );
				
				continue;
			}
			
			
			int prefix = '-';
			static float flBestSeconds;
			
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
			
			static char szBestTime[SIZE_TIME_HINT];
			FormatSeconds( flBestSeconds, szBestTime, sizeof( szBestTime ), FORMAT_DESISECONDS );
			
			// WARNING: Each line has to have something (e.g space), or it will break.
			// "00:00:00.0C(+00:00:00.0) C CSpeedCXXXX" - [38]
			PrintHintText( client, "%s\n(%c%s) \n \nSpeed\n%.0f",
				szMyTime,
				prefix,
				szBestTime,
				GetClientSpeed( target ) );
#endif
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_ClientJoinTeam( Handle hTimer, any userid )
{
	int client;
	
	if ( ( client = GetClientOfUserId( userid ) ) < 1 ) return;
	
	if ( GetClientTeam( client) > CS_TEAM_SPECTATOR && !IsPlayerAlive( client ) )
	{
		CS_RespawnPlayer( client );
	}
}

public Action Timer_DoMapStuff( Handle hTimer )
{
	// Spawn the block zones.
	// Instead of looping through block zones in the main think function, we let the engine handle it.
	CreateBlockZoneEntity( ZONE_BLOCK_1 );
	CreateBlockZoneEntity( ZONE_BLOCK_2 );
	CreateBlockZoneEntity( ZONE_BLOCK_3 );
	
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

static const int BeamColor[NUM_ZONES][4] =
{
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

enum { POINT_BOTTOM, POINT_TOP, NUM_POINTS };
static float g_vecZonePoints[NUM_ZONES][NUM_POINTS][4][3];

stock void SetupZonePoints( int zone )
{
	// Called after zone mins and maxs are fixed.
	// Clock-wise
	
	// Bottom
	g_vecZonePoints[zone][POINT_BOTTOM][0][0] = g_vecZoneMins[zone][0] + ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_BOTTOM][0][1] = g_vecZoneMins[zone][1] + ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_BOTTOM][0][2] = g_vecZoneMins[zone][2] + ZONE_WIDTH;
	
	g_vecZonePoints[zone][POINT_BOTTOM][1][0] = g_vecZoneMaxs[zone][0] - ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_BOTTOM][1][1] = g_vecZoneMins[zone][1] + ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_BOTTOM][1][2] = g_vecZoneMins[zone][2] + ZONE_WIDTH;
	
	g_vecZonePoints[zone][POINT_BOTTOM][2][0] = g_vecZoneMaxs[zone][0] - ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_BOTTOM][2][1] = g_vecZoneMaxs[zone][1] - ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_BOTTOM][2][2] = g_vecZoneMins[zone][2] + ZONE_WIDTH;
	
	g_vecZonePoints[zone][POINT_BOTTOM][3][0] = g_vecZoneMins[zone][0] + ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_BOTTOM][3][1] = g_vecZoneMaxs[zone][1] - ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_BOTTOM][3][2] = g_vecZoneMins[zone][2] + ZONE_WIDTH;
	
	// Top
	g_vecZonePoints[zone][POINT_TOP][0][0] = g_vecZoneMins[zone][0] + ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_TOP][0][1] = g_vecZoneMins[zone][1] + ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_TOP][0][2] = g_vecZoneMaxs[zone][2] - ZONE_WIDTH;
	
	g_vecZonePoints[zone][POINT_TOP][1][0] = g_vecZoneMaxs[zone][0] - ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_TOP][1][1] = g_vecZoneMins[zone][1] + ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_TOP][1][2] = g_vecZoneMaxs[zone][2] - ZONE_WIDTH;
	
	g_vecZonePoints[zone][POINT_TOP][2][0] = g_vecZoneMaxs[zone][0] - ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_TOP][2][1] = g_vecZoneMaxs[zone][1] - ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_TOP][2][2] = g_vecZoneMaxs[zone][2] - ZONE_WIDTH;
	
	g_vecZonePoints[zone][POINT_TOP][3][0] = g_vecZoneMins[zone][0] + ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_TOP][3][1] = g_vecZoneMaxs[zone][1] - ZONE_WIDTH;
	g_vecZonePoints[zone][POINT_TOP][3][2] = g_vecZoneMaxs[zone][2] - ZONE_WIDTH;
}

public Action Timer_DrawZoneBeams( Handle hTimer )
{
	for ( int i; i < NUM_ZONES; i++ )
	{
		if ( !g_bZoneExists[i] ) continue;
		
		// Bottom
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_BOTTOM][0], g_vecZonePoints[i][POINT_BOTTOM][1], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_BOTTOM][1], g_vecZonePoints[i][POINT_BOTTOM][2], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_BOTTOM][2], g_vecZonePoints[i][POINT_BOTTOM][3], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_BOTTOM][3], g_vecZonePoints[i][POINT_BOTTOM][0], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		// Top
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_TOP][0], g_vecZonePoints[i][POINT_TOP][1], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_TOP][1], g_vecZonePoints[i][POINT_TOP][2], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_TOP][2], g_vecZonePoints[i][POINT_TOP][3], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_TOP][3], g_vecZonePoints[i][POINT_TOP][0], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		// From bottom to top.
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_BOTTOM][0], g_vecZonePoints[i][POINT_TOP][0], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_BOTTOM][1], g_vecZonePoints[i][POINT_TOP][1], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_BOTTOM][2], g_vecZonePoints[i][POINT_TOP][2], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( g_vecZonePoints[i][POINT_BOTTOM][3], g_vecZonePoints[i][POINT_TOP][3], g_iBeam, 0, 0, 0, ZONE_UPDATE_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[i], 0 );
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
	
	float flDif = vecClientPos[2] - g_vecZoneMins[g_iBuilderZone][2];
	
	if ( flDif <= 4.0 && flDif >= -4.0 )
		vecClientPos[2] += ZONE_DEF_HEIGHT;
	
	static float flPoint4Min[3], flPoint4Max[3];
	static float flPoint3Min[3];
	static float flPoint2Min[3], flPoint2Max[3];
	static float flPoint1Max[3];
	
	flPoint4Min[0] = g_vecZoneMins[g_iBuilderZone][0]; flPoint4Min[1] = vecClientPos[1]; flPoint4Min[2] = g_vecZoneMins[g_iBuilderZone][2];
	flPoint4Max[0] = g_vecZoneMins[g_iBuilderZone][0]; flPoint4Max[1] = vecClientPos[1]; flPoint4Max[2] = vecClientPos[2];
	
	flPoint3Min[0] = vecClientPos[0]; flPoint3Min[1] = vecClientPos[1]; flPoint3Min[2] = g_vecZoneMins[g_iBuilderZone][2];
	
	flPoint2Min[0] = vecClientPos[0]; flPoint2Min[1] = g_vecZoneMins[g_iBuilderZone][1]; flPoint2Min[2] = g_vecZoneMins[g_iBuilderZone][2];
	flPoint2Max[0] = vecClientPos[0]; flPoint2Max[1] = g_vecZoneMins[g_iBuilderZone][1]; flPoint2Max[2] = vecClientPos[2];
	
	flPoint1Max[0] = g_vecZoneMins[g_iBuilderZone][0]; flPoint1Max[1] = g_vecZoneMins[g_iBuilderZone][1]; flPoint1Max[2] = vecClientPos[2];
	
	TE_SetupBeamPoints( g_vecZoneMins[g_iBuilderZone], flPoint1Max, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( g_vecZoneMins[g_iBuilderZone], flPoint4Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( g_vecZoneMins[g_iBuilderZone], flPoint2Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint3Min, vecClientPos, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint3Min, flPoint4Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint3Min, flPoint2Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint2Max, flPoint2Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint2Max, flPoint1Max, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint2Max, vecClientPos, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint4Max, flPoint4Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint4Max, flPoint1Max, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint4Max, vecClientPos, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, BeamColor[g_iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	return Plugin_Continue;
}
///////////////
// RECORDING //
///////////////
#if defined RECORD
public Action Timer_Rec_Start( Handle hTimer, any mimic )
{
	if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) || g_hRec[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ] == null || !g_bIsLoaded[ g_iClientRun[mimic] ] )
		return Plugin_Handled;
	
	
	g_nClientTick[mimic] = 0;
	g_bClientMimicing[mimic] = true;
	
	return Plugin_Handled;
}

// WAIT TIME BETWEEN RECORDS
public Action Timer_Rec_Restart( Handle hTimer, any mimic )
{
	if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) || g_hRec[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ] == null || !g_bIsLoaded[ g_iClientRun[mimic] ] )
		return Plugin_Handled;
	
	
	g_nClientTick[mimic] = TICK_PRE_PLAYBLACK;
	TeleportEntity( mimic, g_vecInitRecPos[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ], g_vecInitRecAng[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ], g_vecNull );
	
	CreateTimer( 2.0, Timer_Rec_Start, mimic, TIMER_FLAG_NO_MAPCHANGE );
	
	return Plugin_Handled;
}

/*public Action Timer_Rec_Stop( Handle hTimer, any mimic )
{
	if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) )
		return Plugin_Handled;
	
	delete g_hRec[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ];
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