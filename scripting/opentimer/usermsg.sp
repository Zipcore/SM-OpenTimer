static char g_szBuffer[256];

stock void PrintColorChat( int target, int author, const char[] szMsg, any ... )
{
	VFormat( g_szBuffer, sizeof( g_szBuffer ), szMsg, 4 );
	
	SendColorMessage( target, author, g_szBuffer );
}

stock void PrintColorChatAll( int author, bool bAllowHide, const char[] szMsg, any ... )
{
	VFormat( g_szBuffer, sizeof( g_szBuffer ), szMsg, 4 );
	
	if ( bAllowHide )
	{
		for ( int client = 1; client <= MaxClients; client++ )
			if ( IsClientInGame( client ) && !( g_iClientHideFlags[client] & HIDEHUD_CHAT ) )
				SendColorMessage( client, author, g_szBuffer );
	}
	else
	{
		for ( int client = 1; client <= MaxClients; client++ )
			if ( IsClientInGame( client ) )
				SendColorMessage( client, author, g_szBuffer );
	}
}

static void SendColorMessage( int target, int author, const char szMsg[256] )
{
	// If we don't use the reliable channel, sometimes clients won't receive the message (?).
	// Happens more than you'd normally think.
	Handle hMsg = StartMessageOne( "SayText2", target, USERMSG_RELIABLE );
	
	if ( hMsg != null )
	{
		BfWriteByte( hMsg, author );
		
		// false for no console print. We do this manually because it would display the hex codes in the console.
		BfWriteByte( hMsg, false );
		
		BfWriteString( hMsg, szMsg );
		
		EndMessage();
	}
}

stock void ShowKeyHintText( int client, int target )
{
	Handle hMsg = StartMessageOne( "KeyHintText", client );
	
	if ( hMsg != null )
	{
		static char szTime[12];
		static char szText[92];
		
		if ( g_flClientBestTime[target][ g_iClientRun[target] ][ g_iClientStyle[target] ] != TIME_INVALID )
		{
			FormatSeconds( g_flClientBestTime[target][ g_iClientRun[target] ][ g_iClientStyle[target] ], szTime, sizeof( szTime ), true );
		}
		else Format( szTime, sizeof( szTime ), "N/A" );
		
		if ( g_iClientState[target] != STATE_START )
		{
			// Please, don't divide by zero :(
			if ( g_iClientSync_Max[target] < 1 ) g_iClientSync_Max[target] = 1;
			
			
			// "Strafes: 90000\nTotal Sync: 100.0\nJumps: XXXX\n \nStyle: Real HSW\nPB: 00:00:00.00"
			Format( szText, sizeof( szText ), "Strafes: %i\nTotal Sync: %.1f\nJumps: %i\n \nStyle: %s\nPB: %s\n%s",
				g_iClientStrafeCount[target],
				( g_iClientSync[target] / float( g_iClientSync_Max[target] ) ) * 100.0, // Sync
				g_iClientJumpCount[target],
				g_szStyleName[NAME_LONG][ g_iClientStyle[target] ], // Show our style.
				szTime,
				( g_bIsClientPractising[target] ? "(Prac Mode)" : "" ) ); // Have a practice mode warning for players!
			
		}
		else
		{
			Format( szText, sizeof( szText ), "Style: %s\nPB: %s\n%s",
				g_szStyleName[NAME_LONG][ g_iClientStyle[target] ],
				szTime,
				( g_bIsClientPractising[target] ? "(Prac Mode)" : "" ) );
		}
		
		BfWriteByte( hMsg, 1 );
		BfWriteString( hMsg, szText );
		
		EndMessage();
	}
}