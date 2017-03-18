#!/usr/bin/perl
# -----------------------------------------------------------------------------
use strict;
use warnings;
use Gtk2 '-init';
use FindBin qw /$RealBin/;
use File::Basename;
use constant ICON_PATH => $RealBin . '/i/';
use constant APPNAME   => 'DevLocker';
use constant APPVER    => '0.6';

# -----------------------------------------------------------------------------
my $PROGNAME = basename($0);
my $usage    = qq(
 Usage:
 $PROGNAME "DEVICE_ID_STRING" [position|last|first]
 Default position is 'last'  
 Run `xinput --list` to get DEVICE_ID_STRING );

_die($usage) if $#ARGV < 0 || $#ARGV > 1;
my $position = 'last';
if ( defined $ARGV[1] && $ARGV[1] =~ /^\d+|last|first$/ ) {
    $position = $ARGV[1];
}
elsif ( defined $ARGV[1] ) {
    _die($usage);
}

my ( $DEV_ID, $ICON_ON, $ICON_OFF ) = ( _get_dev_id() );
_die($DEV_ID) unless $DEV_ID =~ /^\d+$/;
_load_icons();

my $trayicon = Gtk2::StatusIcon->new;
my $locked   = 0;
_trayicon_set_tooltip();
_switch_state();
$trayicon->signal_connect(
    'button_press_event' => sub {
        my ( undef, $event ) = @_;
        if ( $event->button eq 3 ) {
            _switch_state() if $locked;
            Gtk2->main_quit;
        }
        elsif ( $event->button eq 1 ) {
            _switch_state();
        }
        1;
    }
);
Gtk2->main;

exit;

# -----------------------------------------------------------------------------
sub _trayicon_set_tooltip
{
    $trayicon->set_tooltip(
        "$ARGV[0] ($DEV_ID)\nLeft click: switch locking\nRight click: unlock and exit");
}

# -----------------------------------------------------------------------------
sub _get_dev_id
{
    my $x;
    unless ( open( $x, '-|', 'xinput' ) ) {
        return "Can't read xinput: $!\n";
    }
    my $pos = 0;
    my $devstring;
    while ( defined( my $line = <$x> ) ) {
        chomp $line;
        next unless $line =~ /$ARGV[0]/;
        ++$pos;
        if ( $position eq 'first' ) {
            $devstring = $line;
            last;
        }
        elsif ( $position eq 'last' ) {
            $devstring = $line;
        }
        elsif ( $position == $pos ) {
            $devstring = $line;
            last;
        }
    }
    close $x;
    unless ($devstring) {
        return "Can't read \"$ARGV[0]\" from xinput at position '$position'\n";
    }
    unless ( $devstring =~ /id=(\d+)/ ) {
        return "Can't find id=X in xinput output for \"$devstring\"\n";
    }
    return $1;
}

# -----------------------------------------------------------------------------
sub _load_icons
{
    my $file_on  = "$DEV_ID-on.png";
    my $file_off = "$DEV_ID-off.png";

    $file_on  = 'dev-on.png'  unless -f ICON_PATH . $file_on;
    $file_off = 'dev-off.png' unless -f ICON_PATH . $file_off;
    $file_on  = ICON_PATH . $file_on;
    $file_off = ICON_PATH . $file_off;
    eval { $ICON_ON = Gtk2::Gdk::Pixbuf->new_from_file($file_on); };
    _die("Error loading ON icon '$file_on'\n$@") if $@;
    eval { $ICON_OFF = Gtk2::Gdk::Pixbuf->new_from_file($file_off); };
    _die("Error loading OFF icon '$file_off'\n$@") if $@;
}

# -----------------------------------------------------------------------------
sub _switch_state
{
    $DEV_ID = _get_dev_id();
    if ( $DEV_ID =~ /^\d+$/ ) {
        _trayicon_set_tooltip();
        if ($locked) {
            $trayicon->set_from_pixbuf($ICON_ON);
            `xinput enable $DEV_ID`;
        }
        else {
            $trayicon->set_from_pixbuf($ICON_OFF);
            `xinput disable $DEV_ID`;
        }
        $locked ^= 1;
    }
    else {
        _die( $DEV_ID, 1 );
    }
}

# -----------------------------------------------------------------------------
sub _die
{
    my ( $msg, $noquit ) = @_;

    my $dialog = Gtk2::Dialog->new( APPNAME . ' v ' . APPVER,
        undef, 'destroy-with-parent', 'gtk-ok' => 'none' );
    my $label = Gtk2::Label->new("\n$msg\n");
    $dialog->get_content_area()->add($label);
    $dialog->signal_connect( response => sub { Gtk2->main_quit } );
    $dialog->show_all;
    unless ($noquit) {
        Gtk2->main;
        exit;
    }
}

# -----------------------------------------------------------------------------

