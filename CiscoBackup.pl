#!/usr/bin/perl
## Author: Deepak Naidu
## Info: Remote SSH command to backup Cisco MDS switch config.

use Net::SSH qw(sshopen2);
use Mail::Send;

##Define variables
$LOC = $ARGV[0];
$ENV = $ARGV[1];
$WD = "/usr/Cisco" ;
$DATE = `date "+%m%d20%y_%H%M"` ;
chomp($DATE);
$CMD = "show running-config" ;
$LOG = "$WD/log/CiscoBackup-$DATE.log" ;
$CONFD = "/usr/Cisco/conf" ;
$USER = "CiscoBackup";
$SYS_GREPCMD = "egrep -v '^[[:cntrl:]]*#' $CONFD/$LOC.conf > $CONFD/$LOC.conf.swp" ;

##Check for script usage
if (@ARGV != 2)
{
   print ("Usage    : ./CiscoBackup COLO-NAME Prod [OR] Dev\n\n");
   exit(0);
}

elsif ($LOC eq “COLO1” && $ENV eq "Prod")
{
   backup();
}

else
{
   print "Example: ./CiscoBackup COLO1 Prod\n";
}


##Create email function
sub email
{
	##Send email for backup completion
        local (*HANDLE, $/, $_);
        open(HANDLE, "< $LOG") or die $!;
        $body = <HANDLE>;
        close(HANDLE);  

        $message = new Mail::Send Subject=>"CiscoBackup from SANMAN for $DATE", To=>'sanalerts@domain.com';
        $header = $message->open;
        print $header "Hello, Cisco Backup log output below\n";
	print $header "\n\n";
        print $header "$body\n";
        $header->close;
}

##Create backup function
sub backup
{
        ##Start logging
        open(backuplog, ">$LOG");
        print backuplog "Starting Log for Backup $DATE...\n" ;

        ##Check for dir, if not create else exit
        print backuplog "Creating dir $WD/$LOC/$ENV/$DATE...\n" ;
        mkdir("$WD/$LOC/$ENV/$DATE") || die "Unable to create directory <$!>\n" ;
        print backuplog "Created dir $WD/$LOC/$ENV/$DATE...\n" ;
        print backuplog "Parsing conf file & looping...\n" ;

        system($SYS_GREPCMD) ;
        open (FILE, "$CONFD/$LOC.conf.swp");
        while (<FILE>)
        {
                chomp;
                ($HOSTNAME, $IP) = split("\t");

                print backuplog "Starting backup of $HOSTNAME.cfg under $WD/$LOC/$ENV/$DATE...\n" ;
        
                open(cfg, ">$WD/$LOC/$ENV/$DATE/$HOSTNAME.cfg") ;
                sshopen2("$USER\@$IP", *READER, undef, "$CMD") || die "ssh: $!" ;
                while (<READER>)
                {
                        chomp();
                        print cfg "$_\n" ;
                }

                close(READER);
                close(cfg);

        }
        print backuplog "Backup completed for $DATE...\n" ;
        close (FILE);
        close (backuplog);
	email();
        exit;
}
