#!/usr/bin/perl -W
#
# Author:	Jon Nistor (nistor@snickers.org)
# Purpose:	[Icinga2] Simple script to change entries in roles.ini files.
#
# Version:	0.03
#
# 0.01	2017-04-13	Initial build
# 0.02	2017-04-17	Added mysql support
# 0.03	2017-04-18	Added symlink support
#

use strict;
use Config::IniFiles;
use Getopt::Std;
use POSIX qw/strftime/;
use DBI;
my %opt;
getopts('a:d:f:hlm:p:x:z',\%opt);

my $o_custadd	= $opt{'a'} ?	$opt{'a'} : 0;		# cust: add cust
my $o_custdel	= $opt{'d'} ?	$opt{'d'} : 0;		# cust: del cust 
my $o_custmod	= $opt{'m'} ?	$opt{'m'} : 0;		# cust: mod cust pass
my $o_custlist	= $opt{'l'} ?	$opt{'l'} : 0;		# cust: list all /+ filter
my $o_custpass	= $opt{'p'} ?	$opt{'p'} : 0;		# cust: pass change

my $o_debug	= $opt{'z'} ?	$opt{'z'} : 0;		# Debug yes/no ?
my $o_file	= $opt{'f'} ?	$opt{'f'} : "/etc/icinga2/conf.d/roles.ini";# Filename to RW
my $o_filter	= $opt{'x'} ?	$opt{'x'} : 0;		# Filter specific name?
my $o_help	= $opt{'h'} ?	$opt{'h'} : 0;		# Enable usage?

my $date	= strftime('%Y-%m-%d %H:%M',localtime);
my $username	= $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);


my $ini_param_comment	= "comment"; # PARAM name
my $sql_ini		= "/etc/icingaweb2/resources.ini";
my $sql_info		= "icingaweb2_db";	# INI section within $sql_ini
my $sql_tbl		= "icingaweb_user";

sub usage()
{
	print "$0 [params]\n";
	print "\n";
	print " -a <cust>	add customer, need -p\n";
	print " -d <cust>	del customer\n";
	print " -f file.ini	read specific file.ini\n";
	print " -l		list all custs\n";
	print " -m <cust>	mod customer, need -p\n";
	print " -p <pass>	password entry\n";
	print " -x <cust>	filter based on <cust>\n";
	print " -z		enable debug\n";
	print "\n";
	exit;
}

sub sql_useradd
{
	# SQL: Add a user to the DB.
	my($dbh, $i_user, $i_pass) = @_;

	my $ssl_pass	= `/usr/bin/openssl passwd -1 $i_pass`;
	chomp($ssl_pass);

	my $sql		= "INSERT INTO $sql_tbl (name, active, password_hash)
				VALUES (?,1,?)";
	my $sth		= $dbh->prepare($sql);
	$sth->execute($i_user,$ssl_pass);

	if( $sth->rows )
	{
		$sth->finish;
		return 1;
	} else {
		$sth->finish;
		return 0;
	}
}

sub sql_userdel
{
	# SQL: Delete user from SQL table
	my( $dbh, $i_user )	= @_;

	my $sql	= "DELETE FROM $sql_tbl WHERE name = ?";
	my $sth	= $dbh->prepare($sql);
	$sth->execute($i_user);

	if( $sth->rows )
	{
		$sth->finish;
		return 1;
	} else {
		$sth->finish;
		return 0;
	}
}

sub sql_userexist
{
	# Let's check if the user exists.

	my($dbh, $i_user)	= @_;

	my $sql		= "SELECT name FROM $sql_tbl WHERE name = ?";
	my $sth		= $dbh->prepare($sql);
	$sth->execute($i_user);

	if( $sth->rows )
	{
		$sth->finish;
		return 1;
	} else {
		$sth->finish;
		return 0;
	}
}

sub sql_usermod
{
	# SQL: Modify the password for a user.
	my( $dbh, $i_user, $i_pass)	= @_;

	my $ssl_pass	= `/usr/bin/openssl passwd -1 $i_pass`;
	chomp($ssl_pass);

	my $sql	= "UPDATE $sql_tbl SET password_hash = ? WHERE name = ?";
	my $sth	= $dbh->prepare($sql);
	$sth->execute($ssl_pass,$i_user);

	if( $sth->rows )
	{
		$sth->finish;
		return 1;
	} else {
		$sth->finish;
		return 0;
	}
}


&usage if( $o_help );
if( ! $o_custadd && ! $o_custdel && ! $o_custmod && ! $o_custlist && ! $o_filter )
{
	&usage;
}

# -----------------------------------------------------------------------
# CHECK: Sanity checks

if( ( $o_custadd && $o_custdel ) || ( $o_custdel && $o_custmod ) ||
    ( $o_custadd && $o_custmod ) )
{
	print " ERR: Can only specify one action [add|del|mod]\n";
	exit(1);
}

# CHECK: Did we pass the -p option?
if( ( $o_custadd || $o_custmod ) && not $o_custpass )
{
	print " ERR: Need to specify the -p flag for password\n";
	exit (1);
}

# CHECK: Does the file exist? Symlink? Readable? Writeable?
if( -f $o_file  )
{
	my $o_filereal	= $o_file;

	if( -l $o_file )
	{
		$o_filereal	= readlink( $o_file );
		print "FILE: Symlink detected, real file: $o_filereal\n";
	}
		

	if( not -W $o_filereal )
	{
		print " ERR: Can't write to file: $o_filereal\n";
		print "       $!\n";
		exit(1);
	}

	# FILE: change location of the file in the variable
	$o_file	= $o_filereal;
}

# -----------------------------------------------------------------------
# SQL: Grab SQL info and connect to ensure it works
my $sql = Config::IniFiles->new(
		-commentchar	=> "#",
		-file		=> $sql_ini,
		-nocase		=> 0
	);
my $db_source	= $sql->val($sql_info,"db");
   $db_source	=~ s/\"//g;
my $db_user	= $sql->val($sql_info,"username");
   $db_user	=~ s/\"//g;
my $db_pass	= $sql->val($sql_info,"password");
   $db_pass	=~ s/\"//g;
my $db_name	= $sql->val($sql_info,"dbname");
   $db_name	=~ s/\"//g;
my $db_connect	= "dbi:$db_source:database=$db_name;host=localhost";

print " SQL: user/pass: $db_source:$db_user/$db_pass ($db_connect)\n" if( $o_debug );

our $dbh= DBI->connect($db_connect, $db_user, $db_pass,
		{	AutoCommit	=> 1,
			RaiseError	=> 1,
			PrintError	=> 1
		}) || die "Cannot connect to Database:$db_source\n";


# -----------------------------------------------------------------------
# INIFILE: Load the configuration and setup a hash
print " CFG: reading $o_file\n";

my $cfg_nocase	= 0;	# Set to 1 handle the config file in a case-insensitive manner.

my $cfg = Config::IniFiles->new(
		-commentchar	=> "#",
		-file		=> $o_file,
		-nocase		=> $cfg_nocase
	 );
# Duplicate into hash
tie my %ini, 'Config::IniFiles', (
		-commentchar	=> "#",
		-file		=> $o_file,
		-nocase		=> $cfg_nocase
	 );


if( $o_debug )
{
	use Data::Dumper;
	print Dumper(%ini);
}

# -----------------------------------------------------------------------
# INICFG: Are we adding a cust?
if( $o_custadd )
{
	# CHECK: Does the customer exist?
	if( $cfg->SectionExists( $o_custadd ) )
	{
		print " ERR: user $o_custadd already exists.\n";
		if( defined( $cfg->val($o_custadd, $ini_param_comment) ) )
		{
		    print "INFO: " . $cfg->val($o_custadd, $ini_param_comment) . "\n";
		}
		exit(1);
	}
	
	print " INI: Adding customer: $o_custadd\n";

	# NOTE: Can't use as part of if statement, doesn't return data.
	my $retval = $cfg->AddSection( $o_custadd );
	if( 1 )
	{
		# INI: copy template first.
		my $s_template		= "TEMPLATE";
		my $comment_date	= "\"Added on $date - $username\"";

		if( $cfg->SectionExists( $s_template ) )
		{
			my %ini_new	= %{$ini{$s_template}};
			print "  OK: copy from template\n";

			# LOOP: Cycle through parameters and swap %%USERS%%
			while( my($ini_param, $ini_value) = each %ini_new )
			{
				$ini_value =~ s/%%USER%%/$o_custadd/g;

				if( $cfg->newval( $o_custadd, $ini_param, $ini_value ) )
				{
					print " INI: set $ini_param -> $ini_value, OK.\n";
				}
			}
		} else {
			print " ERR: template section missing, quitting.\n";
			exit(1);
		}

		print " INI: OK added.\n";

		$cfg->newval( $o_custadd, $ini_param_comment, $comment_date );
		$cfg->WriteConfig( $o_file );

		# SQL: Time to add user to SQL.
		if( sql_userexist($dbh, $o_custadd ) )
		{
			print " ERR: Cannot add SQL entry, user $o_custadd already exists.\n";
			print " SQL: Forcing password change instead.\n";
			if( sql_usermod($dbh, $o_custadd, $o_custpass) )
			{
				print " SQL: password change OK\n";
			} else {
				print " ERR: error changing password.\n";
			}
		} else {

			if( sql_useradd($dbh, $o_custadd, $o_custpass) )
			{
				print " SQL: OK added.\n";
			} else {
				print " ERR: Cannot add user, unknown reason.\n";
				exit ;
			}
		} # END: if userexists
	} else {
		print " ERR: Can't add new section, quitting.\n";
		# exit(1);
	}

	exit;
}

# -----------------------------------------------------------------------
# INICFG: Are we deleting a cust?
if( $o_custdel )
{
	# CHECK: Does the customer exist?
	if( not $cfg->SectionExists( $o_custdel ) )
	{
		print " ERR: user $o_custdel doesn't exists.\n";
		exit(1);
	}

	# PROG: Delete entry entirely
	if( $cfg->DeleteSection( $o_custdel ) )
	{
		print " INI: delete customer $o_custdel, OK\n";
		$cfg->WriteConfig( $o_file );
	} else {
		print " ERR: Can't delete section, quitting.\n";
		exit(1);
	}

	# SQL: Time to clear DB entries
	if( sql_userdel($dbh, $o_custdel) )
	{
		print " SQL: removed row entries for $o_custdel\n";
	} else {
		print " ERR: Problem removing user from DB\n";
	}

	exit;
}

# -----------------------------------------------------------------------
# INICFG: Are we modifying anything?  Likely only the password
if( $o_custmod )
{
	# CHECK: Does the customer exist?
	if( not $cfg->SectionExists( $o_custmod ) )
	{
		print " ERR: user $o_custmod doesn't exists.\n";
		exit(1);
	}

	# PROG: Nothing in INI file to modify, only SQL.
	if( sql_userexist( $dbh, $o_custmod) )
	{
		if( sql_usermod($dbh, $o_custmod, $o_custpass) )
		{
			print " SQL: Modified password for $o_custmod\n";
		} else {
			print " ERR: cannot modify password for $o_custmod\n";
		}
	} else {
		print " ERR: User does not exist in SQL!!!!\n";
	}
	
	exit;
}


# ------------------------------------------------
# PROG: Display all top-level entries

if( $o_custlist || $o_filter )
{

    foreach my $i_section ( keys %ini )
    {
	my $loop_lvl1	= $ini{$i_section};

	# FILT: Do we filter and only display info for a specific entry?
	next if( $o_filter && ( $o_filter ne "$i_section" ) );
	

	#print "Key: $i_section\n";
	#print "Val: " . $ini{$i_section} . "\n";

	print "[$i_section]\n";

	foreach my $i_param ( keys %{$loop_lvl1} )
	{
		my $i_paramvalue = $cfg->val($i_section,$i_param);
		printf "\t%-30s = %s\n", $i_param, $i_paramvalue;
	} # END: foreach $i_param
    } # END: foreach $i_section
} # END: o_custlist


if( $dbh )
{
	# DB: Disconnect from the DB
	$dbh->disconnect();
}

# EOF
#
