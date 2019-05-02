#!/usr/bin/perl -w
# 
# Version 0.1 - 27/03/2017
#
use strict;
use ldap_lib;
use POSIX qw(strftime);
use DBI();
use Digest::MD5 qw(md5);
#-------------------------------------------------------#
# listUsers.pl 
#// liste les utilisateurs presents dans ldap et dans sql 
#-------------------------------------------------------#

#--------Ldap info:-------#
my %params;
&init_config(\%params);

#my $dbh  = connect_dbi($params{'db'});

my $ldap = connect_ldap($params{'ldap'});
#print "on test connecte a la base LDAP !\n";


#--------Mysql info------#
#MySQLdatabase configuration
my $dsn ="DBI:mysql:database=si;host=sql.imss.org";
my $username ="root";
my $password ='dbmaster';

#connection toMySQLdatabase
my %attr =(PrintError=>0,  #turn off error reporting via warn()
        RaiseError=>1);   #turn on error reporting viadie()
my $dbh  =DBI->connect($dsn,$username,$password,\%attr);



#-----fonction ldap-------#
# Declaration variables globales
my ($query,$sth,$res,$row,$user,$expire);
my ($lc);
my (@adds,@mods,@dels);
my (@SIusers,@LDAPusers);
my (%attrib);
my $today = strftime "%Y%m%d%H%M%S", localtime;

print "List des Utilisateurs ";
print "a ce moment : $today \n \n";


print "Utilisateurs LDAP: \n ";
# recuperation de la liste des utilisateurs LDAP
@LDAPusers = sort(get_users_list($ldap,'ou=users,dc=imss,dc=org'));
#$lc = List::Compare->new(\@SIusers, \@LDAPusers);
#@usersToDel = sort($lc->get_Ronly);
if (scalar(@LDAPusers) > 0) {
  foreach my $u (@LDAPusers) {
    my $dn = sprintf("uid= %s,%s",$u,'ou=users,dc=imss,dc=org');
    printf("User: %s\n",$dn);   
}


#-----fonction sql--------#

print "\n Utilisateurs SQL: \n";
my $query = "select * from utilisateurs" ;
my $sth = $dbh->prepare($query);

$sth->execute or die "SQL Error: $DBI::errstr\n";

while (my $row = $sth->fetchrow_hashref) {
        printf "User: uid= %s %s %s\n", $row->{identifiant} ,$row->{nom}, $row->{prenom};
}



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

}

sub sortlist {
  my @unsorted_list = @_;
  my @sorted_list = sort {
                           (split '\.', $a, 2)[1] cmp
                           (split '\.', $b, 2)[1]
                         } @unsorted_list;
  return(@sorted_list);
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


