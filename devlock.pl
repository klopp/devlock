#!/usr/bin/perl

###################################################################
use strict;
use warnings;

use constant INIT_LOCK => 1;    # 0 to unlock keyboard at start

use Gtk2 '-init';
use FindBin qw ( $RealBin );
use constant ICON_PATH => $RealBin . '/i/';
use constant APPNAME   => 'DevLocker';
use constant APPVER    => '0.3';

###################################################################
my $locked   = !INIT_LOCK;
my $lockfile = $0;
$0 =~ m|^.*/([^/]+)$| and $lockfile = $1;
my $DEV_ID = $ARGV[0]
  or _die( "Usage: $lockfile device_id\nRun `xinput --list` to get device_id" );
my $devname = `xinput --list --name-only $DEV_ID 2>&1`;
chomp $devname if $devname;
_die( "Can not get device name for ID '$DEV_ID'!" )
  if !$devname
  or $devname =~ /$DEV_ID$/;
my $ICON_ON;
my $ICON_OFF;

_loadIcons();
$SIG{HUP} = sub {
    _loadIcons( 1 );
    $locked ^= 1;
    _switchState();
};

$lockfile = "/var/lock/$lockfile.$DEV_ID.lock";
if( open my $lock, q{<}, $lockfile )
{
    my $pid = <$lock>;
    close $lock;
    _die( "Already loaded for '$devname'!\n(device ID: $DEV_ID, PID: $pid)" )
      if kill 0, $pid;
}
_die( "Can not create lock in '$lockfile'!" )
  unless open my $lock, q{>}, $lockfile;
print $lock $$;
close $lock;

###################################################################
my $trayicon = Gtk2::StatusIcon->new;
$trayicon->set_tooltip(
"$devname ($DEV_ID)\nLeft click: switch locking\nRight click: unlock and exit"
);
_switchState();
$trayicon->signal_connect(
    'button_press_event' => sub {
        my ( undef, $event ) = @_;
        if( $event->button eq 3 )
        {
            Gtk2->main_quit;
        }
        elsif( $event->button eq 1 )
        {
            _switchState();
        }
        1;
    }
);
Gtk2->main;
_unlock();
unlink $lockfile;

###################################################################
sub _lock
{
    `xinput --disable $DEV_ID`;
}

###################################################################
sub _unlock
{
    `xinput --enable $DEV_ID`;
}

###################################################################
sub _switchState
{
    if( $locked )
    {
        $trayicon->set_from_pixbuf( $ICON_ON );
        _unlock();
    }
    else
    {
        $trayicon->set_from_pixbuf( $ICON_OFF );
        _lock();
    }
    $locked ^= 1;
}

###################################################################
sub _die
{
    my ( $msg, $nogtk ) = @_;

    my $dialog = Gtk2::Dialog->new( APPNAME . ' v ' . APPVER,
        undef, 'destroy-with-parent', 'gtk-ok' => 'none' );
    my $label = Gtk2::Label->new( "\n$msg\n" );
    $dialog->get_content_area()->add( $label );
    $dialog->signal_connect( response => sub { Gtk2->main_quit } );
    $dialog->show_all;
    unless( $nogtk )
    {
        Gtk2->main;
        exit;
    }
}

###################################################################
sub _loadIcons
{
    my ( $running ) = @_;

    undef $ICON_ON  if $ICON_ON;
    undef $ICON_OFF if $ICON_OFF;

    my $file_on  = "$DEV_ID-on.png";
    my $file_off = "$DEV_ID-off.png";
    $file_on  = 'dev-on.png'  unless -f ICON_PATH . $file_on;
    $file_off = 'dev-off.png' unless -f ICON_PATH . $file_off;
    $file_on  = ICON_PATH . $file_on;
    $file_off = ICON_PATH . $file_off;
    eval { $ICON_ON = Gtk2::Gdk::Pixbuf->new_from_file( $file_on ); };
    _die( "Error loading ON icon '$file_on'\n$@", $running ) if $@;
    eval { $ICON_OFF = Gtk2::Gdk::Pixbuf->new_from_file( $file_off ); };
    _die( "Error loading OFF icon '$file_off'\n$@", $running ) if $@;
}

###################################################################
