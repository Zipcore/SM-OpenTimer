// Query handles are closed automatically.

public Threaded_PrintRecords( Handle:hDatabase, Handle:hQuery, const String:error[], any:hData )
{
	new client; 
	if ( ( client = GetClientOfUserId( GetArrayCell( hData, 0, 0 ) ) ) == 0 )
		return;
	
	if ( hQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Error occured when trying to print times to client.\nError: %s", CONSOLE_PREFIX, Error );
	
		PrintColorChat( client, client, "%s Sorry, something went wrong.", CHAT_PREFIX );
		return;
	}
	
	new field, ply, iJumps[17], iStyle[17];
	decl Float:flSeconds[17], String:SteamID[17][32], String:Name[17][MAX_NAME_LENGTH], String:FormattedTime[17][13];
	
	new bool:bInConsole = GetArrayCell( hData, 0, 1 );
	
	while ( SQL_FetchRow( hQuery ) )
	{
		if ( bInConsole )
		{
			SQL_FieldNameToNum( hQuery, "steamid", field );
			SQL_FetchString( hQuery, field, SteamID[ply], sizeof( SteamID[] ) );
		
			SQL_FieldNameToNum( hQuery, "jumps", field );
			iJumps[ply] = SQL_FetchInt( hQuery, field );
		}
		
		SQL_FieldNameToNum( hQuery, "name", field );
		SQL_FetchString( hQuery, field, Name[ply], sizeof( Name[] ) );
		
		SQL_FieldNameToNum( hQuery, "time", field );
		flSeconds[ply] = SQL_FetchFloat( hQuery, field );
		//flSeconds[ply] += 0.0001; // Just to make sure...
		
		SQL_FieldNameToNum( hQuery, "style", field );
		iStyle[ply] = SQL_FetchInt( hQuery, field );
		
		FormatSeconds( flSeconds[ply], FormattedTime[ply], true );
		
		ply++;
	}
	
	new index = 1;
	if ( !bInConsole )
	{
		decl String:Text[200];
		
		if ( ply > 0 )
		{
			Format( Text, sizeof( Text ), "!printrecords for detailed version." );
			
			for ( new i; i < ply; i++ )
			{
				Format( Text, sizeof( Text ), "%s\n%i. %s - %s - %s", Text, index, Name[i], FormattedTime[i], StyleName[NAME_SHORT][ iStyle[i] ] );
				index++;
			}
		}
		else Format( Text, sizeof( Text ), "No one has beaten the map yet... :(" );
		
		ShowMOTDPanel( client, "Top 5 (All modes)", Text, MOTDPANEL_TYPE_TEXT );
	}
	else
	{
		PrintToConsole( client, "\nRecords (Max. 16):\n!printrecord <style> for specific modes. (\"normal\", \"sideways\", \"w\", \"b1/b2\")\n----------------" );
		
		if ( ply > 0 )
		{
			for ( new i; i < ply; i++ )
			{
				PrintToConsole( client, "%i. %s - %s - %s - %s - %i jumps", index, SteamID[i], Name[i], FormattedTime[i], StyleName[NAME_LONG][ iStyle[i] ], iJumps[i] );
				index++;
			}
		}
		else PrintToConsole( client, "No one has beaten the map yet... :(" );
		
		PrintToConsole( client, "----------------" );
		
		PrintColorChat( client, client, "%s Printed all (%i) records in your console.", CHAT_PREFIX, ply );
	}
}

public Threaded_RetrieveClientInfo( Handle:hDatabase, Handle:hQuery, const String:error[], any:data )
{
	if ( hQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't retrieve player data!\n Error: %s", CONSOLE_PREFIX, Error );
		
		return;
	}

	new client;
	if ( ( client = GetClientOfUserId( data ) ) == 0 )
		return;
		
	decl String:SteamID[32];
	
	if ( !GetClientAuthString( client, SteamID, sizeof( SteamID ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return;
	}
	
	decl String:Buffer[128];
	
	if ( SQL_GetRowCount( hQuery ) == 0 )
	{
		Format( Buffer, sizeof( Buffer ), "INSERT INTO player_data ( steamid, fov, hideflags ) VALUES ( '%s', 90, 0 );", SteamID );
		
		if ( !SQL_FastQuery( Database, Buffer ) )
		{
			LogError( "%s Error! Couldn't add a row for new profile!! Steam ID: %s", CONSOLE_PREFIX, SteamID );
			return;
		}

		return;
	}

	new field;
	while ( SQL_FetchRow( hQuery ) )
	{
		SQL_FieldNameToNum( hQuery, "fov", field );
		iClientFOV[client] = SQL_FetchInt( hQuery, field );
		
		SQL_FieldNameToNum( hQuery, "hideflags", field );
		iClientHideFlags[client] = SQL_FetchInt( hQuery, field );
	}
	
	Format( Buffer, sizeof( Buffer ), "SELECT time, style, run FROM '%s' WHERE steamid = '%s' ORDER BY run;", CurrentMap, SteamID );
	SQL_TQuery( Database, Threaded_RetrieveClientTimes, Buffer, GetClientUserId( client ) );
}

public Threaded_RetrieveClientTimes( Handle:hDatabase, Handle:hQuery, const String:error[], any:data )
{
	if ( hQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't retrieve player data!\n Error: %s", CONSOLE_PREFIX, Error );
		
		return;
	}

	new client;
	if ( ( client = GetClientOfUserId( data ) ) == 0 )
		return;
	
	if ( hQuery != INVALID_HANDLE )
	{
		new field, iStyle, iRun;
		while ( SQL_FetchRow( hQuery ) )
		{
			SQL_FieldNameToNum( hQuery, "run", field );
			iRun = SQL_FetchInt( hQuery, field );
			
			SQL_FieldNameToNum( hQuery, "style", field );
			iStyle = SQL_FetchInt( hQuery, field );
		
			SQL_FieldNameToNum( hQuery, "time", field );
			flClientBestTime[client][iRun][iStyle] = SQL_FetchFloat( hQuery, field );
		}
	}
	
	UpdateScoreboard( client );
}