main()
{
	replacefunc( maps\mp\_utility::getlastlivingplayer, ::getlastlivingplayer_stub );
	replacefunc( maps\mp\gametypes\common_sd_sr::ononeleftevent, ::ononeleftevent_stub );

	// gitea#5 workaround
	replacefunc( maps\mp\gametypes\_killcam::killcamvalid, ::killcamvalid_stub );
}

getlastlivingplayer_stub( team )
{
	live_player = undefined;

	foreach ( player in level.players )
	{
		if ( isdefined( team ) && player.team != team )
			continue;

		if ( !maps\mp\_utility::isreallyalive( player ) && !player maps\mp\gametypes\_playerlogic::mayspawn() )
			continue;

		assertex( !isdefined( live_player ), "getLastLivingPlayer() found more than one live player on team." );

		live_player = player;				
	}

	return live_player;
}

ononeleftevent_stub( team )
{
	if ( level.bombexploded || level.bombdefused )
		return;

	last_player = maps\mp\_utility::getlastlivingplayer( team );

	if ( !isdefined( last_player ) )
		return;

	last_player thread maps\mp\gametypes\common_sd_sr::givelastonteamwarning();
}

killcamvalid_stub( victim, attacker, dokillcam )
{
	return dokillcam && level.killcam &&
		!( isdefined( victim.cancelkillcam ) && victim.cancelkillcam ) &&
		game[ "state" ] == "playing" && !victim maps\mp\_utility::isusingremote() &&
		!level.showingfinalkillcam &&
		!isai( victim ) && !isai( attacker );
}
