#!/usr/bin/perl 
# Copyright 2012 xocel lox, xocellox@gmail.com
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Repo: https://github.com/xocel/nightly
# Firefox Nightly/Aurora install & update script for Slackware Linux.
use strict;
use Tie::File;
use File::Find;
use File::Basename;

sub findlogs();

my $FTP = "http://ftp.mozilla.org/pub/mozilla.org/firefox/nightly/";
my $NIGHTLY = "latest-trunk/";
my $AURORA = "latest-mozilla-aurora/";

#Configure
my $CHANNEL = $NIGHTLY; #change to $AURORA for Aurora channel. 
my $ARCH = "x86_64"; #change to i686 for 32bit
#Version: This option is here for when multiple versions exist at the same time.
my $VER = "13"; #Change to 12 for Aurora.  

#set correct libdir 
my $libdir = "lib64";
if ($ARCH eq "i686") {
	$libdir = "lib";
}

#set name
my $name = "Nightly";
my $lcname = "nightly";

if($CHANNEL eq $AURORA) {
	$name = "Aurora";
	$lcname = "aurora";
}

my @buildinfo = ();
my $currentbuild = "";

#check for current installation.
if (-e "/usr/$libdir/firefox-$lcname/firefox") {
	#Installation found. Get BuildID.
	tie(@buildinfo, 'Tie::File', "/usr/$libdir/firefox-$lcname/application.ini") or die;
	$currentbuild = $buildinfo[4];
	$currentbuild =~ s/BuildID=//;
	untie(@buildinfo);
}
undef @buildinfo;
if( $currentbuild ne "" ) {
	print "Checking for updates..\n";
} else {
	print "Checking for latest version..\n"
}

#Get index.
my $tempdir = `mktemp -d /tmp/nightly.XXXXXX`;
chomp($tempdir);
my $wget = `wget -q $FTP$CHANNEL -P $tempdir`; #retrieve index.
my @indexfile = ();
my @index = ();

tie(@indexfile, 'Tie::File', "$tempdir/index.html");
@index = @indexfile;
untie(@indexfile);
undef @indexfile;

my $fullname = "";
my $start = 0;
my $end = 0;
foreach(@index) {
	if($_ =~ "linux-$ARCH.txt") {
		$start = index($_, 'firefox');
		$end = index($_, '.txt');
		$_ = substr($_, $start, $end - $start);
		if( $_ =~ $VER ) {
			$fullname = $_;
		}
	}
}
undef @index;
$start = index($fullname, '-') + 1;
$end = index($fullname, '.en');
my $latestver = substr($fullname, $start, $end - $start); 
#get latest buildID.
system("wget -q $FTP$CHANNEL$fullname.txt -P $tempdir");

my @buildfile = ();
my @builddata = ();
tie(@buildfile, 'Tie::File', "$tempdir/$fullname.txt") or die;
@builddata = @buildfile;
untie @buildfile;
my $latestbuild = $builddata[0];
undef @builddata;
if($currentbuild ne "") {
	if($latestbuild > $currentbuild) {
		print ("New version available, downloading $fullname ($latestbuild)\n");
		system("wget $FTP$CHANNEL$fullname.tar.bz2 -P $tempdir");
	} else {
		print "Already running latest build.\n";
		system("rm -rf $tempdir");
		exit;
	}
} else {
	print ("Downloading lastest version $fullname ($latestbuild)\n");
	system("wget $FTP$CHANNEL$fullname.tar.bz2 -P $tempdir");
}




#make package structure.
my $pkgroot = "$tempdir/firefox-nightly";
mkdir($pkgroot);
mkdir("$pkgroot/install");
mkdir("$pkgroot/usr");
mkdir("$pkgroot/usr/$libdir");
mkdir("$pkgroot/usr/bin");
mkdir("$pkgroot/usr/share");
mkdir("$pkgroot/usr/share/pixmaps");
mkdir("$pkgroot/usr/share/applications");

#create doinst.sh
my @doinst = ();
tie(@doinst, 'Tie::File', "$tempdir/firefox-nightly/install/doinst.sh");
push(@doinst, "( cd usr/bin ; rm -rf $lcname )");
push(@doinst, "( cd usr/bin ; ln -sf /usr/$libdir/firefox-$lcname/firefox $lcname )");
untie(@doinst);

#make executable.
system("chmod +x $tempdir/firefox-nightly/install/doinst.sh");

$libdir = "$pkgroot/usr/$libdir";
#extract.
system("cd $libdir ; tar -xjf $tempdir/$fullname.tar.bz2");
#rename firefox dir
system("mv $libdir/firefox $libdir/firefox-$lcname");
#copy icon to pixmaps
system("cp $libdir/firefox-$lcname/icons/mozicon128.png $tempdir/firefox-nightly/usr/share/pixmaps/$lcname.png");
#create .Desktop file
my @desktop = ();
tie(@desktop, 'Tie::File', "$tempdir/firefox-nightly/usr/share/applications/$lcname.desktop");
push(@desktop, "[Desktop Entry]");
push(@desktop, "Exec=$lcname %u");
push(@desktop, "Icon=$lcname");
push(@desktop, "Type=Application");
push(@desktop, "Categories=Network;");
push(@desktop, "Name=$name");
push(@desktop, "GenericName=Web Browser");
push(@desktop, "MimeType=text/html;");
push(@desktop, "X-KDE-StartupNotify=true");
untie(@desktop);

#make slack-desc
my @slackdesc = ();
tie(@slackdesc, 'Tie::File', "$tempdir/firefox-nightly/install/slack-desc");
push(@slackdesc, "$lcname: Firefox $name $latestver ($latestbuild)");
push(@slackdesc, "$lcname: ");
push(@slackdesc, "$lcname: Firefox $name is a developmental channel for new Firefox releases.");
push(@slackdesc, "$lcname: It's designed to showcase the more experimental builds of Firefox. The");
push(@slackdesc, "$lcname: $name channel allows users to experience the newest Firefox");
push(@slackdesc, "$lcname: innovations in an unstable environment and provide feedback on");
push(@slackdesc, "$lcname: features and performance to help determine what makes the final");
push(@slackdesc, "$lcname: release.");

untie(@slackdesc);

my $pkgname = "$lcname-$latestver-$ARCH-$latestbuild.txz";
system("cd $pkgroot ; /sbin/makepkg -c n -l y /tmp/$pkgname");

#get currently installed package name;
my @logs = ();
my $currentpkg = "";
find(\&findlogs,"/var/log/packages");
foreach(@logs) {
	if ($_ =~ "/$lcname-") {
		chomp($_);
		my @parsed = fileparse($_);
		$currentpkg = $parsed[0];
		undef @parsed;
	}
}

if($currentpkg eq "") {
	#no need for upgrade so just install.
	system("/sbin/installpkg /tmp/$pkgname");
} else {
	#upgrade no new package.
	system("/sbin/upgradepkg $currentpkg%/tmp/$pkgname");
}

sub findlogs()
#File::Find wanted function, install logs
{
	my $file = $File::Find::name;
	if (-T $file) {
		chomp($file);
		push (@logs, $file) unless (-d $file) or (-B $file);
	}
}
#cleanup.
system("rm -rf $tempdir");
system("rm /tmp/$pkgname"); #comment this line out if you want to keep the package.
undef @logs;
