package PTC::HPNA;


require 5.000;
use Exporter;
use lib qw(/opt/perl-traffic-control/lib);
use PTC::Utils;
use Carp;

@ISA = qw(Exporter);

@EXPORT = qw(getPreviewMessage updateWLANnetMessage clearWLANnetMessage getWLANnetMessage getWLANnetClientMessage saveHPNAClient addHPNAClient showHPNAAddress getHPNAClientID loadHPNAClient checkRegister getHPNAPassword saveHPNAPassword addClient updateClient addHPNAClientLANWORLD);



sub getHPNAClientID
{
    my $sth = $main::dbh_hpna->prepare("SELECT DISTINCT clientid FROM radcheck WHERE UserName = '$username';");
    $sth->execute();
    my @row;
    @row = $sth->fetchrow_array;
    #        print @row;
    return $row[0];
}


# Needs reason check
sub getWLANnetMessage
{
    my $username=shift;
    my $sth = $main::dbh_ptc->prepare("SELECT StartTime,ticket FROM blacklist WHERE UserName = '$username' AND StopTime = '0000-00-00 00:00:00' ;");
    $sth->execute();
    my @row;
    my $msg="";
    while (@row = $sth->fetchrow_array ) {
        $msg{$row[0]}=$row[1];
    }
    return \%msg;
}

sub getPreviewMessage
{
    my $dbh=shift;
    my $sth = $dbh->prepare("SELECT StartTime,ticket FROM blacklist WHERE id=1 ;");
    $sth->execute();
    my @row;
    my $msg="";
    while (@row = $sth->fetchrow_array ) {
        $msg{$row[0]}=$row[1];
    }
    return \%msg;
}

sub getWLANnetClientMessage
{
    my $clientid=shift;
    #print "SELECT StartTime,ticket FROM blacklist WHERE clientid = '$clientid' AND active = 1";
    my $sth = $main::dbh_ptc->prepare("SELECT StartTime,ticket FROM blacklist WHERE clientid = '$clientid' AND active=1;");
    $sth->execute();
    my @row;
    my %msg=();
    while (@row = $sth->fetchrow_array ) {
        #        print $row[0].$row[1];
        $msg{$row[0]}=$row[1];
    }
    #print time();
    return \%msg;
}

sub clearWLANnetMessage
{
        my $clientid=shift;
        if ($clientid)
        {
            my $sth = $main::dbh_ptc->do("UPDATE blacklist SET StopTime = NOW(),active=0 WHERE clientid = '$clientid' AND active=1 ;");
        }
        #$sth->execute();
        #    my @row;
        #my $msg="";
        #while ( @row = $sth->fetchrow_array ) {
        #$msg=$msg." ".$row[0]
        #}
        #return $msg;
}

sub updateWLANnetMessage
{
        my $clientid=shift;
        if ($clientid)
        {
            my $sth = $main::dbh_ptc->do("UPDATE blacklist SET ReadTime = NOW() WHERE clientid = '$clientid' AND active=1 ;");
        }
}

sub loadHPNAClient
{
    my $username=shift;
    $username=~s/\@wlanmail.com//;
    my %hpnaClients;
    my $sth = $main::dbh_hpna->prepare("SELECT Username,clientid,Attribute,Value FROM radreply WHERE UserName = '$username' ORDER BY Attribute;");
    $sth->execute();
    my @row;

    while ( @row = $sth->fetchrow_array ) {
        $hpnaClients{$row[0]}{'clientid'}=$row[1];
        $hpnaClients{$row[0]}{$row[2]}=$row[3];
    }
    return \%hpnaClients;
}


sub addClient
{
    my ($username,$password,$clientid,$speed)=@_;
    
    if (!defined $speed)
    {
        $speed="1024/1024";
    }

    $main::dbh_hpna->do("INSERT INTO radcheck VALUES (NULL,'$username','Password','$password','==','$clientid')");
    $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$username','Reply-Message','$clientid/$username/LANWORLD','$clientid','==')");
    $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$username','Filter-Id','$speed','$clientid','==')");
    my $error_str="Added";
    return \$error_str;

}

sub addHPNAClient
{
    my ($mac,$username,$password)=@_;
    $username=~s/\@wlanmail.com//;

    if ($mac !~m#(..\:..\:..\:..\:..\:..)#)
    {
        my $error_str="Laitteisto-osoite ei kelpaa : $mac";
        return \$error_str;
    }
    my $ref=loadHPNAClient($username);
    my %hpnaClients=%$ref;
    if (scalar keys %hpnaClients > 3)
    {
        my $error_str="Liikaa laitteisto-osoitteita / Too many MAC-Addresses ";
        return \$error_str;
    }
    foreach (keys %hpnaClients)
    {
        if ($hpnaClients{$_}{'clientid'} =~/\d+/)
        {
            $clientid=$hpnaClients{$_}{'clientid'};
            if (&checkRegister($mac))
            {
                my $error_str="Laitteisto-osoite on jo k�yt�ss� / MAC-Address is already registered";
                return \$error_str;
            }
            else
            {
                $main::dbh_hpna->do("INSERT INTO radcheck VALUES (NULL,'$mac','Password','$mac','==','$clientid')");
                $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$mac','Reply-Message','$clientid/$username/$main::region','$clientid','==')");

                if (exists $hpnaClients{$_}{'Filter-Id'})
                {
                    $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$mac','Filter-Id','$hpnaClients{$_}{'Filter-Id'}','$clientid','==')");
                    return 1;
                }
                else
                {
                }
                return 0;
            }
        }
    }
}


sub addHPNAClientLANWORLD
{
    my ($mac,$username,$password,$clientid,$speed)=@_;
    $username=~s/\@wlanmail.com//;

    if ($mac !~m#(..\:..\:..\:..\:..\:..)#)
    {
        my $error_str="Laitteisto-osoite ei kelpaa : $mac";
        return \$error_str;
    }
    if (&checkRegister($mac))
    {
        my $error_str="Laitteisto-osoite on jo k�yt�ss� / MAC-Address is already registered";
        return \$error_str;
    }
    else
    {
        if ($speed eq '')
        {
            $speed="1024/1024";
        }
        $main::dbh_hpna->do("INSERT INTO radcheck VALUES (NULL,'$mac','Password','$mac','==','$clientid')");
        $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$mac','Reply-Message','$clientid/$username/$main::region','$clientid','==')");
        $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$mac','Filter-Id','$speed','$clientid','==')");
    }
}


sub saveHPNAClient
{
    my ($mac,$filterid,$replymessage)=@_;

    $mac=lc($mac);
    if ($mac !~m#(..\:..\:..\:..\:..\:..)#)
    {
        my $error_str="Laitteisto-osoite ei kelpaa : $mac";
        return \$error_str;
    }

    if ($replymessage =~m#^(\d+)\/.*#)
    {
        $clientid=$1;;
        if (&checkRegister($mac))
        {
            my $error_str="Laitteisto-osoite on jo k�yt�ss� / MAC-Address is already registered";
            $error_str=$main::dbh_hpna->do("UPDATE radreply set Value='$replymessage' where clientid='$clientid' and UserName='$mac' and Attribute='Reply-Message'");
            if ($error_str eq "0E0")
            {
                $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$mac','Reply-Message','$replymessage','$clientid','==')");
            }
            elsif ($error_str eq 1)
            {
            }
            else
            {
                $error_str="!REPLY:".$error_str."!";
                return \$error_str;
            }


            if (defined $filterid)
            {
                $error_str=$main::dbh_hpna->do("UPDATE radreply SET Value='$filterid' where clientid='$clientid' and UserName='$mac' and Attribute='Filter-Id'");
                if ($error_str eq "0E0")
                {
                    $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$mac','Filter-Id','$filterid','$clientid','==')");
                    return 1;
                }
                elsif ($error_str eq 1)
                {
                    return $error_str;
                }
                else
                {
                    $error_str="!FILTER:".$error_str."!";
                    return \$error_str;


                }
            }
            $error_str="OK $clientid";
            return \$error_str;
            return 0;

            return \$error_str;
        }
        else
        {
            
            $main::dbh_hpna->do("INSERT INTO radcheck VALUES (NULL,'$mac','Password','$mac','==','$clientid')");
            $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$mac','Reply-Message','$replymessage','$clientid','==')");
            if (defined $filterid)
            {
                $main::dbh_hpna->do("INSERT INTO radreply VALUES (NULL,'$mac','Filter-Id','$filterid','$clientid','==')");
                my $error_str="OK $clientid";
                return \$error_str;
                return 1;
            }
            my $error_str="OK $clientid";
            return \$error_str;
            return 0;
        }
    }
    else
    {
        my $error_str="Reply-Message not valid";
        return \$error_str;
    }
    my $error_str="OK";
    return \$error_str;
}



sub deleteHPNAClient
{
    my $ref=loadSipClient();
    my %hpnaClients=%$ref;
    my @menus=("Asiakasnumero:","hpna-tunnus :");
    my @values=();



    print "Poista hpna-asiakas\n";
    for ($i=0; $i<scalar(@menus); $i++)
    {
        DELETE_START:
            #$values[$i] = $term->readline($menus[$i]);

            if (($i eq 0) && ($values[$i] ne ""))
            {
                my $sth = $dbh_hpna->prepare("SELECT * FROM radcheck WHERE clientid = '$values[0]' ORDER BY Attribute;");
                $sth->execute();
                my @row;
                while ( @row = $sth->fetchrow_array ) {
                    print " DELETE $row[0],$row[1],$row[2],$row[3]\n";
                }
                if (yes_or_no() eq 1)
                {
                    $dbh_hpna->do("DELETE FROM radcheck WHERE clientid='$values[0]'");
                }

            }

            if ( ($i eq 1) )
            {
                if (! exists $hpnaClients{$values[$i]})
                {
                    print "Tunnusta ei ole olemassa";
                    goto DELETE_START;
                }
                if ($i eq 1)
                {
                    my $sth = $dbh_hpna->prepare("SELECT * FROM radcheck WHERE UserName = '$values[$i]' ORDER BY Attribute;");
                    $sth->execute();
                    my @row;
                    while ( @row = $sth->fetchrow_array ) {
                        print " DELETE $row[0],$row[1],$row[2],$row[3]\n";
                    }
                    if (yes_or_no() eq 1)
                    {
                        $dbh_hpna->do("DELETE FROM radcheck WHERE UserName='$values[$i]'");
                    }

                }
                if ($i eq 2)
                {
                    my $sth = $dbh_hpna->prepare("SELECT * FROM radcheck WHERE Value = '$values[$i]' AND Attribute = 'SIP-URI-User' ORDER BY Attribute;");
                    $sth->execute();
                    my @row;
                    while ( @row = $sth->fetchrow_array ) {
                        print " DELETE $row[0],$row[1],$row[2],$row[3]\n";
                    }
                    if (yes_or_no() eq 1)
                    {
                        $dbh_hpna->do("DELETE FROM radcheck WHERE Value='$values[$i]'  AND Attribute = 'SIP-URI-User'");
                    }
                }

            }
    }
    foreach (sort {$hpnaClients{$a}{'SIP-URI-User'} <=> $hpnaClients{$b}{'SIP-URI-User'} } keys %hpnaClients)
    {
        print "# ".$hpnaClients{$_}{'SIP-URI-User'}."  ".$_."\n";
    }


}

sub showHPNAAddress
{

    my $ref=loadHPNAClient($username);
    my %hpnaClients=%$ref;
    foreach (keys %hpnaClients)
    {
        my $ref=$hpnaClients{$_}{'Calling-Station-Id'};
        my %temphash=%$ref;
        foreach (keys %temphash)
        {
            Tvalue("Rekister�ity HPNA-MAC",$_);
        }
    }

}

sub checkRegister
{
    my $mac=shift;
    my $found=0;
    my $sth = $main::dbh_hpna->prepare("SELECT Username,clientid,Attribute,Value FROM radcheck WHERE UserName = '$mac'  ORDER BY Attribute;");
    $sth->execute();
    my @row;

    while ( @row = $sth->fetchrow_array ) {
        $found++;
    }
    

    return $found;
}


return 1;
