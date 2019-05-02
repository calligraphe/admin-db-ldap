#!/usr/bin/perl -w
# 
# Version 0.1 - 27/03/2017
#
use strict;
use Config::IniFiles;
use ldap_lib;
use POSIX qw(strftime);
use DBI();
use Digest::MD5 qw(md5);

#-----Connection LDAP-----#
my %params;
&init_config(\%params);

my $ldap = connect_ldap($params{'ldap'});
print "on test connecte a la base LDAP !\n";

# Declaration variables globales
my ($query,$sth,$res,$row,$user,$expire);
my ($lc);
my (@adds,@mods,@dels);
my (@SIusers,@LDAPusers);
my (@mail);
my $today = strftime "%Y%m%d%H%M%S", localtime;

print "Supprimir un utilisateur\n";
print "Date et Heure: $today\n";
my $CFGFILE = "sync.cfg";
my $cfg = Config::IniFiles->new( -file => $CFGFILE );

#------Demande des valeurs------#
print "user:";
$user = <STDIN>;
while ($user eq <>){
print "user:";
$user = <STDIN>;
}
chomp $user;

#-----appel a la fonction Ldap----#
my $dn = ("uid=" . $user . "," . $cfg->val('ldap','usersdn'));
del_entry($ldap, $dn);

#----SQL---------#
#MySQLdatabase configuration
my $dsn ="DBI:mysql:database=si;host=sql.imss.org";
my $username ="root";
my $password ='dbmaster';

#connection toMySQLdatabase
my %attr =(PrintError=>0,  #turn off error reporting via warn()
        RaiseError=>1);   #turn on error reporting viadie()
my $dbh  =DBI->connect($dsn,$username,$password,\%attr);
$dbh->do('DELETE from utilisateurs where identifiant=?',
        undef,
        "$user");

$dbh->disconnect;


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


