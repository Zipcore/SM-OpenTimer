// Hide other players ( doesn't work with bots? )
public Action Event_ClientTransmit( int ent, int client )
{
	if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
	
	return ( client != ent ) ? Plugin_Handled : Plugin_Continue;
}

// Tell the client to respawn!
public Action Event_ClientDeath( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	int client;

	if ( ( client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) ) ) < 1 )
		return;
	
	PrintColorChat( client, client, "%s Type !respawn to spawn again.", CHAT_PREFIX );
}
// Hide player name changes. Doesn't work.
/*public Action Event_ClientName( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	bDontBroadcast = true;
	SetEventBroadcast( hEvent, true );
	
	return Plugin_Handled;
}*/

/*
public Action Event_ClientChangeTeam( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	if ( GetEventBool( hEvent, "disconnect" ) ) return;
	
	if ( GetEventInt( hEvent, "team" ) > 1 )
	{
		int client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
		
		if ( !IsPlayerAlive( client ) )
			CreateTimer( 0.1, Timer_RespawnClient, GetClientUserId( client ) );
	}
}

public Action Timer_RespawnClient( Handle hTimer, any client )
{
	if ( ( client = GetClientOfUserId( client ) ) > 0 )
		CS_RespawnPlayer( client );
}*/

// Set client ready for the map. Collision groups, bots, transparency, etc.
public Action Event_ClientSpawn( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	int client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
	
	if ( client < 1 || GetClientTeam( client ) < 2 || !IsPlayerAlive( client ) ) return;

	if ( g_bIsLoaded[ g_iClientRun[client] ] )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
	}
	
	if ( !IsFakeClient( client ) )
	{
		SetEntProp( client, Prop_Data, "m_CollisionGroup", 2 ); // Disable player collisions.
		
		SetEntityRenderMode( client, RENDER_TRANSALPHA );
		SetEntityRenderColor( client, _, _, _, 128 );
	}
	else
	{
		SetEntProp( client, Prop_Data, "m_CollisionGroup", 1 ); // Same + no trigger collision for bots.
		
		SetEntityRenderMode( client, RENDER_NONE );
	}
	
	CreateTimer( 0.1, Timer_ClientSpawn, GetClientUserId( client ) );
}

// Continued from above event.
public Action Timer_ClientSpawn( Handle hTimer, any client )
{
	if ( ( client = GetClientOfUserId( client ) ) < 1 ) return Plugin_Handled;
	
	// Hides deathnotices, health and weapon.
	// Radar and crosshair stuff can be disabled client side. Disabling those server-side won't allow you to switch between weapons.
	if ( g_iClientHideFlags[client] & HIDEHUD_HUD ) SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
	if ( g_iClientHideFlags[client] & HIDEHUD_VM ) SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 0 );
	
	SetEntProp( client, Prop_Data, "m_nHitboxSet", 2 ); // Don't get damaged from weapons.
	
	if ( IsFakeClient( client ) )
	{
#if defined RECORD
		SetEntityGravity( client, 0.0 );
		
		// Also, hide their guns so they are not just floating around
		int wep;
		for ( int i; i < 6; i++ )
			if ( ( wep = GetPlayerWeaponSlot( client, i ) ) > 0 )
				AcceptEntityInput( wep, "Kill" );
				//SetEntityRenderMode( wep, RENDER_NONE );
#endif

		return Plugin_Handled;
	}
	
	SetClientFOV( client, g_iClientFOV[client], false );
	
	return Plugin_Handled;
}
////////////
// EZHOP //
////////////
public Action Event_ClientJump( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	if ( !g_bEZHop ) return;
	
	SetEntPropFloat( GetClientOfUserId( GetEventInt( hEvent, "userid" ) ), Prop_Send, "m_flStamina", 0.0 );
}

public Action Event_ClientHurt( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	int client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
	
	if ( g_bEZHop )
	{
		SetEntPropFloat( client, Prop_Send, "m_flVelocityModifier", 1.0 );
	}
	
	SetEntProp( client, Prop_Data, "m_iHealth", 100 );
}
//////////
// CHAT //
//////////
#if defined CHAT
public Action Listener_Say( int client, const char[] command, int argc )
{
	// Let the server talk :^)
	if ( client == 0 ) return Plugin_Continue;
	
	if ( IsClientInGame( client ) )
	{
		if ( BaseComm_IsClientGagged( client ) ) return Plugin_Handled;
		
		static char szArg[130]; // MAX MESSAGE LENGTH ( SayText ) + QUOTES
		GetCmdArgString( szArg, sizeof( szArg ) );
		
		if ( szArg[1] == '@' || szArg[1] == '/' || szArg[1] == '!' ) return Plugin_Handled;
		
		StripQuotes( szArg );
		
#if defined VOTING
		if ( StrEqual( szArg, "rtv" ) || StrEqual( szArg, "rockthevote" ) || StrEqual( szArg, "nominate" ) || StrEqual( szArg, "choosemap" ) )
		{
			ClientCommand( client, "sm_choosemap" );
			return Plugin_Handled;
		}
#endif
		
		if ( !IsPlayerAlive( client ) ) PrintColorChatAll( client, true, "%s[%sSPEC%s] \x03%N\x01: %s%s", COLOR_TEXT, COLOR_PURPLE, COLOR_TEXT, client, COLOR_TEXT, szArg );
		else PrintColorChatAll( client, true, "\x03%N\x01: %s%s", client, COLOR_TEXT, szArg );
		
		PrintToServer( "%N: %s", client, szArg );
		
		for ( int i = 1; i <= MaxClients; i++ )
			if ( IsClientInGame( i ) ) PrintToConsole( i, "%N: %s", client, szArg );
	}
	
	return Plugin_Handled;
}
#endif
//////////////////////////////////////
// AUTOBHOP, MODES, SYNC, RECORDING //
//////////////////////////////////////
#if defined RECORD
// DHOOKS in action
// This is called only on real players.
public MRESReturn Event_OnTeleport( int client, Handle hParams )
{
/*
	Params:
	
	1 - New origin
	2 - New angles (as obj)
	3 - New velocity
	
	We don't need to record angles and velocity because we are doing it constantly in OnPlayerRunCmd...
*/
	
	if ( g_iClientState[client] == STATE_RUNNING && g_hClientRecording[client] != null && !DHookIsNullParam( hParams, 1 ) )
	{
		int index = GetArraySize( g_hClientRecording[client] ) - 1;
		
		if ( index < 0 ) return MRES_Ignored;
		
		float vecOrigin[3];
		DHookGetParamVector( hParams, 1, vecOrigin );
		
		SetArrayCell( g_hClientRecording[client], index, GetArrayCell( g_hClientRecording[client], index, 8, false ) | FRAMEFLAG_TELEPORT, 8 );
		SetArrayCell( g_hClientRecording[client], index, vecOrigin[2], 7 );
		SetArrayCell( g_hClientRecording[client], index, vecOrigin[1], 6 );
		SetArrayCell( g_hClientRecording[client], index, vecOrigin[0], 5 );
	}
	
	return MRES_Ignored;
}
#endif

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2] )
{
	if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
	
	if ( !IsFakeClient( client ) )
	{
		// MODES AND "ANTI-CHEAT"
		switch ( g_iClientStyle[client] )
		{
			case STYLE_SIDEWAYS :
			{
				if ( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT )
					CheckFreestyle( client );
			}
			case STYLE_W :
			{
				if ( buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT )
					CheckFreestyle( client );
			}
			case STYLE_REAL_HSW :
			{
				// We have to have something pressed in order to get punished.
				if ( buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_FORWARD || buttons & IN_MOVERIGHT )
				{
					// Prevents people from holding left+forward+back
					// Allow them to hold all keys, tho
					if ( ( buttons & IN_BACK || buttons & IN_FORWARD ) && !( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) )
					{
						CheckFreestyle( client );
					}
					
					// Not holding back+right and back+left
					// Not holding forward+right and forward+left
					else if ( 	( ( !( buttons & IN_BACK ) && !( buttons & IN_MOVERIGHT ) ) && ( !( buttons & IN_BACK ) && !( buttons & IN_MOVELEFT ) ) ) ||
								( ( !( buttons & IN_FORWARD ) && !( buttons & IN_MOVERIGHT ) ) && ( !( buttons & IN_FORWARD ) && !( buttons & IN_MOVELEFT ) ) ) )
					{
						CheckFreestyle( client );
					}
				}
			}
			case STYLE_HSW :
			{
				if ( buttons & IN_BACK )
					CheckFreestyle( client );
				else if ( buttons & IN_BACK || ( buttons & IN_FORWARD && !( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) ) )
					CheckFreestyle( client );
			}
		}
		
		if ( !g_bForbiddenCommands )
		{
			if ( buttons & IN_LEFT ) ForcePlayerSuicide( client );
			if ( buttons & IN_RIGHT ) ForcePlayerSuicide( client );
		}
		
		if ( buttons & IN_RELOAD )
		{
			SetEntProp( client, Prop_Data, "m_iFOV", g_iClientFOV[client] );
			SetEntProp( client, Prop_Data, "m_iDefaultFOV", g_iClientFOV[client] );
		}
		/////////////
		// AUTOHOP //
		/////////////
		if ( g_bAutoHop /*&& g_bClientAutoHop[client]*/ ) // Server setting && Client setting
		{
			int oldbuttons = GetEntProp( client, Prop_Data, "m_nOldButtons" );
			oldbuttons &= ~IN_JUMP;
			
			SetEntProp( client, Prop_Data, "m_nOldButtons", oldbuttons );
		}
		
		// We don't want ladders or water counted as jumpable space.
		if ( GetEntityMoveType( client ) != MOVETYPE_LADDER && GetEntProp( client, Prop_Data, "m_nWaterLevel" ) < 2 )
		{	
			int iFlags = GetEntityFlags( client );
			
			// JUMP COUNT
			if ( buttons & IN_JUMP && iFlags & FL_ONGROUND )
				g_iClientJumpCount[client]++;
			
			// SYNC
			if ( g_iClientState[client] == STATE_RUNNING )
			{
				static float flClientLastVel[MAXPLAYERS_BHOP];
			
				if ( !( iFlags & FL_ONGROUND ) ) // Only calc sync in air.
				{
					if ( mouse[0] != 0 ) // We're moving our mouse, but are we gaining speed?
					{
						static int iClientSync[MAXPLAYERS_BHOP];
						
						float flCurVel = GetClientVelocity( client );
						
						g_iClientGoodSync[client][ iClientSync[client] ] = ( flClientLastVel[client] < flCurVel ) ? 1 : 0;
						
						iClientSync[client]++;
						
						flClientLastVel[client] = flCurVel;
						
						// Reset sync index if done with current cycle.
						if ( iClientSync[client] >= SYNC_MAX_SAMPLES )
							iClientSync[client] = 0;
					}
					
					// If we haven't strafed to the left and mouse is going to the left, etc.
					if ( g_iClientLastStrafe[client] != STRAFE_LEFT && mouse[0] < 0/* && flCurVel >= flClientLastVel[client]*/ )
					{
						// Player is in 'perfect' left strafe.
						g_iClientLastStrafe[client] = STRAFE_LEFT;
						g_iClientStrafeCount[client]++;
					}
					else if ( g_iClientLastStrafe[client] != STRAFE_RIGHT && mouse[0] > 0/* && flCurVel >= flClientLastVel[client]*/  )
					{
						// Player is in 'perfect' right strafe.
						g_iClientLastStrafe[client] = STRAFE_RIGHT;
						g_iClientStrafeCount[client]++;
					}
					/*else if ( g_iClientLastStrafe[client] != STRAFE_RIGHT && mouse[0] > 0 && ( buttons & IN_MOVELEFT || !( buttons & IN_MOVERIGHT ) ) )
					{
						// Mouse going right but we're not holding right strafe key!
						g_iClientGoodSync[client][ iClientSync[client] ] = 0;
						iClientSync[client]++;
					}
					else if ( g_iClientLastStrafe[client] != STRAFE_LEFT && mouse[0] < 0 && ( buttons & IN_MOVERIGHT || !( buttons & IN_MOVELEFT ) ) )
					{
						// Mouse going left but we're not holding left strafe key!
						g_iClientGoodSync[client][ iClientSync[client] ] = 0;
						iClientSync[client]++;
					}*/
				}
				// If we're not in air, we reset our last speed.
				else// if ( !( buttons & IN_JUMP ) )
					flClientLastVel[client] = 0.0;
			}
		}
		
		///////////////
		// RECORDING //
		///////////////
#if defined RECORD
		if ( g_bIsClientRecording[client] && g_hClientRecording[client] != null && g_iClientState[client] == STATE_RUNNING )
		{
			int iFrame[FRAME_SIZE];
			
			// Remove distracting buttons.
			if ( buttons & IN_DUCK )
				iFrame[FRAME_FLAGS] = FRAMEFLAG_CROUCH;
			
			ArrayCopy( angles, iFrame[FRAME_ANGLES], 2 );
			
			// Get AbsVelocity instead of normal velocity.
			// AbsVelocity is basically normal velocity + external sources. (trigger_push/func_conveyor)
			// This makes sure that we don't fuck up.
			static float vecAbsVelocity[3];
			GetEntPropVector( client, Prop_Data, "m_vecAbsVelocity", vecAbsVelocity );
			
			ArrayCopy( vecAbsVelocity, iFrame[FRAME_ABSVELOCITY], 3 );
			
			// No more snapshots.
			static float vecPos[3];
			GetClientAbsOrigin( client, vecPos );
			ArrayCopy( vecPos, iFrame[FRAME_POS], 3 );
			
			// This is only required to check if player's recording is too long.
			g_iClientTick[client]++;
			
			PushArrayArray( g_hClientRecording[client], iFrame, view_as<int>FrameInfo );
		}
#endif
		return Plugin_Continue;
	}
	//////////////
	// PLAYBACK //
	//////////////
#if defined RECORD
	else if ( g_bIsClientMimicing[client] )
	{
		int iFrame[FRAME_SIZE];
		GetArrayArray( g_hMimicRecording[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_iClientTick[client], iFrame, view_as<int>FrameInfo );
		
		buttons = ( iFrame[FRAME_FLAGS] & FRAMEFLAG_CROUCH ) ? IN_DUCK : 0;
		
		vel = g_vecNull; // Stop it, bots! Do what we want you to do, instead of coming up with your own velocity! D:
		ArrayCopy( iFrame[FRAME_ANGLES], angles, 2 );
		
		static float vecPos[3];
		ArrayCopy( iFrame[FRAME_POS], vecPos, 3 );
		
		if ( iFrame[FRAME_FLAGS] & FRAMEFLAG_TELEPORT )
		{
			TeleportEntity( client, vecPos, NULL_VECTOR, NULL_VECTOR );
		}
		else
		{
			SetEntPropVector( client, Prop_Send, "m_vecOrigin", vecPos );
		}
		
		static float vecAbsVelocity[3];
		ArrayCopy( iFrame[FRAME_ABSVELOCITY], vecAbsVelocity, 3 );
		
		// In order to make the bot move properly, we need to change its angles and velocity externally.
		// Changing OnPlayerRunCmd() function's variables isn't enough.
		TeleportEntity( client, NULL_VECTOR, angles, vecAbsVelocity );
		
		g_iClientTick[client]++;
		
		// Are we done with our recording?
		if ( g_iClientTick[client] >= g_iMimicTickMax[ g_iClientRun[client] ][ g_iClientStyle[client] ] )
		{
			g_bIsClientMimicing[client] = false;
			
			CreateTimer( 2.0, Timer_Rec_Restart, client );
		}
		
		// Requires Plugin_Changed?
		return Plugin_Changed;
	}
	else if ( g_iClientTick[client] == TICK_PRE_PLAYBLACK )
	{
		// Means that we are at the start of the run, about to begin our recorded run.
		// Kinda hacky, but works.
		
		// Reset things, so the bot can't move.
		ArrayCopy( g_angInitMimicAngles[ g_iClientRun[client] ][ g_iClientStyle[client] ], angles, 2 );
		vel = g_vecNull;
		buttons = 0;
		
		TeleportEntity( client, g_vecInitMimicPos[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_angInitMimicAngles[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_vecNull );
		
		return Plugin_Changed;
	}
#endif
	
	// Freezes bots when they don't need to do anything.
	return Plugin_Handled;
}