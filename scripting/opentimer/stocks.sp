// From SMLIB
stock void ArrayCopy( const any[] oldArray, any[] newArray, int size = 1 )
{
	for ( int i; i < size; i++ ) newArray[i] = oldArray[i];
}

stock void ArrayFill( any[] Array, any data, int size = 1 )
{
	for ( int i; i < size; i++ ) Array[i] = data;
}

// Format seconds and make them look nice.
stock void FormatSeconds( float flSeconds, char[] szTarget, int iLength, bool bIsDeci, bool bColored = false )
{
	int				iHours;
	int				iMins;
	static char		szHours[3];
	static char		szMins[3];
	static char		szSec[7];
	
	while ( flSeconds >= 3600.0 )
	{
		iHours++;
		flSeconds -= 3600.0;
	}
	
	while ( flSeconds >= 60.0 )
	{
		iMins++;
		flSeconds -= 60.0;
	}
	
	Format( szHours, sizeof( szHours ), ( iHours < 10 ) ? "0%i" : "%i", iHours );
	
	Format( szMins, sizeof( szMins ), ( iMins < 10 ) ? "0%i" : "%i", iMins );
	
	if ( flSeconds < 10.0 )
	{
		Format( szSec, sizeof( szSec ), bIsDeci ? "0%.2f" : "0%.1f", flSeconds );
	}
	else
	{
		Format( szSec, sizeof( szSec ), bIsDeci ? "%.2f" : "%.1f", flSeconds );
	}
	
	// "XX:XX:XX.X" - [11] (HINT)
	// "XX:XX:XX.XX" - [12] (RECORDS)
	// "CXXC:CXXC:CXX.XX" - [17] (CHAT)
	if ( !bColored )
	{
		Format( szTarget, iLength, "%s:%s:%s", szHours, szMins, szSec );
	}
	else
	{
		Format( szTarget, iLength, "\x03%s\x06:\x03%s\x06:\x03%s", szHours, szMins, szSec );
	}
}

// "Real" velocity
stock float GetClientVelocity( int client )
{
	static float vecVel[3];
	GetEntPropVector( client, Prop_Data, "m_vecVelocity", vecVel );
	
	return SquareRoot( ( vecVel[0] * vecVel[0] ) + ( vecVel[1] * vecVel[1] ) );
}

// Tell people what our time is in the clan section of scoreboard.
stock void UpdateScoreboard( int client )
{
	if ( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] <= TIME_INVALID )
	{
		CS_SetClientClanTag( client, "" );
		return;
	}
	
	char szNewTime[11];
	FormatSeconds( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ], szNewTime, sizeof( szNewTime ), false );
	CS_SetClientClanTag( client, szNewTime );
}

stock void SetClientFOV( int client, int fov )
{
	SetEntProp( client, Prop_Data, "m_iFOV", fov );
	SetEntProp( client, Prop_Data, "m_iDefaultFOV", fov );
}

#if defined VOTING
	stock int GetActivePlayers()
	{
		int clients;
		
		for ( int i = 1; i <= MaxClients; i++ )
			if ( IsClientInGame( i ) && !IsFakeClient( i ) && IsPlayerAlive( i ) )
				clients++;
				
		return clients;
	}

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
				PrintColorChatAll( 0, false, "%s Enough people voted for \x03%s%s! Changing map...", CHAT_PREFIX, g_szNextMap, COLOR_TEXT );
				
				return;
			}
	}
#endif
// Used for players and other entities.
stock bool IsInsideBounds( int ent, int bounds )
{
	if ( !g_bZoneExists[bounds] ) return false;
	
	static float vecPos[3];
	GetEntPropVector( ent, Prop_Data, "m_vecOrigin", vecPos );
	
	// Basically, a shit ton of checking if the entity is between coordinates.
	// This allows mins and maxs to be "switched", meaning that mins can actually be bigger than maxs.
	return (
		( ( vecPos[0] >= g_vecBoundsMin[bounds][0] && vecPos[0] <= g_vecBoundsMax[bounds][0] ) || ( vecPos[0] <= g_vecBoundsMin[bounds][0] && vecPos[0] >= g_vecBoundsMax[bounds][0] ) )
		&&
		( ( vecPos[1] >= g_vecBoundsMin[bounds][1] && vecPos[1] <= g_vecBoundsMax[bounds][1] ) || ( vecPos[1] <= g_vecBoundsMin[bounds][1] && vecPos[1] >= g_vecBoundsMax[bounds][1] ) )
		&&
		( ( vecPos[2] >= g_vecBoundsMin[bounds][2] && vecPos[2] <= g_vecBoundsMax[bounds][2] ) || ( vecPos[2] <= g_vecBoundsMin[bounds][2] && vecPos[2] >= g_vecBoundsMax[bounds][2] ) ) );
}