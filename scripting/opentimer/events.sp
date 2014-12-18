// Hide other players ( doesn't work with bots? )
public Action:Event_ClientTransmit( ent, client )
{
	if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
	
	return ( client != ent ) ? Plugin_Handled : Plugin_Continue;
}
// Hide player name changes. Doesn't work.
/*public Action:Event_ClientName( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
	dontBroadcast = true;
	SetEventBroadcast( hEvent, true );
	
	return Plugin_Handled;
}*/
/*public Event_ClientChangeTeam( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
	if ( GetEventBool( hEvent, "disconnect" ) ) return;
	
	if ( GetEventInt( hEvent, "team" ) > 1 )
	{
		new client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
		
		if ( !IsPlayerAlive( client ) )
			CreateTimer( 0.1, Timer_RespawnClient, GetClientUserId( client ) );
	}
}
public Action:Timer_RespawnClient( Handle:hTimer, any:client )
{
	if ( ( client = GetClientOfUserId( client ) ) > 0 )
		CS_RespawnPlayer( client );
}*/
// Set client ready for the map. Collision groups, bots, transparency, etc.
public Event_ClientSpawn( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
	
	if ( client < 1 || GetClientTeam( client ) < 2 ) return;
	
	if ( IsPlayerAlive( client ) )
	{
		if ( bIsLoaded[ iClientRun[client] ] )
			TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
	
		SetEntityRenderMode( client, RENDER_TRANSALPHA );
		SetEntityRenderColor( client, _, _, _, 64 );
		
		if ( !IsFakeClient( client ) )
			SetEntProp( client, Prop_Data, "m_CollisionGroup", 2 ); // Disable player collisions.
		else
			SetEntProp( client, Prop_Data, "m_CollisionGroup", 1 ); // No trigger collision for bots.
	}
	
	CreateTimer( 0.1, Timer_ClientSpawn, GetClientUserId( client ) );
}

// Continued from above event.
public Action:Timer_ClientSpawn( Handle:timer, any:client )
{
	if ( ( client = GetClientOfUserId( client ) ) < 1 ) return Plugin_Handled;
	
	// Hides deathnotices, health and weapon. Radar and crosshair stuff can be disabled client side. Disabling those won't allow you to switch between weapons.
	if ( iClientHideFlags[client] & HIDEHUD_HUD ) SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
	if ( iClientHideFlags[client] & HIDEHUD_VM ) SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 0 );
	
	if ( !IsPlayerAlive( client ) )
		return Plugin_Handled;
		
	SetEntProp( client, Prop_Data, "m_nHitboxSet", 2 ); // Don't get damaged from weapons.
	
	if ( IsFakeClient( client ) )
	{
#if defined RECORD
		SetEntityGravity( client, 0.0 );
		
		// Also, hide their guns so they are not just floating around
		new wep;
		for ( new i; i < 6; i++ )
			if ( ( wep = GetPlayerWeaponSlot( client, i ) ) > 0 )
				AcceptEntityInput( wep, "Kill" );
				//SetEntityRenderMode( wep, RENDER_NONE );
#endif

		return Plugin_Handled;
	}
	
	SetClientFOV( client, iClientFOV[client], false );
	
	return Plugin_Handled;
}
////////////
// EZHOP //
////////////
public Event_ClientJump( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
	if ( !bAutoHop ) return;
	
	SetEntPropFloat( GetClientOfUserId( GetEventInt( hEvent, "userid" ) ), Prop_Send, "m_flStamina", 0.0 );
}

public Event_ClientHurt( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
	
	if ( bAutoHop )
		SetEntPropFloat( client, Prop_Send, "m_flVelocityModifier", 1.0 );
		
	SetEntProp( client, Prop_Data, "m_iHealth", 100 );
}

public Event_ClientDeath( Handle:hEvent, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
	
	PrintColorChat( client, client, "%s Type !respawn to spawn again.", CHAT_PREFIX );
}
//////////
// CHAT //
//////////
#if defined CHAT
public Action:Listener_Say( client, const String:command[], argc )
{
	if ( client == 0 ) return Plugin_Continue;
	
	if ( IsClientInGame( client ) )
	{
		if ( BaseComm_IsClientGagged( client ) ) return Plugin_Handled;
		
		decl String:Arg[130]; // MAX MESSAGE LENGTH ( SayText ) + QUOTES
		GetCmdArgString( Arg, sizeof( Arg ) );
		
		if ( Arg[1] == '@' || Arg[1] == '/' || Arg[1] == '!' ) return Plugin_Handled;
		
		StripQuotes( Arg );
		
#if defined VOTING
		if ( StrEqual( Arg, "rtv" ) || StrEqual( Arg, "rockthevote" ) || StrEqual( Arg, "nominate" ) || StrEqual( Arg, "choosemap" ) )
		{
			ClientCommand( client, "sm_choosemap" );
			return Plugin_Handled;
		}
#endif
		
		if ( !IsPlayerAlive( client ) ) PrintColorChatAll( client, true, "%s[%sSPEC%s] \x03%N\x01: %s%s", COLOR_TEXT, COLOR_PURPLE, COLOR_TEXT, client, COLOR_TEXT, Arg );
		else PrintColorChatAll( client, true, "\x03%N\x01: %s%s", client, COLOR_TEXT, Arg );
		
		PrintToServer( "%N: %s", client, Arg );
		
		for ( new i = 1; i <= MaxClients; i++ )
			if ( IsClientInGame( i ) ) PrintToConsole( i, "%N: %s", client, Arg );
	}
	
	return Plugin_Handled;
}
#endif
//////////////////////////////////////
// AUTOBHOP, MODES, SYNC, RECORDING //
//////////////////////////////////////

#if defined RECORD
//static bool:bClientTeleported[MAXPLAYERS_BHOP];

public MRESReturn:Event_OnTeleport( client, Handle:hParams ) // This is called only on real players.
{
	if ( iClientState[client] == STATE_RUNNING && hClientRecording[client] != INVALID_HANDLE && !DHookIsNullParam( hParams, 1 ) )
	{
		decl Float:vecOrigin[3];
		DHookGetParamVector( hParams, 1, vecOrigin );
		
		new index = GetArraySize( hClientRecording[client] ) - 1;
		
		if ( index < 0 ) return MRES_Ignored;
		
		SetArrayCell( hClientRecording[client], index, FRAMEFLAG_TELEPORT, 12 );
		SetArrayCell( hClientRecording[client], index, vecOrigin[2], 11 );
		SetArrayCell( hClientRecording[client], index, vecOrigin[1], 10 );
		SetArrayCell( hClientRecording[client], index, vecOrigin[0], 9 );
	}
	
	return MRES_Ignored;
}
#endif

public Action:OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2] )
{
	if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
	
	new bool:bIsBot = true;
	if ( !IsFakeClient( client ) )
	{
		bIsBot = false;
		// MODES AND "ANTI-CHEAT"
		if ( iClientStyle[client] == STYLE_SIDEWAYS )
		{
			if ( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) CheckFreestyle( client );
		}
		else if ( iClientStyle[client] == STYLE_W )
		{
			if ( buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) CheckFreestyle( client );
		}
		else if ( iClientStyle[client] == STYLE_REAL_HSW )
		{
			// We have to have something pressed in order to get punish.
			if ( buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_FORWARD || buttons & IN_MOVERIGHT )
			{
				// Prevents people from holding left+forward+back
				// Allow them to hold all keys, tho
				if ( ( buttons & IN_BACK || buttons & IN_FORWARD ) && !( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) ) CheckFreestyle( client );
				// Not holding back+right and back+left
				// Not holding forward+right and forward+left
				else if ( 	( ( !( buttons & IN_BACK ) && !( buttons & IN_MOVERIGHT ) ) && ( !( buttons & IN_BACK ) && !( buttons & IN_MOVELEFT ) ) ) ||
							( ( !( buttons & IN_FORWARD ) && !( buttons & IN_MOVERIGHT ) ) && ( !( buttons & IN_FORWARD ) && !( buttons & IN_MOVELEFT ) ) ) )
					CheckFreestyle( client );
			}
						
		}
		else if ( iClientStyle[client] == STYLE_HSW )
		{
			if ( buttons & IN_BACK ) CheckFreestyle( client );
			else if ( buttons & IN_BACK || ( buttons & IN_FORWARD && !( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) ) )
				CheckFreestyle( client );
		}
		
		if ( !bForbiddenCommands )
		{
			if ( buttons & IN_LEFT ) ForcePlayerSuicide( client );
			if ( buttons & IN_RIGHT ) ForcePlayerSuicide( client );
		}
		
		if ( buttons & IN_RELOAD )
		{
			SetEntProp( client, Prop_Data, "m_iFOV", iClientFOV[client] );
			SetEntProp( client, Prop_Data, "m_iDefaultFOV", iClientFOV[client] );
		}
		
		// AUTOHOP
		if ( bAutoHop /*&& bClientAutoHop[client]*/ ) // Server setting && Client setting
		{
			new oldbuttons = GetEntProp( client, Prop_Data, "m_nOldButtons" );
			oldbuttons &= ~IN_JUMP;
			
			SetEntProp( client, Prop_Data, "m_nOldButtons", oldbuttons );
		}
		
		// We don't want ladders or water counted as jumpable space.
		if ( GetEntityMoveType( client ) != MOVETYPE_LADDER && GetEntProp( client, Prop_Data, "m_nWaterLevel" ) < 2 )
		{	
			new flags = GetEntityFlags( client );
			
			if ( buttons & IN_JUMP && flags & FL_ONGROUND )
				iClientJumpCount[client]++;
			
			// SYNC
			if ( iClientState[client] == STATE_RUNNING )
			{
				static Float:flClientLastVel[MAXPLAYERS_BHOP];
			
				if ( !( flags & FL_ONGROUND ) ) // Only calc sync in air. If we're not in air, we reset our last speed.
				{
					new Float:flCurVel = GetClientVelocity( client );
					
					if ( mouse[0] != 0 ) // We're moving our mouse, but are we gaining speed?
					{
						static iClientSync[MAXPLAYERS_BHOP];
						
						if ( flClientLastVel[client] < flCurVel )
							iClientGoodSync[client][ iClientSync[client] ] = 1;
						else
							iClientGoodSync[client][ iClientSync[client] ] = 0;
						
						iClientSync[client]++;
						
						flClientLastVel[client] = flCurVel;
						
						if ( iClientSync[client] >= SYNC_MAX_SAMPLES )
							iClientSync[client] = 0;
					}
					
					// If we haven't strafes to the left and mouse is going to the left, etc.
					if ( iClientLastStrafe[client] != STRAFE_LEFT && mouse[0] < 0/* && flCurVel >= flClientLastVel[client]*/ )
					{
						// Player is in 'perfect' left strafe.
						iClientLastStrafe[client] = STRAFE_LEFT;
						iClientStrafeCount[client]++;
					}
					else if ( iClientLastStrafe[client] != STRAFE_RIGHT && mouse[0] > 0/* && flCurVel >= flClientLastVel[client]*/  )
					{
						// Player is in 'perfect' right strafe.
						iClientLastStrafe[client] = STRAFE_RIGHT;
						iClientStrafeCount[client]++;
					}
					/*else if ( iClientLastStrafe[client] != STRAFE_RIGHT && mouse[0] > 0 && ( buttons & IN_MOVELEFT || !( buttons & IN_MOVERIGHT ) ) )
					{
						// Mouse going right but we're not holding right strafe key!
						iClientGoodSync[client][ iClientSync[client] ] = 0;
						iClientSync[client]++;
					}
					else if ( iClientLastStrafe[client] != STRAFE_LEFT && mouse[0] < 0 && ( buttons & IN_MOVERIGHT || !( buttons & IN_MOVELEFT ) ) )
					{
						// Mouse going left but we're not holding left strafe key!
						iClientGoodSync[client][ iClientSync[client] ] = 0;
						iClientSync[client]++;
					}*/
				}
				else if ( !( buttons & IN_JUMP ) )
					flClientLastVel[client] = 0.0;
			}
		}
	}
	
	// RECORDING
#if defined RECORD
	if ( hClientRecording[client] != INVALID_HANDLE && bIsClientRecording[client] && iClientState[client] == STATE_RUNNING )
	{
		new iFrame[FRAME_SIZE];
		
		// Remove distracting buttons.
		// Seriously, we don't even need them...
		// This also prevents the bot from constantly duckjumping.
		if ( buttons & IN_DUCK ) iFrame[FRAME_BUTTONS] = IN_DUCK;
		
		ArrayCopy( angles, iFrame[FRAME_ANGLES], 2 );
		ArrayCopy( vel, iFrame[FRAME_VELOCITY], 3 );
		
		decl Float:vecAbsVelocity[3];
		GetEntPropVector( client, Prop_Data, "m_vecAbsVelocity", vecAbsVelocity );
		iFrame[FRAME_ABSVELOCITY] = vecAbsVelocity;
		
		if ( iClientTick[client] % SNAPSHOT_INTERVAL == 0 || iClientTick[client] == 0 || GetEntityMoveType( client ) == MOVETYPE_LADDER )
		{
			decl Float:vecPos[3];
			GetClientAbsOrigin( client, vecPos );
			ArrayCopy( vecPos, iFrame[FRAME_POS], 3 );

			iFrame[FRAME_FLAGS] = FRAMEFLAG_SNAPSHOT;
		}
		
		iClientTick[client]++;
		
		PushArrayArray( hClientRecording[client], iFrame, _:FrameInfo );
	}
	else if ( bIsClientMimicing[client] )
	{
		new iFrame[FRAME_SIZE];
		GetArrayArray( hMimicRecording[ iClientRun[client] ][ iClientStyle[client] ], iClientTick[client], iFrame, _:FrameInfo );
		
		buttons = iFrame[FRAME_BUTTONS];
		
		ArrayCopy( iFrame[FRAME_ANGLES], angles, 2 );
		ArrayCopy( iFrame[FRAME_VELOCITY], vel, 3 );
		
		decl Float:vecAbsVelocity[3];
		ArrayCopy( iFrame[FRAME_ABSVELOCITY], vecAbsVelocity, 3 );
		
		if ( iFrame[FRAME_FLAGS] > 0 )
		{
			decl Float:vecPos[3];
			ArrayCopy( iFrame[FRAME_POS], vecPos, 3 );
			
			if ( iFrame[FRAME_FLAGS] == FRAMEFLAG_TELEPORT )
				TeleportEntity( client, vecPos, NULL_VECTOR, NULL_VECTOR );
			else
				SetEntPropVector( client, Prop_Send, "m_vecOrigin", vecPos );
				
		}
		
		TeleportEntity( client, NULL_VECTOR, angles, vecAbsVelocity );
		
		iClientTick[client]++;
		
		if ( iClientTick[client] >= iMimicTickMax[ iClientRun[client] ][ iClientStyle[client] ] )
		{
			bIsClientMimicing[client] = false;
			
			CreateTimer( 2.0, Timer_Rec_Restart, client );
			
			return Plugin_Handled;
		}
		
		return Plugin_Changed;
	}
	else if ( iClientTick[client] < 0 )
	{
		// -1 means that we are at the start of the run, about to begin our recorded run.
		// Kinda hacky, but works.
		ArrayCopy( angInitMimicAngles[ iClientRun[client] ][ iClientStyle[client] ], angles, 2 );
		vel = vecNull;
		
		TeleportEntity( client, vecInitMimicPos[ iClientRun[client] ][ iClientStyle[client] ], angInitMimicAngles[ iClientRun[client] ][ iClientStyle[client] ], vecNull );
		
		return Plugin_Changed;
	}
#endif
	
	// Freezes bots when they don't need to do anything.
	return bIsBot ? Plugin_Handled : Plugin_Continue;
}