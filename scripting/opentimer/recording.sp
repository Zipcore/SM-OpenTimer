public Action OnPlayerRunCmd(
	int client,
	int &buttons,
	int &impulse, // Not used
	float vel[3],
	float angles[3],
	int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed,  // Not used
	int mouse[2] )
{
	if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
	
	
	// Shared between recording and mimicing.
#if defined RECORD
	static int		iFrame[FRAME_SIZE];
	static float	vecPos[3];
#endif
	
	if ( !IsFakeClient( client ) )
	{
		// MODES
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
					else if ( 	( ( !( buttons & IN_BACK ) && !( buttons & IN_MOVERIGHT ) )
										&& ( !( buttons & IN_BACK ) && !( buttons & IN_MOVELEFT ) ) ) ||
								( ( !( buttons & IN_FORWARD ) && !( buttons & IN_MOVERIGHT ) )
										&& ( !( buttons & IN_FORWARD ) && !( buttons & IN_MOVELEFT ) ) ) )
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
		
		// "ANTI-CHEAT"
		if ( !g_bForbiddenCommands && ( buttons & IN_LEFT || buttons & IN_RIGHT ) )
		{
			if ( g_iClientState[client] == STATE_RUNNING )
			{
				TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
			}
			
			if ( g_flClientWarning[client] < GetEngineTime() )
			{
				PrintColorChat( client, client, "%s \x03+left%s and \x03+right%s are not allowed!", CHAT_PREFIX, COLOR_TEXT, COLOR_TEXT );
				
				g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
			}
			
			
			return Plugin_Handled;
		}
		
		
		// Reset field of view in case they reloaded their gun.
		if ( buttons & IN_RELOAD )
		{
			SetClientFOV( client, g_iClientFOV[client] );
		}
		
		int iFlags = GetEntityFlags( client );
		
		/////////////
		// AUTOHOP //
		/////////////
		if ( g_bAutoHop /*&& g_bClientAutoHop[client]*/ ) // Server setting && Client setting
		{
			int iOldButtons = GetEntProp( client, Prop_Data, "m_nOldButtons" );
			iOldButtons &= ~IN_JUMP;
			
			SetEntProp( client, Prop_Data, "m_nOldButtons", iOldButtons );
			
			// Anti-doublestepping
			if ( g_bClientHoldingJump[client] && iFlags & FL_ONGROUND ) buttons |= IN_JUMP;
		}
		
		// Jump count stat
		if ( iFlags & FL_ONGROUND && buttons & IN_JUMP )
			g_iClientJumpCount[client]++;
		
		
		// Rest what we do is done in running only.
		if ( g_iClientState[client] != STATE_RUNNING ) return Plugin_Continue;
		
		
		///////////////
		// RECORDING //
		///////////////
#if defined RECORD
		if ( g_bIsClientRecording[client] && g_hClientRecording[client] != null )
		{
			// Remove distracting buttons.
			iFrame[FRAME_FLAGS] = ( buttons & IN_DUCK ) ? FRAMEFLAG_CROUCH : 0;
			
			
			ArrayCopy( angles, iFrame[FRAME_ANGLES], 2 );
			
			GetEntPropVector( client, Prop_Data, "m_vecOrigin", vecPos );
			ArrayCopy( vecPos, iFrame[FRAME_POS], 3 );
			
			
			// This is only required to check if player's recording is too long.
			g_iClientTick[client]++;
			
			PushArrayArray( g_hClientRecording[client], iFrame, view_as<int>FrameInfo );
		}
#endif

		///////////
		// STATS //
		///////////
		// We don't want ladders or water counted as jumpable space.
		if ( GetEntityMoveType( client ) == MOVETYPE_LADDER || GetEntProp( client, Prop_Data, "m_nWaterLevel" ) > 1 )
			return Plugin_Continue;
		
		
		static float flClientLastVel[MAXPLAYERS_BHOP];
		
		// JUMP COUNT
		if ( iFlags & FL_ONGROUND && !( buttons & IN_JUMP ) )
		{
			// If we're on the ground and not jumping, we reset our last speed.
			flClientLastVel[client] = 0.0;
			
			return Plugin_Continue;
		}
		// SYNC AND STRAFE COUNT
		// Not on ground, moving mouse and we're pressing at least some key.
		else if ( mouse[0] != 0 && ( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT || buttons & IN_FORWARD || buttons & IN_BACK ) )
		{
			float flCurVel = GetClientVelocity( client );
			
			// We're moving our mouse, but are we gaining speed?
			if ( flCurVel > flClientLastVel[client] ) g_iClientSync[client]++;
			
			g_iClientSync_Max[client]++;
			
			flClientLastVel[client] = flCurVel;

			
			// If we haven't strafed to the left and mouse is going to the left, etc.
			if ( g_iClientLastStrafe[client] != STRAFE_LEFT && mouse[0] < 0 )
			{
				// Player is in 'perfect' left strafe.
				g_iClientLastStrafe[client] = STRAFE_LEFT;
				g_iClientStrafeCount[client]++;
			}
			else if ( g_iClientLastStrafe[client] != STRAFE_RIGHT && mouse[0] > 0 )
			{
				// Player is in 'perfect' right strafe.
				g_iClientLastStrafe[client] = STRAFE_RIGHT;
				g_iClientStrafeCount[client]++;
			}
		}


		return Plugin_Continue;
	}
	
	//////////////
	// PLAYBACK //
	//////////////
	
#if defined RECORD
	if ( g_bIsClientMimicing[client] )
	{
		GetArrayArray( g_hMimicRecording[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_iClientTick[client], iFrame, view_as<int>FrameInfo );
		
		// Take care of the buttons.
		buttons = ( iFrame[FRAME_FLAGS] & FRAMEFLAG_CROUCH ) ? IN_DUCK : 0;
		
		vel = g_vecNull;
		ArrayCopy( iFrame[FRAME_ANGLES], angles, 2 );
		
		
		ArrayCopy( iFrame[FRAME_POS], vecPos, 3 );
		
		static float vecPrevPos[3];
		GetEntPropVector( client, Prop_Data, "m_vecOrigin", vecPrevPos );
		
		
		// The problem with this system is that the spectator's view will be delayed and when the mimic gets teleported, the rest of the r.
		// Sure, it gets rid of DHOOKS, but I just don't like how the spectating works.
		
		if ( GetVectorDistance( vecPrevPos, vecPos, true ) > 370.0 )
		// Around the same distance as you can travel with 3500 speed in 1 tick.
		{
			//PrintToServer( "Teleporting the bot!" );
			TeleportEntity( client, vecPos, angles, NULL_VECTOR );
		}
		else
		{
			// Make the velocity!
			static float vecDirVel[3];
			vecDirVel[0] = vecPos[0] - vecPrevPos[0];
			vecDirVel[1] = vecPos[1] - vecPrevPos[1];
			vecDirVel[2] = vecPos[2] - vecPrevPos[2];
			
			ScaleVector( vecDirVel, 100.0 );
			
			TeleportEntity( client, NULL_VECTOR, angles, vecDirVel );
			
			// If server ops want more responsive but choppy view, here it is.
			if ( !g_bSmoothPlayback ) SetEntPropVector( client, Prop_Send, "m_vecOrigin", vecPos );
		}
		
		
		g_iClientTick[client]++;
		
		// Are we done with our recording?
		if ( g_iClientTick[client] >= g_iMimicTickMax[ g_iClientRun[client] ][ g_iClientStyle[client] ] )
		{
			g_bIsClientMimicing[client] = false;
			
			CreateTimer( 2.0, Timer_Rec_Restart, client, TIMER_FLAG_NO_MAPCHANGE );
		}
		
		return Plugin_Changed;
	}
	
	
	if ( g_iClientTick[client] == TICK_PRE_PLAYBLACK )
	{
		// Means that we are at the start of the run, about to begin our recorded run.
		// Kinda hacky, but works.
		
		// Reset things, so the bot can't move.
		ArrayCopy( g_angInitMimicAngles[ g_iClientRun[client] ][ g_iClientStyle[client] ], angles, 2 );
		vel = g_vecNull;
		
		SetEntProp( client, Prop_Data, "m_nButtons", 0 );
		buttons = 0;
		
		TeleportEntity( client, g_vecInitMimicPos[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_angInitMimicAngles[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_vecNull );
		
		return Plugin_Changed;
	}
#endif
	
	// Freezes bots when they don't need to do anything. I.e. at the end of the run.
	return Plugin_Handled;
}