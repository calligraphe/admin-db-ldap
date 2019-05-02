#!/usr/bin/perl -w
# 
# Version 0.1 - 27/03/2017
#
use strict;
use warnings;
use Config::IniFiles;
use ldap_lib;
use POSIX qw(strftime);
use DBI();
use Digest::MD5 qw(md5);

my %params;
&init_config(\%params);

my $ldap = connect_ldap($params{'ldap'});
print "on test connecte a la base LDAP !\n";

# Declaration variables globales
my ($query,$sth,$res,$row,$user,$expire);
my ($lc);
my (@adds,@mods,@dels);
my (@SIusers,@LDAPusers);
my (%attrib);
my $today = strftime "%Y%m%d%H%M%S", localtime;
my $CFGFILE = "sync.cfg";

print "Date et Heure: $today\n";
print "Ajouter des Usetilisateurs: \n";

#-------Demande des informations ----�--# 
print " Tapez le identifiant :  ";
$user = <STDIN>;
while ($user eq <>  ){
print " Tapez le identifiant :   ";
$user = <STDIN>;
}
chomp $user;

print "Tapez le nom de l'utilisater :  ";
my $userLastName = <STDIN>;
while ($userLastName eq <>  ){
print " Tapez le nom de l'utilisater :  ";
$userLastName = <STDIN>;
}
chomp $userLastName;

print "Tapez le mot de passe :  ";
my $psw = <STDIN>;
while ($psw eq <>  ){
print " Tapez le mot de passe :  ";
$psw = <STDIN>;
}
chomp $psw;


print "Tapez le nom de login :  ";
my $login = <STDIN>;
while ($login eq <>  ){
print " Tapez le nom de login :  ";
$login = <STDIN>;
}
chomp $login;

print "Tapez le prenom :  ";
my $name = <STDIN>;
while ($name eq <>  ){
print " Tapez le prenom :  ";
$name = <STDIN>;
}
chomp $name;

print "Tapez le courriel electronique :  ";
my $mail = <STDIN>;
while ($mail eq <>  ){
print " Tapez le courriel electronique :  ";
$mail = <STDIN>;
}
chomp $mail;

print "\nTapez l'ID de l'utilisateur :  ";
my $uidNumber = <STDIN>;
chomp $uidNumber;

print "\nTapez l'ID du groupe :  ";
my $gidNumber = <STDIN>;
chomp $gidNumber;

print " \nTapez le nombre de ShadowExpire:  ";
my $shadowExpire = <STDIN>;
chomp $shadowExpire;


print " \nTapez la date d'expiration :  ";
my $dateEx = <STDIN>;
chomp $dateEx;
#----- creation de la table attrib ---#
$attrib{'cn'} = $userLastName; # name surname
$attrib{'sn'}= $login; # login
$attrib{'givenName'}=$name; # name
$attrib{'mail'}=$mail; # email
$attrib{'uidNumber'}=$uidNumber; # gid 
$attrib{'gidNumber'}=$gidNumber; # uid
$attrib{'homeDirectory'}='/home/$user'; # login
$attrib{'loginShell'}='/bin/bash'; 
$attrib{'userPassword'}='root'; # pass
$attrib{'shadowExpire'}=$shadowExpire;

#------appel a la fonction------# 
my $cfg = Config::IniFiles->new( -file => $CFGFILE );
#my $filter = ("uid=".$user);
#my $base = $cfg->val('ldap','usersdn'); 
#print "here";
#print exist_entry($ldap, $base, $filter);

add_user($ldap, $user, $cfg->val('ldap','usersdn'), %attrib);

#------SQL --------------------#

#MySQLdatabase configuration
my $dsn ="DBI:mysql:database=si;host=sql.imss.org";
my $username ="root";
my $password ='dbmaster';

#connection toMySQLdatabase
my %attr =(PrintError=>0,  #turn off error reporting via warn()
        RaiseError=>1);   #turn on error reporting viadie()
my $dbh  =DBI->connect($dsn,$username,$password,\%attr);


$query = "INSERT INTO utilisateurs(identifiant, nom,prenom,mot_passe,courriel,id_utilisateur,id_groupe,date_expiration) VALUES(?,?,?,?,?,?,?,?)" ;
#my $query2 = "INSERT INTO groupe_membres(id_groupe,identifiant) VALUES(?,?)";
$sth = $dbh->prepare($query);
#my $sth2 = $dbh->prepare($query2);


$sth->execute($user , $userLastName , $name , $psw , $mail , $uidNumber , $gidNumber , $dateEx );
#$sth2->execute("$ARGV[6]", "$ARGV[0]");
#onestconnecté, $dbh est le HANDLE de la base de données

#enfind'utilisation de la BD faire

$dbh->disconnect;


print "l'utilisateur $user a ete bien enregistre \n";

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

  #$$ref_config{'db'}{'database'}  = $cfg->val('db','database');
  #$$ref_config{'db'}{'server'}    = $cfg->val('db','server');
  #$$ref_config{'db'}{'user'}      = $cfg->val('db','user');    
  #$$ref_config{'db'}{'password'}  = $cfg->val('db','password');
}

sub sortlist {
  my @unsorted_list = @_;
  my @sorted_list = sort {
                           (split '\.', $a, 2)[1] cmp
                           (split '\.', $b, 2)[1]
                         } @unsorted_list;
  return(@sorted_list);
}

sub gen_password {
  my $clearPassword = shift;

  my $hashPassword = "{MD5}" . encode_base64( md5($clearPassword),'' );
  return($hashPassword);
}

sub calc_date {

  my $date = shift;

  my ($year,$month,$day) = split("-",$date);
  my $rec = {};
  $rec->{'date'} = $year.$month.$day."235959Z";
  chomp(my $timestamp = `date --date='$date 23:59:59' +%s`);
  $rec->{'shadow'} = ceil($timestamp/24/3600);
  return $rec;
}
