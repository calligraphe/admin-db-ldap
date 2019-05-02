#!/usr/bin/perl -w
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

# declare global variables
my ($user, $nom_groupe);

# Get identifiant and nom_groupe
do {
   print " Entrez l'identifiant :  ";
   $user = <STDIN>;
} while ($user eq <>  );
chomp $user;

do {
   print " Entrez le nom_groupe :  ";
   $nom_groupe = <STDIN>;
} while ($nom_groupe eq <>  );
chomp $nom_groupe;

# ---------------------------------- SQL ----------------------------------- #

#MySQLdatabase configuration
my $dsn ="DBI:mysql:database=si;host=sql.imss.org";
my $username ="root";
my $password ='dbmaster'; 

#connection toMySQLdatabase
my %attr =(PrintError=>0,  #turn off error reporting via warn()
	RaiseError=>1);   #turn on error reporting viadie() 
my $dbh  =DBI->connect($dsn,$username,$password,\%attr);

# requests preparation
my $subquery = "(select id_groupe from groupes where nom_groupe = \"$nom_groupe\" limit 1)";
my $query = "delete from groupe_membres where identifiant=\"$user\" and id_groupe=$subquery";

my $sth = $dbh->prepare($query);

# request execution
$sth->execute(); 

#onestconnecté, $dbh est le HANDLE de la base de données 

#enfind'utilisation de la BD faire

$dbh->disconnect;


# ---------------------------------- LDAP ---------------------------------- #

my %params;
&init_config(\%params);

# ldap connection
my $ldap = connect_ldap($params{'ldap'});

my $CFGFILE = "sync.cfg";
my $cfg = Config::IniFiles->new( -file => $CFGFILE );
my $dn = ($cfg->val('ldap','groupsdn'));

# deleting member from a group
posixgroup_del_user($ldap, $dn, $nom_groupe, $user);

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

# deletes a member from a group
sub posixgroup_del_user {
  my ($ldap, $base, $group, $user) = @_;
  my @dels;
  my $is_member = is_posixgroup_member($ldap, $base, $group, $user);
 
  if ($is_member == 0 ) {
    return 0;
  }
  else {
    my $dn = "cn=$group,$base";
    push (@dels, 'memberUid' =>  $user);
    del_attr($ldap, $dn, @dels);
  }
  return 1;

}

