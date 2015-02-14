// Query handles are closed automatically.

public void Threaded_PrintRecords( Handle hOwner, Handle hQuery, const char[] szError, any hData )
{
	int client;
	if ( ( client = GetClientOfUserId( GetArrayCell( hData, 0, 0 ) ) ) == 0 ) return;
	
	if ( hQuery == null )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( "%s An error occured when trying to print times to client.\nError: %s", CONSOLE_PREFIX, g_szError );
	
		PrintColorChat( client, client, "%s Sorry, something went wrong.", CHAT_PREFIX );
		return;
	}
	
	int field, ply;
	
	int iJumps[RECORDS_PRINT_MAXPLAYERS + 1], iStyle[RECORDS_PRINT_MAXPLAYERS + 1];
	static float flSeconds[RECORDS_PRINT_MAXPLAYERS + 1];
	
	char szSteamId[RECORDS_PRINT_MAXPLAYERS + 1][STEAMID_MAXLENGTH];
	char szName[RECORDS_PRINT_MAXPLAYERS + 1][MAX_NAME_LENGTH];
	char szFormTime[RECORDS_PRINT_MAXPLAYERS + 1][12];
	
	bool bInConsole = GetArrayCell( hData, 0, 1 );
	
	while ( SQL_FetchRow( hQuery ) )
	{
		if ( bInConsole )
		{
			SQL_FieldNameToNum( hQuery, "steamid", field );
			SQL_FetchString( hQuery, field, szSteamId[ply], sizeof( szSteamId[] ) );
		
			SQL_FieldNameToNum( hQuery, "jumps", field );
			iJumps[ply] = SQL_FetchInt( hQuery, field );
		}
		
		SQL_FieldNameToNum( hQuery, "name", field );
		SQL_FetchString( hQuery, field, szName[ply], sizeof( szName[] ) );
		
		SQL_FieldNameToNum( hQuery, "time", field );
		flSeconds[ply] = SQL_FetchFloat( hQuery, field );
		//flSeconds[ply] += 0.0001; // Just to make sure...
		
		SQL_FieldNameToNum( hQuery, "style", field );
		iStyle[ply] = SQL_FetchInt( hQuery, field );
		
		FormatSeconds( flSeconds[ply], szFormTime[ply], sizeof( szFormTime[] ), true );
		
		ply++;
	}
	
	int index = 1;
	if ( !bInConsole )
	{
		static char szText[200];
		
		if ( ply > 0 )
		{
			Format( szText, sizeof( szText ), "!printrecords for detailed version." );
			
			for ( int i; i < ply; i++ )
			{
				Format( szText, sizeof( szText ), "%s\n%i. %s - %s - %s", szText, index, szName[i], szFormTime[i], g_szStyleName[NAME_SHORT][ iStyle[i] ] );
				index++;
			}
		}
		else Format( szText, sizeof( szText ), "No one has beaten the map yet... :(" );
		
		ShowMOTDPanel( client, "Top 5 (All modes)", szText, MOTDPANEL_TYPE_TEXT );
	}
	else
	{
		PrintToConsole( client, "\nRecords (Max. %i):\n!printrecord <style> for specific modes. (\"normal\", \"sideways\", \"w\", \"b1/b2\")\n----------------", RECORDS_PRINT_MAXPLAYERS );
		
		if ( ply > 0 )
		{
			for ( int i; i < ply; i++ )
			{
				PrintToConsole( client, "%i. %s - %s - %s - %s - %i jumps", index, szSteamId[i], szName[i], szFormTime[i], g_szStyleName[NAME_LONG][ iStyle[i] ], iJumps[i] );
				index++;
			}
		}
		else PrintToConsole( client, "No one has beaten the map yet... :(" );
		
		PrintToConsole( client, "----------------" );
		
		PrintColorChat( client, client, "%s Printed all (%i) records in your console.", CHAT_PREFIX, ply );
	}
}

public void Threaded_RetrieveClientInfo( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( "%s Couldn't retrieve player data!\n g_szError: %s", CONSOLE_PREFIX, g_szError );
		
		return;
	}
	
	int client;
	
	if ( ( client = GetClientOfUserId( data ) ) == 0 ) return;
	
	char szSteamId[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamId, sizeof( szSteamId ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return;
	}
	
	static char szQuery[128];
	
	if ( SQL_GetRowCount( hQuery ) == 0 )
	{
		Format( szQuery, sizeof( szQuery ), "INSERT INTO player_data ( steamid, fov, hideflags ) VALUES ( '%s', 90, 0 );", szSteamId );
		
		SQL_LockDatabase( g_Database );
		
		if ( !SQL_FastQuery( g_Database, szQuery ) )
		{
			SQL_UnlockDatabase( g_Database );
			
			LogError( "%s Error! Couldn't add a row for new profile!! Steam ID: %s", CONSOLE_PREFIX, szSteamId );
			return;
		}
		
		SQL_UnlockDatabase( g_Database );
		
		return;
	}
	
	int field;
	while ( SQL_FetchRow( hQuery ) )
	{
		SQL_FieldNameToNum( hQuery, "fov", field );
		g_iClientFOV[client] = SQL_FetchInt( hQuery, field );
		
		SQL_FieldNameToNum( hQuery, "hideflags", field );
		g_iClientHideFlags[client] = SQL_FetchInt( hQuery, field );
	}
	
	Format( szQuery, sizeof( szQuery ), "SELECT time, style, run FROM '%s' WHERE steamid = '%s' ORDER BY run;", g_szCurrentMap, szSteamId );
	SQL_TQuery( g_Database, Threaded_RetrieveClientTimes, szQuery, GetClientUserId( client ) );
}

public void Threaded_RetrieveClientTimes( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( "%s Couldn't retrieve player data!\n Error: %s", CONSOLE_PREFIX, g_szError );
		
		return;
	}

	int client;
	if ( ( client = GetClientOfUserId( data ) ) == 0 ) return;
	
	if ( hQuery != null )
	{
		int field, iStyle, iRun;
		while ( SQL_FetchRow( hQuery ) )
		{
			SQL_FieldNameToNum( hQuery, "run", field );
			iRun = SQL_FetchInt( hQuery, field );
			
			SQL_FieldNameToNum( hQuery, "style", field );
			iStyle = SQL_FetchInt( hQuery, field );
		
			SQL_FieldNameToNum( hQuery, "time", field );
			g_flClientBestTime[client][iRun][iStyle] = SQL_FetchFloat( hQuery, field );
		}
	}
	
	UpdateScoreboard( client );
}

// No callback is needed.
public void Threaded_Empty( Handle hOwner, Handle hQuery, const char[] szError, any data ) {}