#!/usr/local/bin/php
<?php
//
// Author:	Jon Nistor <nistor@snickers.org>
// Purpose:	Return GEO Lat/Long coordinates for an address.
// 		Using Google Maps API / JSON responses
//
// Version:	0.01
//
// 0.01 2017-05-02	Initial
//


$o_debug	= FALSE;

if( (PHP_SAPI == 'cli') && (count($argc) == 0) ) _usage($argv[0]);

if( PHP_SAPI == 'cli' )
{
	$i		= 0;
	$address	= NULL;
	if( isset($argv[1]) )
	{
		foreach( $argv as $arg )
		{
			$i++;
			if( $i == 1 ) continue;
			$address = $address . " " . $arg;
		}
	} else {
		$address = 0;	
	}

} else {
	$address	= $_GET['address'];
	$address	= str_replace("/^ /","", $address);
}

if( empty($address) || is_null($address) || (strlen($address) < 2) )
{
	_usage($argv[0]);
}


// PROG: Process address.
echo "ADDR: $address\n";
$addrClean	= str_replace(' ','+',$address);
if( $o_debug ) echo " DBG: Address to post to GMAPS API: $addrClean\n";


$u_opts		= array('http' =>
			array('timeout' => 5)
		  );
$u_stream	= stream_context_create($u_opts);
$geocode	= @file_get_contents('http://maps.google.com/maps/api/geocode/json?address='.$addrClean.'&sensor=false',false,$u_stream);
if( empty($geocode) || ! isset($geocode) )
{
	echo "PULL: Failed to get GEO location, please try again.\n";
	exit;
}
if( $o_debug ) print_r($geocode);

$output		= json_decode($geocode);
$lat		= isset($output->results[0]->geometry->location->lat) ?
			$output->results[0]->geometry->location->lat : 0;
$long		= isset($output->results[0]->geometry->location->lng) ?
			$output->results[0]->geometry->location->lng : 0;

echo " Lat: $lat\n";
echo "Long: $long\n";

function _usage($script)
{
	echo "Usage: $script 'address, city, country'\n";
	exit(1);
}

?>
