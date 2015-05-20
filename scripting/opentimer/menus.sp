public Action Command_ToggleHUD( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Menu mMenu = CreateMenu( Handler_Hud );
	SetMenuTitle( mMenu, "HUD Menu\n " );
	
#if !defined CSGO
	AddMenuItem( mMenu, "_", ( g_fClientHideFlags[client] & HIDEHUD_HUD )		? "HUD: OFF" : "HUD: ON" );
#endif

	AddMenuItem( mMenu, "_", ( g_fClientHideFlags[client] & HIDEHUD_VM )		? "Viewmodel: OFF" : "Viewmodel: ON" );
	AddMenuItem( mMenu, "_", ( g_fClientHideFlags[client] & HIDEHUD_PLAYERS )	? "Players: OFF" : "Players: ON" );
	AddMenuItem( mMenu, "_", ( g_fClientHideFlags[client] & HIDEHUD_BOTS )		? "Bots: OFF" : "Bots: ON" );
	AddMenuItem( mMenu, "_", ( g_fClientHideFlags[client] & HIDEHUD_TIMER )		? "Timer: OFF" : "Timer: ON" );
	
#if !defined CSGO
	AddMenuItem( mMenu, "_", ( g_fClientHideFlags[client] & HIDEHUD_SIDEINFO ) 	? "Sidebar: OFF" : "Sidebar: ON" );
#endif

#if defined CHAT
	AddMenuItem( mMenu, "_", ( g_fClientHideFlags[client] & HIDEHUD_CHAT )		? "Chat: OFF" : "Chat: ON" );
#endif
	
	//SetMenuExitButton( mMenu, true );
	DisplayMenu( mMenu, client, 8 );
	
	return Plugin_Handled;
}

public int Handler_Hud( Menu mMenu, MenuAction action, int client, int item )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 )
			{
				if ( g_fClientHideFlags[client] & HIDEHUD_HUD )
					SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
				else
					ClientCommand( client, "sm_hud" );
			}
			
			delete mMenu;
		}
		case MenuAction_Select :
		{
			char szItem[2];
			
			if ( !GetMenuItem( mMenu, item, szItem, sizeof( szItem ) ) || szItem[0] != '_' )
			{
				return 0;
			}
			
			// We selected an item!
			switch ( item )
			{
#if !defined CSGO
				case 0 :
				{
					if ( g_fClientHideFlags[client] & HIDEHUD_HUD )
					{
						g_fClientHideFlags[client] &= ~HIDEHUD_HUD;
						
						SetEntProp( client, Prop_Send, "m_iHideHUD", 0 );
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "Restored HUD." );
					}
					else
					{
						g_fClientHideFlags[client] |= HIDEHUD_HUD;
						
						SetEntProp( client, Prop_Send, "m_iHideHUD", HIDE_FLAGS );
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "Your HUD is now partially hidden! For no radar: \x03cl_radaralpha 0" );
					}
				}
#endif

#if !defined CSGO
				case 1 :
#else
				case 0 :
#endif
				{
					if ( g_fClientHideFlags[client] & HIDEHUD_VM )
					{
						g_fClientHideFlags[client] &= ~HIDEHUD_VM;
						
						SetEntProp( client, Prop_Send, "m_bDrawViewmodel", 1 );
					}
					else
					{
						g_fClientHideFlags[client] |= HIDEHUD_VM;
						
						SetEntProp( client, Prop_Send, "m_bDrawViewmodel", 0 );
					}
				}
#if !defined CSGO
				case 2 :
#else
				case 1 :
#endif
				{
					if ( g_fClientHideFlags[client] & HIDEHUD_PLAYERS )
					{
						g_fClientHideFlags[client] &= ~HIDEHUD_PLAYERS;
				
						PRINTCHAT( client, client, CHAT_PREFIX ... "All players show up again!" );
					}
					else
					{
						g_fClientHideFlags[client] |= HIDEHUD_PLAYERS;
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "All players are hidden!" );
					}
				}
#if !defined CSGO
				case 3 :
#else
				case 2 :
#endif
				{
					if ( g_fClientHideFlags[client] & HIDEHUD_BOTS )
					{
						g_fClientHideFlags[client] &= ~HIDEHUD_BOTS;
				
						PRINTCHAT( client, client, CHAT_PREFIX ... "Record bots show up again!" );
					}
					else
					{
						g_fClientHideFlags[client] |= HIDEHUD_BOTS;
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "Record bots are now hidden!" );
					}
				}
#if !defined CSGO
				case 4 :
#else
				case 3 :
#endif
				{
					if ( g_fClientHideFlags[client] & HIDEHUD_TIMER )
					{
						g_fClientHideFlags[client] &= ~HIDEHUD_TIMER;
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "Your timer is back!" );
					}
					else
					{
						g_fClientHideFlags[client] |= HIDEHUD_TIMER;
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "Your timer is now hidden!" );
					}
				}
#if !defined CSGO
				case 5 :
				{
					if ( g_fClientHideFlags[client] & HIDEHUD_SIDEINFO )
					{
						g_fClientHideFlags[client] &= ~HIDEHUD_SIDEINFO;
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "Sidebar enabled!" );
					}
					else
					{
						g_fClientHideFlags[client] |= HIDEHUD_SIDEINFO;
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "Sidebar is now hidden!" );
					}
				}
#endif // CSGO

#if defined CHAT

#if !defined CSGO
				case 6 :
#else // CSGO
				case 4 :
#endif // CSGO
				{
					if ( g_fClientHideFlags[client] & HIDEHUD_CHAT )
					{
						g_fClientHideFlags[client] &= ~HIDEHUD_CHAT;
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "Chat enabled!" );
					}
					else
					{
						g_fClientHideFlags[client] |= HIDEHUD_CHAT;
						
						PRINTCHAT( client, client, CHAT_PREFIX ... "Chat is now hidden!" );
					}
				}
#endif // CHAT
			}
			
			if ( !DB_SaveClientData( client ) )
				PRINTCHAT( client, client, CHAT_PREFIX ... "Couldn't save your settings!" );
		}
	}
	
	return 0;
}

#if defined VOTING
	public Action Command_VoteMap( int client, int args )
	{
		if ( client == INVALID_INDEX ) return Plugin_Handled;
		
		if ( g_hMapList == null )
		{
			PRINTCHAT( client, client, CHAT_PREFIX ... "Voting is currently disabled!" );
			return Plugin_Handled;
		}
		
		if ( !IsPlayerAlive( client ) )
		{
			PRINTCHAT( client, client, CHAT_PREFIX ... "You cannot participate in the vote if you're not doing anything, silly." );
			return Plugin_Handled;
		}
		
		
		int len = GetArraySize( g_hMapList );
		
		if ( len < 1 )
		{
			PRINTCHAT( client, client, CHAT_PREFIX ... "Voting is currently disabled!" );
			return Plugin_Handled;
		}
		
		
		SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
		Menu mMenu = CreateMenu( Handler_Vote );
		SetMenuTitle( mMenu, "Vote\n " );
		
		int iMap[MAX_MAP_NAME_LENGTH];
		char MapName[MAX_MAP_NAME_LENGTH];
		
		for ( int i; i < len; i++ )
		{
			GetArrayArray( g_hMapList, i, iMap, view_as<int>MapInfo );
			strcopy( MapName, sizeof( MapName ), iMap[MAP_NAME] );
			
			AddMenuItem( mMenu, "_", MapName );
		}
		
		//SetMenuExitButton( mMenu, true );
		DisplayMenu( mMenu, client, MENU_TIME_FOREVER );
		
		return Plugin_Handled;
	}

	public int Handler_Vote( Menu mMenu, MenuAction action, int client, int index )
	{
		switch ( action )
		{
			case MenuAction_End :
			{
				if ( client > 0 && g_fClientHideFlags[client] & HIDEHUD_HUD )
					SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
				
				delete mMenu;
			}
			case MenuAction_Select :
			{
				char szItem[2];
				
				if ( !GetMenuItem( mMenu, index, szItem, sizeof( szItem ) ) || szItem[0] != '_' )
				{
					return 0;
				}
				
				if ( g_iClientVote[client] == index ) return 0;

				
				int len = GetArraySize( g_hMapList );
				
				if ( index > len ) return 0;
				
				
				int iMap[MAX_MAP_NAME_LENGTH];
				char szMap[MAX_MAP_NAME_LENGTH];
				
				GetArrayArray( g_hMapList, index, iMap, view_as<int>MapInfo );
				
				strcopy( szMap, sizeof( szMap ), iMap[MAP_NAME] );
				
				if ( g_iClientVote[client] != -1 )
				{
					PRINTCHATALLV( client, false, CHAT_PREFIX ... "\x03%N"...CLR_TEXT..." changed their vote to \x03%s"...CLR_TEXT..."!", client, szMap );
				}
				else
				{
					PRINTCHATALLV( client, false, CHAT_PREFIX ... "\x03%N"...CLR_TEXT..." voted for \x03%s"...CLR_TEXT..."!", client, szMap );
				}
				
				g_iClientVote[client] = index;
				
				CalcVotes();
				//else PRINTCHAT( client, client, CHAT_PREFIX ... "Was unable to process your vote. Try again." );
			}
		}
		
		return 0;
	}
#endif

public Action Command_Style( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !IsPlayerAlive( client ) )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "You must be alive to change your style!" );
		return Plugin_Handled;
	}
	
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Menu mMenu = CreateMenu( Handler_Style );
	SetMenuTitle( mMenu, "Choose Style\n " );
	
	
	
	for ( int i; i < NUM_STYLES; i++ )
	{
		bool bAllowed = true;
		switch ( i )
		{
			case STYLE_SIDEWAYS :
			{
				if ( !GetConVarBool( g_ConVar_Allow_SW ) ) bAllowed = false;
			}
			case STYLE_W :
			{
				if ( !GetConVarBool( g_ConVar_Allow_W ) ) bAllowed = false;
			}
			case STYLE_REAL_HSW :
			{
				if ( !GetConVarBool( g_ConVar_Allow_RHSW ) ) bAllowed = false;
			}
			case STYLE_HSW :
			{
				if ( !GetConVarBool( g_ConVar_Allow_HSW ) ) bAllowed = false;
			}
			case STYLE_VEL :
			{
				char sz[8]; // "XXXXvel"
				FormatEx( sz, sizeof( sz ), "%.0fvel", g_flVelCap );
				
				if ( !GetConVarBool( g_ConVar_Allow_Vel ) || g_iClientStyle[client] == i )
				{
					AddMenuItem( mMenu, "_", sz, ITEMDRAW_DISABLED );
				}
				else AddMenuItem( mMenu, "_", sz );
				
				continue;
			}
		}
		
		if ( bAllowed && g_iClientStyle[client] != i )
		{
			AddMenuItem( mMenu, "_", g_szStyleName[NAME_LONG][i] );
		}
		else
		{
			AddMenuItem( mMenu, "_", g_szStyleName[NAME_LONG][i], ITEMDRAW_DISABLED );
		}
	}
	
	//SetMenuExitButton( mMenu, true );
	DisplayMenu( mMenu, client, 8 );
	
	return Plugin_Handled;
}

public int Handler_Style( Menu mMenu, MenuAction action, int client, int style )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_fClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			
			delete mMenu;
		}
		case MenuAction_Select :
		{
			char szItem[2];
			
			if ( !GetMenuItem( mMenu, style, szItem, sizeof( szItem ) ) || szItem[0] != '_' )
			{
				return 0;
			}
			
			if ( 0 > style >= NUM_STYLES ) return 0;
			
			SetPlayerStyle( client, style );
		}
	}
	
	return 0;
}

public Action Command_Practise_GotoPoint( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsClientPractising[client] )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "You have to be in practice mode! (\x03!prac"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "You must be alive to use this command!" );
		return Plugin_Handled;
	}
	
	// Do we even have a checkpoint?
	if ( g_iClientCurSave[client] == INVALID_CP || g_flClientSaveDif[client][ g_iClientCurSave[client] ] == TIME_INVALID )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "You must save a location first! (\x03!save"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	
	// Format: sm_cp 1-9000, etc.
	if ( args > 0 )
	{
		char szArg[3]; // For double digits. (just in case some nutjob changes PRAC_MAX_SAVES. Including you. YES, YOU! I see you reading this...)
		GetCmdArgString( szArg, sizeof( szArg ) );
		
		int index = StringToInt( szArg );
		index--;
		
		if ( 0 > index >= PRAC_MAX_SAVES )
		{
			PRINTCHATV( client, client, CHAT_PREFIX ... "Invalid argument! (1-%i)", PRAC_MAX_SAVES - 1 );
			return Plugin_Handled;
		}
		
		
		index = g_iClientCurSave[client] - index;
		
		if ( index < 0 ) index = PRAC_MAX_SAVES + index;
		
		if ( ( 0 > index >= PRAC_MAX_SAVES ) || g_flClientSaveDif[client][index] == TIME_INVALID )
		{
			PRINTCHAT( client, client, CHAT_PREFIX ... "You don't have a checkpoint there!" );
			return Plugin_Handled;
		}
		
		
		// Valid checkpoint!
		g_flClientStartTime[client] = GetEngineTime() - g_flClientSaveDif[client][index];
		
		TeleportEntity( client, g_vecClientSavePos[client][index], g_vecClientSaveAng[client][index], g_vecClientSaveVel[client][index] );
		
		return Plugin_Handled;
	}
	
	
	// Yes we do!
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Menu mMenu = CreateMenu( Handler_Check );
	SetMenuTitle( mMenu, "Checkpoints\n " );
	
	AddMenuItem( mMenu, "_", "Last CP" );
	
	char	szSlot[7]; // "#XX CP"
	int		iSlot = 2;
	int		index = g_iClientCurSave[client] - 1;
	
	// Now, do we have more than the last cp?
	while ( index != g_iClientCurSave[client] )
	{
		if ( index < 0 ) index = PRAC_MAX_SAVES - 1;
		
		if ( g_flClientSaveDif[client][index] == TIME_INVALID ) break;
		
		
		// Add it to the menu!
		FormatEx( szSlot, sizeof( szSlot ), "#%i CP", iSlot );
		
		AddMenuItem( mMenu, "_", szSlot );
		
		index--;
		iSlot++;
	}
	
	DisplayMenu( mMenu, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_Check( Menu mMenu, MenuAction action, int client, int item )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_fClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			
			delete mMenu;
		}
		case MenuAction_Select :
		{
			char szItem[2];
			
			if ( !GetMenuItem( mMenu, item, szItem, sizeof( szItem ) ) || szItem[0] != '_' )
			{
				return 0;
			}
			
			int index = g_iClientCurSave[client] - item;
			
			if ( index < 0 ) index = PRAC_MAX_SAVES + index;
			
			
			// Just to be on the safe side...
			if ( 0 > index >= PRAC_MAX_SAVES ) return 0;
			if ( g_flClientSaveDif[client][index] == TIME_INVALID ) return 0;
			
			
			g_flClientStartTime[client] = GetEngineTime() - g_flClientSaveDif[client][index];
			
			TeleportEntity( client, g_vecClientSavePos[client][index], g_vecClientSaveAng[client][index], g_vecClientSaveVel[client][index] );
			
			// Re-open mMenu.
			ClientCommand( client, "sm_cp" );
		}
	}
	
	return 0;
}

public Action Command_Credits( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Menu mMenu = CreateMenu( Handler_Check );
	SetMenuTitle( mMenu, "Credits\n " );
	
	AddMenuItem( mMenu, "_", "Mehis - Original author\n ", ITEMDRAW_DISABLED );
	
	AddMenuItem( mMenu, "_", "Thanks to: ", ITEMDRAW_DISABLED );
	AddMenuItem( mMenu, "_", "Peace-Maker - For making botmimic. Learned a lot.", ITEMDRAW_DISABLED );
	AddMenuItem( mMenu, "_", "george. - For the recording tip.", ITEMDRAW_DISABLED );
	
	DisplayMenu( mMenu, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

// Used for multiply menus.
public int Handler_Empty( Menu mMenu, MenuAction action, int client, int item )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_fClientHideFlags[client] & HIDEHUD_HUD )
			{
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			}
			
			delete mMenu;
		}
	}
	
	return 0;
}