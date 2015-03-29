public Action Command_ToggleHUD( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Menu mMenu = CreateMenu( Handler_Hud );
	SetMenuTitle( mMenu, "HUD Menu\n " );

	
	AddMenuItem( mMenu, "_", ( g_iClientHideFlags[client] & HIDEHUD_HUD )		? "HUD: OFF" : "HUD: ON" );
	AddMenuItem( mMenu, "_", ( g_iClientHideFlags[client] & HIDEHUD_VM )			? "Viewmodel: OFF" : "Viewmodel: ON" );
	AddMenuItem( mMenu, "_", ( g_iClientHideFlags[client] & HIDEHUD_PLAYERS )	? "Players: OFF" : "Players: ON" );
	AddMenuItem( mMenu, "_", ( g_iClientHideFlags[client] & HIDEHUD_TIMER )		? "Timer: OFF" : "Timer: ON" );
	AddMenuItem( mMenu, "_", ( g_iClientHideFlags[client] & HIDEHUD_SIDEINFO ) 	? "Sidebar: OFF" : "Sidebar: ON" );
	
#if defined CHAT
	AddMenuItem( mMenu, "_", ( g_iClientHideFlags[client] & HIDEHUD_CHAT )		? "Chat: OFF" : "Chat: ON" );
#endif
	
	
	SetMenuExitButton( mMenu, true );
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
				if ( g_iClientHideFlags[client] & HIDEHUD_HUD )
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
				case 0 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_HUD )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_HUD;
						
						SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
						
						PrintColorChat( client, client, "%s Restored HUD. (cl_radaralpha 200)", CHAT_PREFIX );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_HUD;
						
						SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
						ClientCommand( client, "cl_radaralpha 0" );
						
						PrintColorChat( client, client, "%s Your HUD is now partially hidden. (cl_radaralpha 0)", CHAT_PREFIX );
					}
				}
				case 1 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_VM )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_VM;
						
						SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 1 );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_VM;
						
						SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 0 );
					}
				}
				case 2 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_PLAYERS )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_PLAYERS;
						
						SDKUnhook( client, SDKHook_SetTransmit, Event_ClientTransmit );
				
						PrintColorChat( client, client, "%s All players show up again!", CHAT_PREFIX );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_PLAYERS;
						
						SDKHook( client, SDKHook_SetTransmit, Event_ClientTransmit );
						
						PrintColorChat( client, client, "%s All players are hidden!", CHAT_PREFIX );
					}
				}
				case 3 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_TIMER )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_TIMER;
						
						if ( !( g_iClientHideFlags[client] & HIDEHUD_TIMER ) && !( g_iClientHideFlags[client] & HIDEHUD_SIDEINFO ) )
							CreateTimer( TIMER_UPDATE_INTERVAL, Timer_ShowClientInfo, client, TIMER_REPEAT );
						
						PrintColorChat( client, client, "%s Your timer is back!", CHAT_PREFIX );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_TIMER;
						
						PrintColorChat( client, client, "%s Your timer is now hidden!", CHAT_PREFIX );
					}
				}
				case 4 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_SIDEINFO )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_SIDEINFO;
						
						PrintColorChat( client, client, "%s Sidebar enabled!", CHAT_PREFIX );
						
						if ( !( g_iClientHideFlags[client] & HIDEHUD_TIMER ) && !( g_iClientHideFlags[client] & HIDEHUD_SIDEINFO ) )
							CreateTimer( TIMER_UPDATE_INTERVAL, Timer_ShowClientInfo, client, TIMER_REPEAT );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_SIDEINFO;
						
						PrintColorChat( client, client, "%s Sidebar is now hidden!", CHAT_PREFIX );
					}
				}
#if defined CHAT
				case 5 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_CHAT )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_CHAT;
						
						PrintColorChat( client, client, "%s Chat enabled!", CHAT_PREFIX );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_CHAT;
						
						PrintColorChat( client, client, "%s Chat is now hidden!", CHAT_PREFIX );
					}
				}
#endif
			}
			
			if ( !SaveClientInfo( client ) )
				PrintColorChat( client, client, "%s Couldn't save your settings!", CHAT_PREFIX );
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
			PrintColorChat( client, client, "%s Voting is currently disabled!", CHAT_PREFIX );
			return Plugin_Handled;
		}
		
		if ( !IsPlayerAlive( client ) )
		{
			PrintColorChat( client, client, "%s You cannot participate in the vote if you're not doing anything, silly.", CHAT_PREFIX );
			return Plugin_Handled;
		}
		
		int len = GetArraySize( g_hMapList );
		
		if ( len < 1 )
		{
			PrintColorChat( client, client, "%s Voting is currently disabled!", CHAT_PREFIX );
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
		
		SetMenuExitButton( mMenu, true );
		
		DisplayMenu( mMenu, client, MENU_TIME_FOREVER );
		
		return Plugin_Handled;
	}

	public int Handler_Vote( Menu mMenu, MenuAction action, int client, int index )
	{
		switch ( action )
		{
			case MenuAction_End :
			{
				if ( client > 0 && g_iClientHideFlags[client] & HIDEHUD_HUD )
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
				char MapName[MAX_MAP_NAME_LENGTH];
				
				GetArrayArray( g_hMapList, index, iMap, view_as<int>MapInfo );
				
				strcopy( MapName, sizeof( MapName ), iMap[MAP_NAME] );
				
				if ( g_iClientVote[client] != -1 )
				{
					PrintColorChatAll( client, false, "%s \x03%N%s changed his/her vote to \x03%s%s!", CHAT_PREFIX, client, COLOR_TEXT, MapName, COLOR_TEXT );
				}
				else
				{
					PrintColorChatAll( client, false, "%s \x03%N%s voted for \x03%s%s!", CHAT_PREFIX, client, COLOR_TEXT, MapName, COLOR_TEXT );
				}
				
				g_iClientVote[client] = index;
				
				CalcVotes();
				//else PrintColorChat( client, client, "%s Was unable to process your vote. Try again.", CHAT_PREFIX );
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
		PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Menu mMenu = CreateMenu( Handler_Mode );
	SetMenuTitle( mMenu, "Choose Style\n " );
	
	
	for ( int i; i < MAX_STYLES; i++ )
	{
		if ( g_iClientStyle[client] != i )
		{
			AddMenuItem( mMenu, "_", g_szStyleName[NAME_LONG][i] );
		}
		else
		{
			AddMenuItem( mMenu, "_", g_szStyleName[NAME_LONG][i], ITEMDRAW_DISABLED );
		}
	}
	
	SetMenuExitButton( mMenu, true );
	DisplayMenu( mMenu, client, 8 );
	
	return Plugin_Handled;
}

public int Handler_Mode( Menu mMenu, MenuAction action, int client, int style )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_iClientHideFlags[client] & HIDEHUD_HUD )
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
			
			if ( style < 0 || style >= MAX_STYLES ) return 0;
			
			if ( IsPlayerAlive( client ) )
			{
				TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
				g_iClientStyle[client] = style;
				
				PrintColorChat( client, client, "%s Your style is now \x03%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][style], COLOR_TEXT );
			}
		}
	}
	
	return 0;
}

public Action Command_Practise_GotoPoint( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( !g_bIsClientPractising[client] )
	{
		PrintColorChat( client, client, "%s You have to be in practice mode! (\x03!prac%s)", CHAT_PREFIX, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You have to be alive to use this command!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	// Do we even have a checkpoint?
	if ( g_iClientCurSave[client] == INVALID_CP || g_flClientSaveDif[client][ g_iClientCurSave[client] ] == TIME_INVALID )
	{
		PrintColorChat( client, client, "%s You must save a location first! (\x03!save%s)", CHAT_PREFIX, COLOR_TEXT );
		return Plugin_Handled;
	}
	
	// Format: sm_cp 1-9000, etc.
	if ( args > 0 )
	{
		char szArg[3]; // For double digits.
		GetCmdArgString( szArg, sizeof( szArg ) );
		
		int index = StringToInt( szArg );
		index--;
		
		if ( index < 0 || index >= PRAC_MAX_SAVES )
		{
			PrintColorChat( client, client, "%s Invalid argument! (1-%i)", CHAT_PREFIX, PRAC_MAX_SAVES - 1 );
			return Plugin_Handled;
		}
		
		index = g_iClientCurSave[client] - index;
		
		if ( index < 0 ) index = PRAC_MAX_SAVES + index;
		
		if ( ( index < 0 || index >= PRAC_MAX_SAVES ) || g_flClientSaveDif[client][index] == TIME_INVALID )
		{
			PrintColorChat( client, client, "%s You don't have a checkpoint there!", CHAT_PREFIX );
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
		
		
		// Add that shit to the mMenu!
		Format( szSlot, sizeof( szSlot ), "#%i CP", iSlot );
		
		AddMenuItem( mMenu, "_", szSlot );
		
		index--;
		iSlot++;
	}
	
	
	SetMenuExitButton( mMenu, true );
	DisplayMenu( mMenu, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_Check( Menu mMenu, MenuAction action, int client, int item )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_iClientHideFlags[client] & HIDEHUD_HUD )
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
			if ( index < 0 || index >= PRAC_MAX_SAVES ) return 0;
			if ( g_flClientSaveDif[client][index] == TIME_INVALID ) return 0;
			
			
			g_flClientStartTime[client] = GetEngineTime() - g_flClientSaveDif[client][index];
			
			TeleportEntity( client, g_vecClientSavePos[client][index], g_vecClientSaveAng[client][index], g_vecClientSaveVel[client][index] );
			
			// Re-open mMenu.
			ClientCommand( client, "sm_cp" );
		}
	}
	
	return 0;
}