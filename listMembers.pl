#!/usr/bin/perl
use strict;
use DBI();

use Config::IniFiles;
use ldap_lib;
use List::Compare;
use POSIX qw(strftime);
use IO::File;
use Digest::MD5 qw(md5);
use MIME::Base64 qw(encode_base64);
use Getopt::Long;

my $nom_groupe;

# Get group name
do {
   print " Entrez le nom de groupe :  ";
   $nom_groupe = <STDIN>;
} while ($nom_groupe eq <>  );
chomp $nom_groupe;

#------------------- SQL ----------------------------------------------------------------------
#MySQLdatabase configuration
my $dsn ="DBI:mysql:database=si;host=sql.imss.org";
my $username ="root";
my $password ='dbmaster'; 

#connection toMySQLdatabase
my %attr =(PrintError=>0,  #turn off error reporting via warn()
	RaiseError=>1);   #turn on error reporting viadie() 
my $dbh  =DBI->connect($dsn,$username,$password,\%attr);

# request preparation
my $subquery = "(select id_groupe from groupes where nom_groupe = \"$nom_groupe\" limit 1)";
my $query = "select identifiant from groupe_membres where id_groupe = $subquery" ; 
my $sth = $dbh->prepare($query);

$sth->execute or die "SQL Error: $DBI::errstr\n";

print "\n  Membres de $nom_groupe presents dans la base de donnees:\n";
# request output
while (my $row = $sth->fetchrow_hashref) {
	printf "%s\n", $row->{identifiant};
}
print "\n";
#onestconnecté, $dbh est le HANDLE de la base de données 
#enfind'utilisation de la BD faire

$dbh->disconnect;

#------------------- LDAP ----------------------------------------------------------------------

my %params;
&init_config(\%params);

# connection to LDAP
my $ldap = connect_ldap($params{'ldap'});

my $CFGFILE = "sync.cfg";
my $cfg = Config::IniFiles->new( -file => $CFGFILE );
my $dn = ($cfg->val('ldap','groupsdn'));

# get get members of a given group name
my @members = get_posixgroup_members($ldap, $dn, $nom_groupe);

print "  Membres de $nom_groupe presents dans LDAP:\n";

# result output
if (scalar(@members) > 0) {
    foreach my $m (@members) {
       print "$m\n";
    }
}
print "\n";

$ldap->unbind;

#-----------------------------------------------------------------------
# fonctions
#-----------------------------------------------------------------------
sub init_config {
  (my $ref_config) = @_;

  $$ref_config{'ldap'}{'server'}  = 'ldap1.imss.org';
  $$ref_config{'ldap'}{'version'} = '3';
  $$ref_config{'ldap'}{'port'}    = '389';
  $$ref_config{'ldap'}{'binddn'}  = 'cn=admin,dc=imss,dc=org';
  $$ref_config{'ldap'}{'passdn'}  = 'secret';
}
