#include common_scripts\utility;

main()
{
	replacefunc( maps\mp\gametypes\_rank::init, ::init_stub );
	replacefunc( maps\mp\gametypes\_rank::syncxpstat, ::syncxpstat_stub );

	replacefunc( common_scripts\utility::set_trigger_flag_permissions, ::set_trigger_flag_permissions_stub );
}

init_stub()
{
	level.scoreinfo = [];
	level.xpscale = getdvarint( "scr_xpscale" );

	level.xpscale = max( level.xpscale, 1 );
	level.teamxpscale["axis"] = 1;
	level.teamxpscale["allies"] = 1;
	level.ranktable = [];
	level.weaponranktable = [];
	level.maxrank = int( tablelookup( "mp/rankTable.csv", 0, "maxrank", 1 ) );
	level.maxprestige = int( tablelookup( "mp/rankTable.csv", 0, "maxprestige", 1 ) );
	level.maxforbotmatch = getdvarint( "max_xp_per_match", 0 );
	var_0 = 0;
	var_1 = 0;

	for ( var_0 = 0; var_0 <= min( 10, level.maxprestige ); var_0++ )
	{
		for ( var_1 = 0; var_1 <= level.maxrank; var_1++ )
			precacheshader( tablelookup( "mp/rankIconTable.csv", 0, var_1, var_0 + 1 ) );
	}

	var_2 = 0;

	for ( var_3 = tablelookup( "mp/rankTable.csv", 0, var_2, 1 ); isdefined( var_3 ) && var_3 != ""; var_3 = tablelookup( "mp/rankTable.csv", 0, var_2, 1 ) )
	{
		level.ranktable[var_2][1] = tablelookup( "mp/rankTable.csv", 0, var_2, 1 );
		level.ranktable[var_2][2] = tablelookup( "mp/rankTable.csv", 0, var_2, 2 );
		level.ranktable[var_2][3] = tablelookup( "mp/rankTable.csv", 0, var_2, 3 );
		level.ranktable[var_2][7] = tablelookup( "mp/rankTable.csv", 0, var_2, 7 );
		precachestring( tablelookupistring( "mp/rankTable.csv", 0, var_2, 16 ) );
		var_2++;
	}

	var_4 = int( tablelookup( "mp/weaponRankTable.csv", 0, "maxrank", 1 ) );

	for ( var_5 = 0; var_5 < var_4 + 1; var_5++ )
	{
		level.weaponranktable[var_5][1] = tablelookup( "mp/weaponRankTable.csv", 0, var_5, 1 );
		level.weaponranktable[var_5][2] = tablelookup( "mp/weaponRankTable.csv", 0, var_5, 2 );
		level.weaponranktable[var_5][3] = tablelookup( "mp/weaponRankTable.csv", 0, var_5, 3 );
	}

	maps\mp\gametypes\_missions::buildchallegeinfo();
	level thread maps\mp\gametypes\_rank::patientzerowaiter();
	level thread maps\mp\gametypes\_rank::onplayerconnect();
}

syncxpstat_stub()
{
	var_0 = maps\mp\gametypes\_rank::getrankxp();
	var_1 = self.pers["activeSquadMember"];

	/#
		// Attempt to catch xp regression
		old_xp = self getrankedplayerdata( "squadMembers", var_1, "squadMemXP" );
		assert( var_0 >= old_xp, "Attempted XP regression in syncXPStat - " + old_xp + " -> " + var_0 + " for player " + self.name );
	#/

	self setrankedplayerdata( "squadMembers", var_1, "squadMemXP", var_0 );
	self setrankedplayerdata( "experience", var_0 );

	if ( var_0 >= maps\mp\gametypes\_rank::getrankinfomaxxp( level.maxrank ) )
	{
		var_3 = self getrankedplayerdata( "characterXP", var_1 );

		if ( var_3 == 0 )
		{
			var_4 = getsystemtime();
			self setrankedplayerdata( "characterXP", var_1, var_4 );
			var_5 = self getrankedplayerdatareservedint( "prestigeLevel" );
			var_6 = var_5 + 1;
			self setrankedplayerdatareservedint( "prestigeLevel", var_6 );
			self setrank( level.maxrank, var_6 );
			thread maps\mp\gametypes\_hud_message::splashnotifyurgent( "prestige" + var_6 );
			var_7 = self.pers["team"];

			for ( var_8 = 0; var_8 < level.players.size; var_8++ )
			{
				var_9 = level.players[var_8];
				var_10 = var_9.pers["team"];

				if ( isdefined( var_10 ) && var_9 != self )
				{
					if ( var_10 == var_7 )
						var_9 iprintln( &"RANK_PLAYER_WAS_PROMOTED", self, &"MPUI_PRESTIGE" );
				}
			}
		}
	}
}

set_trigger_flag_permissions_stub( var_0 )
{
	if ( !isdefined( level.trigger_flags ) || !isdefined( level.trigger_flags[var_0] ) )
		return;

	level.trigger_flags[var_0] = array_removeundefined( level.trigger_flags[var_0] );
	array_thread( level.trigger_flags[var_0], ::update_trigger_based_on_flags );
}
