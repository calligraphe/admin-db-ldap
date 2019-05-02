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

# ------------------------------ SQL ----------------------------------------------------------- #
# Declaring global variables
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

#MySQLdatabase configuration
my $dsn ="DBI:mysql:database=si;host=sql.imss.org";
my $username ="root";
my $password ='dbmaster'; 

#connection toMySQLdatabase
my %attr =(PrintError=>0,  #turn off error reporting via warn()
	RaiseError=>1);   #turn on error reporting viadie() 
my $dbh  =DBI->connect($dsn,$username,$password,\%attr);

# verifier si $user est un utilisateur dans DB
my $query = "select * from utilisateurs"; 
my $sth = $dbh->prepare($query);
$sth->execute();
my $counter = 0;
while (my $row = $sth->fetchrow_hashref) {
        if ($row->{identifiant} eq $user) {
	   $counter += 1;
	}
}

if ($counter == 0) {
   print "$user n'est pas un utilisateur dans DB!\n";
   exit;
}

# verifier si $user est deja dans $nom_groupe de DB
my $subquery = "(select id_groupe from groupes where nom_groupe = \"$nom_groupe\" limit 1)";
$query = "select * from groupe_membres where identifiant=\"$user\" and id_groupe = $subquery";
$sth = $dbh->prepare($query);
$sth->execute();
while (my $row = $sth->fetchrow_hashref) {
        if ($row->{identifiant} eq $user) {
           print "$user est deja dans le $nom_groupe de SQL!\n";
           exit;
        }
}

# Ajout de membre
$query = "INSERT INTO groupe_membres(id_groupe,identifiant) VALUES($subquery,\"$user\")";
$sth = $dbh->prepare($query);
$sth->execute(); 
print "Ajoute SQL!\n";

#onestconnecté, $dbh est le HANDLE de la base de données 

#enfind'utilisation de la BD faire

$dbh->disconnect;

# ------------------------------ LDAP ---------------------------------------------------------- #

my %params;
&init_config(\%params);

# connection LDAP
my $ldap = connect_ldap($params{'ldap'});

my $CFGFILE = "sync.cfg";
my $cfg = Config::IniFiles->new( -file => $CFGFILE );
my $dn = ($cfg->val('ldap','groupsdn'));

# verifier si $user est un utilisateur existant
my @users = sort(get_users_list($ldap, 'ou=users,dc=imss,dc=org'));
$counter = 0;
if (scalar(@users) > 0) {
    foreach my $u (@users) {
       if ($u eq $user) {
	   $counter += 1;
       }
    }
}
if (!$counter) {
   print "$user n'est un utilisateur de la base LDAP!\n";
   exit;
}

print "\n";

# add a new member
posixgroup_add_user($ldap, $dn, $nom_groupe, $user);
print "Ajoute LDAP!\n";

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

