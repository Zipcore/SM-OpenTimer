// From SMLIB
stock void ArrayCopy( const any[] oldArray, any[] newArray, int size = 1 )
{
	for ( int i; i < size; i++ ) newArray[i] = oldArray[i];
}

stock void ArrayFill( any[] Array, any data, int size = 1 )
{
	for ( int i; i < size; i++ ) Array[i] = data;
}

stock void CorrectMinsMaxs( float vecMins[3], float vecMaxs[3] )
{
	// Corrects map zones.
	float f;
	
	if ( vecMins[0] > vecMaxs[0] )
	{
		f = vecMins[0];
		vecMins[0] = vecMaxs[0];
		vecMaxs[0] = f;
	}
	
	if ( vecMins[1] > vecMaxs[1] )
	{
		f = vecMins[1];
		vecMins[1] = vecMaxs[1];
		vecMaxs[1] = f;
	}
	
	if ( vecMins[2] > vecMaxs[2] )
	{
		f = vecMins[2];
		vecMins[2] = vecMaxs[2];
		vecMaxs[2] = f;
	}
}

// Format seconds and make them look nice.
stock void FormatSeconds( float flSeconds, char[] szTarget, int iLength, int fFlags = 0 )
{
	static int		iHours;
	int				iMins;
	static char		szSec[6];
	
	if ( !( fFlags & FORMAT_NOHOURS ) )
	{
		iHours = 0;
		
		while ( flSeconds >= 3600.0 )
		{
			iHours++;
			flSeconds -= 3600.0;
		}
	}
	
	while ( flSeconds >= 60.0 )
	{
		iMins++;
		flSeconds -= 60.0;
	}
	
	// XX.XX
	FormatEx( szSec, sizeof( szSec ), ( fFlags & FORMAT_DESISECONDS ) ? "%04.1f" : "%05.2f", flSeconds );
	
	// "XX:XX.X" - [8] (SCOREBOARD)
	// "XX:XX.XX" - [9] (CSGO)
	// "XX:XX:XX.X" - [11] (HINT)
	// "XX:XX:XX.XX" - [12] (RECORDS)
	// "CXXC:CXXC:CXX.XX" - [17] (CHAT)
	if ( fFlags & FORMAT_COLORED )
	{
		FormatEx( szTarget, iLength, "\x03%02i\x06:\x03%02i\x06:\x03%s", iHours, iMins, szSec );
	}
	else if ( fFlags & FORMAT_NOHOURS )
	{
		FormatEx( szTarget, iLength, "%02i:%s", iMins, szSec );
	}
	else FormatEx( szTarget, iLength, "%02i:%02i:%s", iHours, iMins, szSec );
}

// "Real" velocity
stock float GetClientSpeed( int client )
{
	static float vecVel[3];
	GetEntPropVector( client, Prop_Data, "m_vecVelocity", vecVel );
	
	return SquareRoot( vecVel[0] * vecVel[0] + vecVel[1] * vecVel[1] );
}

stock void HideEntity( int ent )
{
	SetEntityRenderMode( ent, RENDER_TRANSALPHA );
	SetEntityRenderColor( ent, _, _, _, 0 );
}

// Tell people what our time is in the clan section of scoreboard.
stock void UpdateScoreboard( int client )
{
	if ( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] <= TIME_INVALID )
	{
		CS_SetClientClanTag( client, "" );
		return;
	}
	
	
	char szNewTime[SIZE_TIME_SCOREBOARD];
	FormatSeconds( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ], szNewTime, sizeof( szNewTime ), FORMAT_NOHOURS );
	CS_SetClientClanTag( client, szNewTime );
}

stock void SetClientFOV( int client, int fov )
{
	// I wonder if there's a way to stop weapon switching resetting your FOV...
	SetEntProp( client, Prop_Send, "m_iFOV", fov );
	SetEntProp( client, Prop_Send, "m_iDefaultFOV", fov ); // This affects player's sensitivity. Should always be the same as desired FOV.
	//SetEntProp( client, Prop_Send, "m_iFOVStart", fov );
}

stock int GetActivePlayers( int ignore = 0 )
{
	int clients;
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( i == ignore ) continue;
		
		if ( IsClientInGame( i ) && !IsFakeClient( i ) )
			clients++;
	}
	
	return clients;
}

#if defined VOTING
	stock void CalcVotes()
	{
		int iClients = GetActivePlayers();
		
		if ( iClients < 1 || g_hMapList == null ) return;
		
		
		int len = GetArraySize( g_hMapList );
		int[] iMapVotes = new int[len];
		
		// Gather votes
		for ( int i = 1; i <= MaxClients; i++ )
			if ( IsClientInGame( i ) && g_iClientVote[i] != -1 )
				iMapVotes[ g_iClientVote[i] ]++;
		
		// Get maximum needed votes.
		int iReq = 1;
		
		if ( iClients > 2 )
		{
			iReq = RoundFloat( iClients * 0.8 );
		}
		
		// Check if we have a winrar
		for ( int i; i < len; i++ )
			if ( iMapVotes[i] >= iReq )
			{
				int iMap[MAX_MAP_NAME_LENGTH];
				GetArrayArray( g_hMapList, i, iMap, view_as<int>MapInfo );
				strcopy( g_szNextMap, sizeof( g_szNextMap ), iMap[MAP_NAME] );
				
				CreateTimer( 3.0, Timer_ChangeMap, TIMER_FLAG_NO_MAPCHANGE );
				PRINTCHATALLV( 0, false, CHAT_PREFIX ... "Enough people voted for \x03%s"...CLR_TEXT..."! Changing map...", g_szNextMap );
				
				return;
			}
	}
#endif