#!/usr/bin/perl -w
# 
# Version 0.1 - 27/03/2017
#
use strict;
use Config::IniFiles;
use ldap_lib;
use List::Compare;
use POSIX qw(strftime);
use IO::File;
use DBI();
use Digest::MD5 qw(md5);
use MIME::Base64 qw(encode_base64);
use Getopt::Long;

# declare global variables
my ($user, $nom_groupe, $gid, $description, @LDAPgid);

# Recuperation de gid et de nom_groupe
do {
   print " Entrez nom_groupe :  ";
   $nom_groupe = <STDIN>;
} while ($nom_groupe eq <>  );
chomp $nom_groupe;

do {
   print " Entrez gid :  ";
   $gid = <STDIN>;
} while ($gid eq <>  );
chomp $gid;

# ----------------------------------------- LDAP ---------------------------------------------- #

my %params;
&init_config(\%params);

# ldap connection
my $ldap = connect_ldap($params{'ldap'});

my $CFGFILE = "sync.cfg";
my $cfg = Config::IniFiles->new( -file => $CFGFILE );
my $dn = ($cfg->val('ldap','groupsdn'));

# recuperation de la liste des gid des utilisateurs LDAP
@LDAPgid = sort(get_gid_list($ldap,'ou=users,dc=imss,dc=org'));

# Verification si gid est le groupe primaire d'un utilisateur
if (scalar(@LDAPgid) > 0) {
  foreach my $u (@LDAPgid) {
     if ($u == $gid) {
        print "Ce gid est le groupe primaire d'un utilisateur!\n";
        exit;
     }
  }
}

# Recuperation de description de groupe a supprimer
do {
   print " Entrez description de groupe :  ";
   $description = <STDIN>;
}while ($description eq <>  );
chomp $description;

# creation des attributs de groupe
my %attr;
$attr{'cn'} = $nom_groupe;
$attr{'gidNumber'} = $gid;
$attr{'description'} = $description;
 
# verification si le groupe est vide
my @members = get_posixgroup_members($ldap,$dn,$nom_groupe);
if (scalar @members > 0){
	print "groupe LDAP n'est pas vide!\n";
	exit;
}

# Suppression d'un groupe
del_posixgroup($ldap, $dn, %attr);
print "groupe LDAP deleted\n";

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

# supprime le groupe donne
sub del_posixgroup {

  my ($ldap, $groupsdn, %attr) = @_;

  my $dn = "cn=".$attr{'cn'}.",$groupsdn";
  print $dn."\n" if $options{'verbose'};
  my $add = $ldap->delete (dn => $dn,
                              attr => [
                                     'objectclass' => ['top','posixGroup' ],
                                     'cn'   => $attr{'cn'},
                                     'gidNumber'   => $attr{'gidNumber'},
                                     'description'   => $attr{'description'}                                     
                                      ]
                       );
  $add->code && warn "failed to delete entry: ", $add->error ;
}

# retourne la liste des gid des utilisateurs
sub get_gid_list {
  my ($ldap, $base) = @_;

  my @members = ();
  my $uid;
  my $mesg = $ldap->search ( # perform a search
                             base   => $base,
                             filter => "(objectClass=posixAccount)",
                             attrs => ['gidNumber']
                           );
  $mesg->code && die $mesg->error;

  foreach my $entry ($mesg->all_entries) {
    foreach my $value ($entry->get_value("gidNumber")) {
      push @members,$value;
    }
  }
  return @members;
}

# --------------------------------------------------------------------------------------------- #
# ----------------------------------------- SQL ----------------------------------------------- #

#MySQLdatabase configuration
my $dsn ="DBI:mysql:database=si;host=sql.imss.org";
my $username ="root";
my $password ='dbmaster';

#connection toMySQLdatabase
%attr =(PrintError=>0,  #turn off error reporting via warn()
        RaiseError=>1);   #turn on error reporting viadie()
my $dbh  =DBI->connect($dsn,$username,$password,\%attr);

# verification si le groupe est vide
my $query = "select identifiant from groupe_membres where id_groupe = $gid";
my $sth = $dbh->prepare($query);
$sth->execute or die "SQL Error: $DBI::errstr\n";
while (my $row = $sth->fetchrow_hashref) {
   if ($row->{identifiant}) {
	print "Groupe SQL n'est pas vide!\n";
	exit;
   }
}

# suppression d'un groupe
my $query2 = "delete from groupes where id_groupe = $gid and nom_groupe = \"$nom_groupe\" and description = \"$description\"";
my $sth2 = $dbh->prepare($query2);
$sth2->execute or die "SQL Error: $DBI::errstr\n";
print "group SQL deleted!\n";
print "\n";
#onestconnecté, $dbh est le HANDLE de la base de données
#enfind'utilisation de la BD faire

$dbh->disconnect;

