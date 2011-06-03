#!/usr/bin/perl
################################################################################################################
## mailhilight.pl by NChief
##
## This is a script for sending you email if you get hilighted or get a private message.
## It wil only trigger if you are away. (/away <reason>)
## It wil gather all hilights/msg and if no hilight/msg within specified interval(default 60sec), mail is sent.
##
## Script requires sendmail and perl module Mail::Sendmail (`cpan Mail::Sendmail`)
##
#### Settings explained:
## - /set mailhilight_hiligon YourNick
##		This sets what to trigger on. its a list of triggers sepreated with space
##		It wil on trigger if its surrounded by non word characters (A-z_)
## - /set mailhilight_to you@email.com
##		Set wich email to send your hilights to.
## - /set mailhilight_from from@email.com
##		Set the from-mail
## - /set mailhilight_intervall 60
##		This sets the time in sec from your highlight to recive it to stop gather hililights and send them.
## - /set mailhilight_subject New hilights/messages
##		Sets the subject the mail i sent with
## - /set mailhilight_print ON
##		Do you want to print messages like "Hilights sent du mail" in status?
## - /set mailhilight_timerreset ON
##		Do you want the timer to reset on new hilight?
## - /set mailhilight_ircaway ON
##		Use /away (ON) or depend on autoaway/screen away (OFF)?
## - /set mailhilight_autoawayreason Im away
##		Set away reason given on autoaway.
##
#### Commands:
## - /send_hilights
##		discard timer and send hiligts that are ready to send.
##
#### Changelog:
## 0.1 (http://pastebin.com/mFSUcFxS)
##	* Initial release.
## 0.2 (http://pastebin.com/eCKqtWeZ)
##	* Code-cleanup
##	* More documentation
##	* Use $var insted of file
##	* Everything i forgot
## 0.3 (http://pastebin.com/ys6XpDa7)
##	* interval is in sec
##	* cleanup
##	* reset timer on new hilight
##	* Possible to set subject in settings
##	* Possible to turn of status prints
## 0.4 (http://pastebin.com/DKQ6GxKb)
##	* autoaway is integrated with mods (Use own settings if use)
##  * screen_away is integrated with mods (use own settings if use)
##	* if connected to irssi-proxy we wont be away or send mail. edit ircnet to fit you on line 556 and 572
##	* reset timer is optional
##	* possible to be away without /away
##	* The tings i forgot.
## 0.5
##	* Autoaway reason
##	* bugfix with _ircaway
##
#### TODO:
## - Context( X lines before and after hilight) if possible.
## - more cleanup
## - Printformats for print with theme.
## - Set auto-away reason
## - better print handling(se also above)
##
################################################################################################################

use strict;
use warnings;

# Irssi import
use Irssi qw(settings_add_str settings_get_str print settings_add_int settings_get_int settings_get_bool settings_add_bool);
use Irssi::Irc;
# Sendmail for sending mail
use Mail::Sendmail;

use POSIX;
use utf8;
use vars qw($VERSION %IRSSI);

# IRSSI
$VERSION = "0.4";
%IRSSI = (
        authours => 'NChief',
        contact => 'NChief @ EFNet',
        name => 'mailhilight',
        description => 'Send mail on hilight/msg'
);

# Settings
settings_add_str('mailhilight', 'mailhilight_hiligon', 'yournick somthingelse');
settings_add_str('mailhilight', 'mailhilight_to', 'your@mailadrrr.com');
settings_add_str('mailhilight', 'mailhilight_from', 'from@mailarrr.com');
settings_add_int('mailhilight', 'mailhilight_interval', 60);
settings_add_str('mailhilight', 'mailhilight_subject', 'New hilights/messages');
settings_add_bool('mailhilight', 'mailhilight_print', 1);
settings_add_bool('mailhilight', 'mailhilight_timerreset', 1);
settings_add_bool('mailhilight', 'mailhilight_ircaway', 1); # Use /AWAY ?
settings_add_str('mailhilight', 'mailhilight_autoawayreason', 'Im autoaway');

# Global vars
my @hilights = split(" ", settings_get_str('mailhilight_hiligon'));
my $mailto = settings_get_str('mailhilight_to');
my $mailfrom = settings_get_str('mailhilight_from');
my $subject = settings_get_str('mailhilight_subject');
my $ircaway = settings_get_bool('mailhilight_ircaway');
my $timebuffer = undef; # used for timers
my $messages = undef; # Message sent to mail
my $is_away = 0;

sub start_timer {
        if ($timebuffer && settings_get_bool('mailhilight_timerreset')) { # reset timer.
                Irssi::timeout_remove($timebuffer);
                $timebuffer = undef;
        }
        unless(defined($timebuffer)) { # If no timer set
                $timebuffer = Irssi::timeout_add_once(settings_get_int('mailhilight_interval') * 1000, 'send_hilights', undef);
        }
}

# On public message
sub event_public_message {
        my ($server, $msg, $nick, $address, $target) = @_;
        foreach (@hilights) {
                if ($msg =~ /(\W|^)$_(\W|$)/i) {
                        my $time = strftime(Irssi::settings_get_str('timestamp_format')." ", localtime);
                        $messages .= $time.$target." <".$nick."> ".$msg."\n";
						if ($is_away) {
							start_timer();
							print "Hilight saved" if (settings_get_bool('mailhilight_print'));
						}
                }
        }
}

sub event_privmsg { # If Private message
        my ($server, $data, $nick, $address) = @_;
        my ($target, $text) = split(/ :/, $data, 2);
        if ($target eq $server->{nick}) {
                my $time = strftime(Irssi::settings_get_str('timestamp_format')." ", localtime);
                $messages .= $time."<".$nick."> ".$text."\n";
				if ($is_away) {
					start_timer();
					print "MSG saved" if (settings_get_bool('mailhilight_print'));
				}
        }
}

sub send_hilights {
        if(defined($messages)) { # If we got a message to send.
                my %mail = ( To => $mailto, From => $mailfrom, 'Content-Type' => 'text/plain; charset="UTF-8"', Subject => $subject, Message => $messages );
                sendmail(%mail) or die($Mail::Sendmail::error);
                print "Hilights sent to ".$mailto if (settings_get_bool('mailhilight_print'));
                $timebuffer = undef;
                $messages = undef;
        }
}

sub sig_setup_changed { # If setup is changed update vars.
        @hilights = split(" ", settings_get_str('mailhilight_hiligon'));
        $mailto = settings_get_str('mailhilight_to');
        $mailfrom = settings_get_str('mailhilight_from');
		$subject = settings_get_str('mailhilight_subject');
		$ircaway = settings_get_bool('mailhilight_ircaway');
}

# Print on load!
print "";
print "\002mailhilight\002 by \002NChief\002 v1.0";
print "Sends hilights on mail if away";
print "see '/set mailhilight' for settings";

# Signals
Irssi::signal_add("message public", "event_public_message");
Irssi::signal_add("event privmsg", "event_privmsg");
Irssi::command_bind('mailhilight', 'send_hilights');
Irssi::signal_add_last('setup changed', "sig_setup_changed");

##
## AUTOAWAY ##
##

# /AUTOAWAY <n> - Mark user away after <n> seconds of inactivity
# /AWAY - play nice with autoaway
# New, brighter, whiter version of my autoaway script. Actually works :)
# (c) 2000 Larry Daffner (vizzie@airmail.net)
#     You may freely use, modify and distribute this script, as long as
#      1) you leave this notice intact
#      2) you don't pretend my code is yours
#      3) you don't pretend your code is mine
#
# share and enjoy!

# A simple script. /autoaway <n> will mark you as away automatically if
# you have not typed any commands in <n> seconds. (<n>=0 disables the feature)
# It will also automatically unmark you away the next time you type a command.
# Note that using the /away command will disable the autoaway mechanism, as
# well as the autoreturn. (when you unmark yourself, the autoaway wil
# restart again)

# Thanks to Adam Monsen for multiserver and config file fix

my ($autoaway_sec, $autoaway_to_tag, $autoaway_state);
$autoaway_state = 0;
my $connected = 0;

#
# /AUTOAWAY - set the autoaway timeout
#
sub cmd_autoaway {
  my ($data, $server, $channel) = @_;
  
  if (!($data =~ /^[0-9]+$/)) {
    Irssi::print("autoaway: usage: /autoaway <seconds>");
    return 1;
  }
  
  $autoaway_sec = $data;
  
  if ($autoaway_sec) {
    Irssi::settings_set_int("autoaway_timeout", $autoaway_sec);
    Irssi::print("autoaway timeout set to $autoaway_sec seconds");
  } else {
    Irssi::print("autoway disabled");
  }
  
  if (defined($autoaway_to_tag)) {
    Irssi::timeout_remove($autoaway_to_tag);
    $autoaway_to_tag = undef;
  }

  if ($autoaway_sec) {
    $autoaway_to_tag =
      Irssi::timeout_add($autoaway_sec*1000, "auto_timeout", "");
  }
}

#
# away = Set us away or back, within the autoaway system
sub cmd_away {
  my ($data, $server, $channel) = @_;
  
  if ($data eq "") {
    $autoaway_state = 0;
	$is_away = 0;
    # If $autoaway_state is 2, we went away by typing /away, and need
    # to restart autoaway ourselves. Otherwise, we were autoaway, and
    # we'll let the autoaway return take care of business.

    if ($autoaway_state eq 2) {
      if ($autoaway_sec) {
	$autoaway_to_tag =
	  Irssi::timeout_add($autoaway_sec*1000, "auto_timeout", "");
      }
    }
  } else {
	$is_away = 1;
    if ($autoaway_state eq 0) {
      Irssi::timeout_remove($autoaway_to_tag);
      $autoaway_to_tag = undef;
      $autoaway_state = 2;
	  
    }
  }
}

sub auto_timeout {
	my ($data, $server) = @_;
	unless ($connected) {
		# we're in the process.. don't touch anything.
		$autoaway_state = 3;
	
	
		Irssi::command("/AWAY ".settings_get_str('mailhilight_autoawayreason')) if ($ircaway);
		$is_away = 1;
		send_hilights();
	

		Irssi::timeout_remove($autoaway_to_tag);
		$autoaway_state = 1;
	}
}

sub reset_timer {
   if ($autoaway_state eq 1) {
     $autoaway_state = 3;
     #foreach my $server (Irssi::servers()) {
         #$server->command("/AWAY");
	Irssi::command("/AWAY") if ($ircaway);
	$is_away = 0;
     #}
     $autoaway_state = 0;
   } 
  if ($autoaway_state eq 0) {
	$message = undef;
    if (defined($autoaway_to_tag)) {
      Irssi::timeout_remove($autoaway_to_tag);
      $autoaway_to_tag = undef();
    }
    if ($autoaway_sec) {
      $autoaway_to_tag = Irssi::timeout_add($autoaway_sec*1000
					    , "auto_timeout", "");
    }
  }
}

Irssi::settings_add_int("misc", "autoaway_timeout", 0);

my $autoaway_default = Irssi::settings_get_int("autoaway_timeout");
if ($autoaway_default) {
  $autoaway_to_tag =
    Irssi::timeout_add($autoaway_default*1000, "auto_timeout", "");
	$autoaway_sec = $autoaway_default;

}

Irssi::command_bind('autoaway', 'cmd_autoaway');
Irssi::command_bind('away', 'cmd_away');
Irssi::signal_add('send command', 'reset_timer');

##
## SCREEN AWAY
##


use FileHandle;


# screen_away irssi module
#
# written by Andreas 'ads' Scherbaum <ads@ufp.de>
#
# changes:
#  07.02.2004 fix error with away mode
#             thanks to Michael Schiansky for reporting and fixing this one
#  07.08.2004 new function for changing nick on away
#  24.08.2004 fixing bug where the away nick was not storedcorrectly
#             thanks for Harald Wurpts for help debugging this one
#  17.09.2004 rewrote init part to use $ENV{'STY'}
#  05.12.2004 add patch for remember away state
#             thanks to Jilles Tjoelker <jilles@stack.nl>
#             change "chatnet" to "tag"
#  18.05.2007 fix '-one' for SILC networks
#
#
# usage:
#
# put this script into your autorun directory and/or load it with
#  /SCRIPT LOAD <name>
#
# there are 5 settings available:
#
# /set screen_away_active ON/OFF/TOGGLE
# /set screen_away_repeat <integer>
# /set screen_away_message <string>
# /set screen_away_window <string>
# /set screen_away_nick <string>
#
# active means, that you will be only set away/unaway, if this
#   flag is set, default is ON
# repeat is the number of seconds, after the script will check the
#   screen status again, default is 5 seconds
# message is the away message sent to the server, default: not here ...
# window is a window number or name, if set, the script will switch
#   to this window, if it sets you away, default is '1'
# nick is the new nick, if the script goes away
#   will only be used it not empty
#
# normal you should be able to rename the script to something other
# than 'screen_away' (as example, if you dont like the name) by simple
# changing the 'name' parameter in the %IRSSI hash at the top of this script


# variables
my $timer_name = undef;
my $away_status = 0;
my %old_nicks = ();
my %away = ();


# Register formats
Irssi::theme_register(
[
 'screen_away_crap', 
 '{line_start}{hilight screen_away:} $0'
]);

# if we are running
my $screen_away_used = 0;

# try to find out, if we are running in a screen
# (see, if $ENV{STY} is set
if (!defined($ENV{STY})) {
  # just return, we will never be called again
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'screen_away_crap',
    "could not open status file for parent process (pid: " . getppid() . "): $!");
  return;
}

my ($socket_name, $socket_path);

# search for socket
# normal we could search the socket file, ... if we know the path
# but so we have to call one time the screen executable
# disable locale
# the quotes around C force perl 5.005_03 to use the shell
# thanks to Jilles Tjoelker <jilles@stack.nl> for pointing this out
my $socket = `LC_ALL="C" screen -ls`;



my $running_in_screen = 0;
# locale doesnt seems to be an problem (yet)
if ($socket !~ /^No Sockets found/s) {
  # ok, should have only one socket
  $socket_name = $ENV{'STY'};
  $socket_path = $socket;
  $socket_path =~ s/^.+\d+ Sockets? in ([^\n]+)\.\n.+$/$1/s;
  if (length($socket_path) != length($socket)) {
    # only activate, if string length is different
    # (to make sure, we really got a dir name)
    $screen_away_used = 1;
  } else {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'screen_away_crap',
      "error reading screen informations from:");
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'screen_away_crap',
      "$socket");
    return;
  }
}

# last check
if ($screen_away_used == 0) {
  # we will never be called again
  return;
}

# build complete socket name
$socket = $socket_path . "/" . $socket_name;

# register config variables
Irssi::settings_add_bool('misc', 'screen_away_active', 1);
Irssi::settings_add_int('misc', 'screen_away_repeat', 5);
Irssi::settings_add_str('misc', 'screen_away_message', "not here ...");
Irssi::settings_add_str('misc', 'screen_away_window', "1");
Irssi::settings_add_str('misc', 'screen_away_nick', "");

# init process
screen_away();

# screen_away()
#
# check, set or reset the away status
#
# parameter:
#   none
# return:
#   0 (OK)
sub screen_away {
  my ($away, @screen, $screen);

  # only run, if activated
  if (Irssi::settings_get_bool('screen_away_active') == 1) {
    if ($away_status == 0) {
      # display init message at first time
      Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'screen_away_crap',
        "activating screen_away (interval: " . Irssi::settings_get_int('screen_away_repeat') . " seconds)");
    }
    # get actual screen status
    my @screen = stat($socket);
    # 00100 is the mode for "user has execute permissions", see stat.h
    if (($screen[2] & 00100) == 0) {
      # no execute permissions, Detached
      $away = 1;
    } else {
      # execute permissions, Attached
      $away = 2;
    }

    # check if status has changed
    if ($away == 1 and $away_status != 1 and $connected != 1) {
      # set away
      if (length(Irssi::settings_get_str('screen_away_window')) > 0) {
        # if length of window is greater then 0, make this window active
        Irssi::command('window goto ' . Irssi::settings_get_str('screen_away_window'));
      }
      Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'screen_away_crap',
        "Set away");
      my $message = Irssi::settings_get_str('screen_away_message');
      if (length($message) == 0) {
        # we have to set a message or we wouldnt go away
        $message = "not here ...";
      }
      my ($server);
      foreach $server (Irssi::servers()) {
        if (!$server->{usermode_away}) {
          # user isnt yet away
          $away{$server->{'tag'}} = 0;
          $server->command("AWAY " . (($server->{chat_type} ne 'SILC') ? "-one " : "") . "$message") if (!$server->{usermode_away} && $ircaway);
		  $is_away = 1;
          if (length(Irssi::settings_get_str('screen_away_nick')) > 0) {
            # only change, if actual nick isnt already the away nick
            if (Irssi::settings_get_str('screen_away_nick') ne $server->{nick}) {
              # keep old nick
              $old_nicks{$server->{'tag'}} = $server->{nick};
              # set new nick
              $server->command("NICK " . Irssi::settings_get_str('screen_away_nick'));
            }
          }
        } else {
          # user is already away, remember this
          $away{$server->{'tag'}} = 1;
        }
      }
      $away_status = $away;
    } elsif ($away == 2 and $away_status != 2) {
      # unset away
      Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'screen_away_crap',
        "Reset away");
      my ($server);
      foreach $server (Irssi::servers()) {
        if (defined($away{$server->{'tag'}}) && $away{$server->{'tag'}} == 1) {
          # user was already away, dont reset away
          $away{$server->{'tag'}} = 0;
          next;
        }
        $server->command("AWAY" . (($server->{chat_type} ne 'SILC') ? " -one" : "")) if ($server->{usermode_away} && $ircaway);
		$is_away = 0;
        if (defined($old_nicks{$server->{'tag'}}) and length($old_nicks{$server->{'tag'}}) > 0) {
          # set old nick
          $server->command("NICK " . $old_nicks{$server->{'tag'}});
          $old_nicks{$server->{'tag'}} = "";
        }
      }
      $away_status = $away;
    }
  }
  # but everytimes install a new timer
  register_screen_away_timer();
  return 0;
}

# register_screen_away_timer()
#
# remove old timer and install a new one
#
# parameter:
#   none
# return:
#   none
sub register_screen_away_timer {
  if (defined($timer_name)) {
    # remove old timer, if defined
    Irssi::timeout_remove($timer_name);
  }
  # add new timer with new timeout (maybe the timeout has been changed)
  $timer_name = Irssi::timeout_add(Irssi::settings_get_int('screen_away_repeat') * 1000, 'screen_away', '');
}

my $old_state = $autoaway_state;
sub client_connect {
	my($client) = shift;
	my $server = $client->{server};
	#print $client->{server}->{usermode_away};
	if($client->{ircnet} eq "NorTV") { #other ircnets suck
		$connected = 1;
		
		if($server->{usermode_away}) {
			Irssi::command("/AWAY") if ($ircaway);
			$is_away = 0;
		}
		$old_state = $autoaway_state;
		$autoaway_state = 3;
	}
}

sub client_disconnect {
	my($client) = shift;
	my $server = $client->{server};
	#print $client->{server}->{usermode_away};
	if($client->{ircnet} eq "NorTV") { # :D
		$connected = 0;
		$autoaway_state = $old_state;
		$old_state = 0;
		#reset_timer();
	}
}

Irssi::signal_add_last('proxy client connected', 'client_connect');
Irssi::signal_add_last('proxy client disconnected', 'client_disconnect');

