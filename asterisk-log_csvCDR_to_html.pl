#!/usr/bin/perl -W
#
# Author:	Jon Nistor (nistor@snickers.org)
# Purpose:	Read in Master.csv from Asterisk's CDR records, output simple HTML.
#
#
# Version:	0.01
#  0.01	Initial Version
#
#

use strict;
use Getopt::Std;
my %opt;
getopts('dfvhm:s:u:',\%opt);

my $o_cdrcsv	= $opt{'c'} || "/var/log/asterisk/cdr-custom/Master.csv";
my $o_debug	= $opt{'d'} || 0;
my $o_help	= $opt{'h'} || 0;
my $o_maxrecord	= $opt{'m'} || 365;
my $o_server	= $opt{'s'} || 0;
my $o_user	= $opt{'u'} || 0;
my $o_writehtml	= $opt{'w'} || "cdr-records.html";
my $o_verbose	= $opt{'v'} || 0;

# PROG: Read in CDR records
#
open(INPUT, "<$o_cdrcsv") || die "Cannot open $o_cdrcsv: $!";
my $cdrLoop = 0;
my %cdrInfo;

while(my $CDR = <INPUT>)
{
	chomp($CDR);
	$cdrLoop++;
	#$CDR =~ s/\"//g;

	# PROG: Variables same as cdr_custom.conf
	#

	my($c_clid,$c_src,$c_dst,$c_dcontext,$c_channel,$c_dstchannel,
	   $c_lastapp,$c_lastdata,$c_start,$c_answer,$c_end,$c_duration,
	   $c_billsec,$c_disposition,$c_amaflags,$c_accountcode,
	   $c_uniqueid,$c_userfield) = split(/\",\"/, $CDR);

	# DEBUG:
	if( $o_debug )
	{
		print "===\n";
		print "        CLID: $c_clid\n";
		print "         SRC: $c_src\n";
		print "         DST: $c_dst\n";
		print "    DCONTEXT: $c_dcontext\n";
		print "     CHANNEL: $c_channel\n";
		print "  DSTCHANNEL: $c_dstchannel\n";
		print "     LASTAPP: $c_lastapp\n";
		print "    LASTDATA: $c_lastdata\n";
		print "       START: $c_start\n";
		print "      ANSWER: $c_answer\n";
		print "         END: $c_end\n";
		print "    DURATION: $c_duration\n";
		print "     BILLSEC: $c_billsec\n";
		print " DISPOSITION: $c_disposition\n";
		print "    AMAFLAGS: $c_amaflags\n";
		print " ACCOUNTCODE: $c_accountcode\n";
		print "    UNIQUEID: $c_uniqueid\n";
		print "   USERFIELD: $c_userfield\n";
	}

	# PROG: Build a hash
	$c_clid	=~ s/\"//g;
	$c_clid =~ s/<.*>//g;
	$cdrInfo{$cdrLoop}{'clid'}		= $c_clid;

	$cdrInfo{$cdrLoop}{'src'}		= $c_src;
	$cdrInfo{$cdrLoop}{'dst'}		= $c_dst;
	$cdrInfo{$cdrLoop}{'dcontext'}		= $c_dcontext;
	$cdrInfo{$cdrLoop}{'channel'}		= $c_channel;
	$cdrInfo{$cdrLoop}{'dstchannel'}	= $c_dstchannel;
	$cdrInfo{$cdrLoop}{'lastapp'}		= $c_lastapp;
	$cdrInfo{$cdrLoop}{'lastdata'}		= $c_lastdata;
	$cdrInfo{$cdrLoop}{'start'}		= $c_start;
	$cdrInfo{$cdrLoop}{'answer'}		= $c_answer;
	$cdrInfo{$cdrLoop}{'end'}		= $c_end;
	$cdrInfo{$cdrLoop}{'duration'}		= $c_duration;
	$cdrInfo{$cdrLoop}{'billsec'}		= $c_billsec;
	$cdrInfo{$cdrLoop}{'disposition'}	= $c_disposition;
	$cdrInfo{$cdrLoop}{'amaflags'}		= $c_amaflags;
	$cdrInfo{$cdrLoop}{'accountcode'}	= $c_accountcode;
	$cdrInfo{$cdrLoop}{'uniqueid'}		= $c_uniqueid;
	$cdrInfo{$cdrLoop}{'userfield'}		= $c_userfield;
}

# -------------------------------------------------------------
# PROG: Output the data
open(OUTPUT,">/tmp/$o_writehtml");
print OUTPUT <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/transitional.dtd">
<HEAD>
        <TITLE>Asterisk Phone logs</TITLE>
	<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
	<META HTTP-EQUIV="Refresh" CONTENT="600">
	<style type="text/css">
        <!--
        HTML,BODY,P
        {
                color:       #000000;
                padding:     6px 8px;
                font-size:   100%;
                font-family: "HelveticaNeue-Light", "Helvetica Neue Light",
                             "Helvetica Neue", Helvetica, Arial,
                             "Lucida Grande", sans-serif;
                background:  #668CAA;
        }
        P.center        {       text-align:     center;         }
        TABLE
        {
                width:          100%;
                border-collapse: collapse;
                font-size:      .875em;
        }
        TD
        {
                padding:        5px;
                outline:        0;
                border:         0;
                border-bottom:  1px solid #ddd;
                vertical-align: top;
                text-align:     left;
        }
        TR
        {
                outline:        0
                border:         0
        }
        TR.colour1      {       background-color: #CCCCCC;      }
        TR.colour2      {       background-color: #BABABA;      }
        TR:hover td{
                background:     #000000;
                background:     rgba(10,80,50,0.25);
        }

        -->
        </style>
</HEAD>
<BODY>
EOF

print OUTPUT "
	<Table>
	<TR>
	<td>ID</td>
	<td>START</td>
	<td>END</td>
	<td>DURATION</td>

	<td>CLID</td>
	<td>SRC (caller)</td>
	<td>DST (dialed)</td>
	<td>DCONTEXT</td>
	<td>LASTAPP</td>
	<td>DISPOSITION</td>
";


my $cdrDisplay = 0;
foreach my $cdr ( reverse sort { $a <=> $b } keys %{cdrInfo} )
{
	next if( $cdrDisplay > $o_maxrecord );
	$cdrDisplay++;
	my $bgcolor = ($cdr % 2) ? "colour1" : "colour2"; # Flip/flop BG.

	print OUTPUT "<tr class='$bgcolor'>";
	print OUTPUT "<td>$cdr</td>\n";
	print OUTPUT "<td>" . $cdrInfo{$cdr}{'start'} . "</td>";
	print OUTPUT "<td>" . $cdrInfo{$cdr}{'end'} . "</td>";
	print OUTPUT "<td>" . callDuration($cdrInfo{$cdr}{'duration'}) . "</td>";

	print OUTPUT "<td>" . $cdrInfo{$cdr}{'clid'} . "</td>";
	print OUTPUT "<td>" . convertNumber($cdrInfo{$cdr}{'src'})  . "</td>";
	print OUTPUT "<td>" . convertNumber($cdrInfo{$cdr}{'dst'})  . "</td>";
	print OUTPUT "<td>" . $cdrInfo{$cdr}{'dcontext'} . "</td>";
	print OUTPUT "<td>" . $cdrInfo{$cdr}{'lastapp'} . "</td>";
	print OUTPUT "<td>" . $cdrInfo{$cdr}{'disposition'} . "</td>";
	print OUTPUT "</tr>\n";
}

print OUTPUT "</table></body></html>";
close(OUTPUT);

# PROG: Subroutines to assist
sub callDuration {
	my $hours	= int($_[0]/3600);
	my $leftover	= $_[0] % 3600;
	my $mins	= int($leftover/60);
	my $secs	= int($leftover % 60);

	return sprintf ("%02d:%02d:%02d", $hours,$mins,$secs)
}

sub convertNumber {
	my $tel	= $_[0];

	if( ( $tel =~ /^-?\d+$/ ) && ( length($tel) == 10 ) )
	{
		return "(" . substr($tel, 0, 3) . ") " .
			substr($tel, 3, 3) . "-" . substr($tel, 6, 4);
	} elsif ( ( $tel =~ /^-?\d+$/ ) && ( length($tel) == 11 ) )
	{
		return "1 (" . substr($tel, 1, 3) . ") " .
			substr($tel, 4, 3) . "-" . substr($tel, 7, 4);
	}
	return $tel;
}

# EOF
#
