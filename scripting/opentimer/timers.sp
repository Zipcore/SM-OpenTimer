// Every 3600 seconds we check if there are any players around. If not, we restart the map for performance reasons.
public Action:Timer_RestartMap( Handle:hTimer )
{
	PrintToServer( "%s Attempting to restart map!", CONSOLE_PREFIX );
	
	for ( new i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) && !IsFakeClient( i ) )
			return Plugin_Continue;
	
	ServerCommand( "changelevel %s", CurrentMap );
	
	return Plugin_Handled;
}

public Action:Timer_Connected( Handle:hTimer, any:client )
{
	if ( !IsClientInGame( client ) ) return Plugin_Handled;
	
	if ( ConVar_AirAccelerate != INVALID_HANDLE )
		PrintColorChat( client, client, "\n%sServer is running: %.0ftick, %iaa, Auto/EZhop and Practice Mode.", COLOR_TEAL, 1 / GetTickInterval(), GetConVarInt( ConVar_AirAccelerate ) );
	
	PrintColorChat( client, client, "%s Type !commands for more info.", CHAT_PREFIX );
	
	if ( !bIsLoaded[RUN_MAIN] )
		PrintColorChat( client, client, "%s No records are available for this map!", CHAT_PREFIX );
	
	return Plugin_Handled;
}

// Main component of the HUD timer.
public Action:Timer_ShowClientInfo( Handle:hTimer, any:client )
{
	if ( !IsClientInGame( client ) ) return Plugin_Stop;
	
	new target = client;
	if ( !( iClientHideFlags[client] & HIDEHUD_SIDEINFO ) )
	{
		if ( IsPlayerAlive( client ) ) ShowKeyHintText( client, client );
		else
		{
			target = GetEntPropEnt( client, Prop_Data, "m_hObserverTarget" );
			
			if ( target > 1 && IsPlayerAlive( target ) && !IsFakeClient( target ) ) ShowKeyHintText( client, target );
		}
	}
	
	if ( !( iClientHideFlags[client] & HIDEHUD_TIMER ) )
	{
		if ( !IsPlayerAlive( client ) )
		{
			target = GetEntPropEnt( client, Prop_Data, "m_hObserverTarget" );
			
			if ( target < 1 || !IsPlayerAlive( target ) ) return Plugin_Continue;
			else if ( IsFakeClient( target ) )
			{
				PrintHintText( client, "Replay Bot\n[%s|%s]\n \nSpeed\n%.0f", RunName[NAME_LONG][ iClientRun[target] ], StyleName[NAME_LONG][ iClientStyle[target] ], GetClientVelocity( target ) );
				return Plugin_Continue;
			}
		}
		
		if ( !bIsLoaded[ iClientRun[client] ] )
		{
			PrintHintText( client, "Speed\n%.0f", GetClientVelocity( target ) );
			return Plugin_Continue;
		}
		
		if ( iClientState[target] == STATE_START )
		{
			PrintHintText( client, "Starting Zone\n \nSpeed\n%.0f", GetClientVelocity( target ) );
			return Plugin_Continue;
		}
		
		decl Float:flSeconds, Float:flBestSeconds, String:TextBuffer[92];
		new char = '-';
		
		if ( iClientState[target] != STATE_RUNNING ) flSeconds = flClientFinishTime[target];
		else flSeconds = GetEngineTime() - flClientStartTime[target];
		
		if ( flMapBestTime[ iClientRun[target] ][ iClientStyle[target] ] > flSeconds )
			flBestSeconds = flMapBestTime[ iClientRun[target] ][ iClientStyle[target] ] - flSeconds;
		else if ( flMapBestTime[ iClientRun[target] ][ iClientStyle[target] ] > 0.0 )
		{
			flBestSeconds = flSeconds - flMapBestTime[ iClientRun[target] ][ iClientStyle[target] ];
			char = '+';
		}
		
		decl String:FormattedMyTime[13], String:FormattedBestTime[13];
		FormatSeconds( flSeconds, FormattedMyTime, false );
		
		if ( flMapBestTime[ iClientRun[target] ][ iClientStyle[target] ] != 0.0 )
			FormatSeconds( flBestSeconds, FormattedBestTime, false );
		
		// 00:00:00.0\n(+00:00:00.0)Vel - 1000.0\nStrafes - 1000
		if ( flMapBestTime[ iClientRun[target] ][ iClientStyle[target] ] > 0.0 )
			Format( TextBuffer, sizeof( TextBuffer ), "%s\n(%c%s)\n \nSpeed\n%.0f", FormattedMyTime, char, FormattedBestTime, GetClientVelocity( target ) );
		else
			Format( TextBuffer, sizeof( TextBuffer ), "%s\n \nSpeed\n%.0f", FormattedMyTime, GetClientVelocity( target ) );
		
		PrintHintText( client, TextBuffer );
	}
	
	return Plugin_Continue;
}

#if defined DELETE_ENTS
public Action:Timer_DoMapStuff( Handle:hTimer )
{
	new ent = -1;

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
}
#endif

static const BeamColor[MAX_BOUNDS][] = {
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
public Action:Timer_DrawZoneBeams( Handle:hTimer )
{
	decl Float:flPoint4Min[3], Float:flPoint4Max[3], Float:flPoint3Min[3], Float:flPoint2Min[3], Float:flPoint2Max[3], Float:flPoint1Max[3];
	
	for ( new i; i < MAX_BOUNDS; i++ )
	{
		if ( !bZoneExists[i] ) continue;
		
		flPoint4Min[0] = vecBoundsMin[i][0]; flPoint4Min[1] = vecBoundsMax[i][1]; flPoint4Min[2] = vecBoundsMin[i][2] + 2.0;
		flPoint4Max[0] = vecBoundsMin[i][0]; flPoint4Max[1] = vecBoundsMax[i][1]; flPoint4Max[2] = vecBoundsMax[i][2] - 2.0;
		
		flPoint3Min[0] = vecBoundsMax[i][0]; flPoint3Min[1] = vecBoundsMax[i][1]; flPoint3Min[2] = vecBoundsMin[i][2] + 2.0;
		//flStartPoint3Max[0] = vecBoundsMax[i][0]; flStartPoint3Max[1] = vecBoundsMax[i][1]; flStartPoint3Max[2] = vecBoundsMax[i][2] - 2.0;
		
		flPoint2Min[0] = vecBoundsMax[i][0]; flPoint2Min[1] = vecBoundsMin[i][1]; flPoint2Min[2] = vecBoundsMin[i][2] + 2.0;
		flPoint2Max[0] = vecBoundsMax[i][0]; flPoint2Max[1] = vecBoundsMin[i][1]; flPoint2Max[2] = vecBoundsMax[i][2] - 2.0;
		
		//flStartPoint1Min[0] = vecBoundsMin[i][0]; flStartPoint1Min[1] = vecBoundsMin[i][1]; flStartPoint1Min[2] = vecBoundsMin[i][2] + 2.0;
		flPoint1Max[0] = vecBoundsMin[i][0]; flPoint1Max[1] = vecBoundsMin[i][1]; flPoint1Max[2] = vecBoundsMax[i][2] - 2.0;
		
		
		TE_SetupBeamPoints( vecBoundsMin[i], flPoint1Max, iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( vecBoundsMin[i], flPoint4Min, iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( vecBoundsMin[i], flPoint2Min, iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint3Min, vecBoundsMax[i], iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint3Min, flPoint4Min, iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint3Min, flPoint2Min, iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint2Max, flPoint2Min, iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint2Max, flPoint1Max, iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint2Max, vecBoundsMax[i], iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint4Max, flPoint4Min, iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint4Max, flPoint1Max, iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
		
		TE_SetupBeamPoints( flPoint4Max, vecBoundsMax[i], iBeam, 0, 0, 0, BOUNDS_UPDATE_INTERVAL, 2.0, 2.0, 0, 0.0, BeamColor[i], 0 );
		TE_SendToAll( 0.0 );
	}
	
	return Plugin_Continue;
}

public Action:Timer_DrawBuildZoneBeams( Handle:timer, any:client )
{
	if ( iBuilderZone == -1 || iBuilderIndex < 1 || !IsClientInGame( client ) || !IsPlayerAlive( client ) )
	{
		iBuilderIndex = 0;
		iBuilderZone = -1;
		
		return Plugin_Stop;
	}
	
	decl Float:vecClientPos[3];
	GetClientAbsOrigin( client, vecClientPos );
	
	vecClientPos[0] = vecClientPos[0] - ( RoundFloat( vecClientPos[0] ) % iBuilderGridSize );
	vecClientPos[1] = vecClientPos[1] - ( RoundFloat( vecClientPos[1] ) % iBuilderGridSize );
	
	decl Float:flPoint4Min[3], Float:flPoint4Max[3], Float:flPoint3Min[3], Float:flPoint2Min[3], Float:flPoint2Max[3], Float:flPoint1Max[3];
	
	flPoint4Min[0] = vecBoundsMin[iBuilderZone][0]; flPoint4Min[1] = vecClientPos[1]; flPoint4Min[2] = vecBoundsMin[iBuilderZone][2];
	flPoint4Max[0] = vecBoundsMin[iBuilderZone][0]; flPoint4Max[1] = vecClientPos[1]; flPoint4Max[2] = vecClientPos[2];
	
	flPoint3Min[0] = vecClientPos[0]; flPoint3Min[1] = vecClientPos[1]; flPoint3Min[2] = vecBoundsMin[iBuilderZone][2];
	//flPoint3Max[0] = vecBoundsMax[iBuilderZone][0]; flPoint3Max[1] = vecBoundsMax[iBuilderZone][1]; flPoint3Max[2] = vecBoundsMax[iBuilderZone][2];
	
	flPoint2Min[0] = vecClientPos[0]; flPoint2Min[1] = vecBoundsMin[iBuilderZone][1]; flPoint2Min[2] = vecBoundsMin[iBuilderZone][2];
	flPoint2Max[0] = vecClientPos[0]; flPoint2Max[1] = vecBoundsMin[iBuilderZone][1]; flPoint2Max[2] = vecClientPos[2];
	
	//flPoint1Min[0] = vecBoundsMin[iBuilderZone][0]; flPoint1Min[1] = vecBoundsMin[iBuilderZone][1]; flPoint1Min[2] = vecBoundsMin[iBuilderZone][2];
	flPoint1Max[0] = vecBoundsMin[iBuilderZone][0]; flPoint1Max[1] = vecBoundsMin[iBuilderZone][1]; flPoint1Max[2] = vecClientPos[2];
	
	TE_SetupBeamPoints( vecBoundsMin[iBuilderZone], flPoint1Max, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( vecBoundsMin[iBuilderZone], flPoint4Min, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( vecBoundsMin[iBuilderZone], flPoint2Min, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint3Min, vecClientPos, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint3Min, flPoint4Min, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint3Min, flPoint2Min, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint2Max, flPoint2Min, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint2Max, flPoint1Max, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint2Max, vecClientPos, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint4Max, flPoint4Min, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint4Max, flPoint1Max, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	TE_SetupBeamPoints( flPoint4Max, vecClientPos, iBeam, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, BeamColor[iBuilderZone], 0 );
	TE_SendToClient( client, 0.0 );
	
	return Plugin_Continue;
}
///////////////
// RECORDING //
///////////////
#if defined RECORD
public Action:Timer_Rec_Start( Handle:hTimer, any:mimic )
{
	if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) || hMimicRecording[ iClientRun[mimic] ][ iClientStyle[mimic] ] == INVALID_HANDLE )
		return Plugin_Handled;
	
	iClientTick[mimic] = 0;
	bIsClientMimicing[mimic] = true;
	
	return Plugin_Handled;
}

// WAIT TIME BETWEEN RECORDS
public Action:Timer_Rec_Restart( Handle:hTimer, any:mimic )
{
	if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) || hMimicRecording[ iClientRun[mimic] ][ iClientStyle[mimic] ] == INVALID_HANDLE )
		return Plugin_Handled;
	
	iClientTick[mimic] = -1;
	TeleportEntity( mimic, vecInitMimicPos[ iClientRun[mimic] ][ iClientStyle[mimic] ], angInitMimicAngles[ iClientRun[mimic] ][ iClientStyle[mimic] ], vecNull );
	SetEntProp( mimic, Prop_Data, "m_nButtons", 0 );
	
	CreateTimer( 2.0, Timer_Rec_Start, mimic );
	
	return Plugin_Handled;
}

/*public Action:Timer_Rec_Stop( Handle:hTimer, any:mimic )
{
	if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) )
		return Plugin_Handled;
	
	CloseHandle( hMimicRecording[ iClientRun[mimic] ][ iClientStyle[mimic] ] );
	AcceptEntityInput( mimic, "Kill" );
	
	return Plugin_Handled;
}*/
#endif

#if defined VOTING
public Action:Timer_ChangeMap( Handle:hTimer )
{
	ServerCommand( "changelevel %s", NextMap );
	return Plugin_Handled;
}
#endif