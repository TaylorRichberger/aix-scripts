# ApiIdsPha.pm
# Absolute Performance Inc., LLC
#   Informix Dynamic Server
#      Pseudo-High Availability
# subroutines common to the programs
# Copyright (c) 2009 Absolute Performance Inc., LLC. All rights reserved.
package ApiIdsPha;

use warnings;
use strict;
require Exporter;
our @ISA = qw(Exporter);
# valid with Perl 5.8.3 and later:
#use Exporter qw{import};
our (@EXPORT) = qw{
   set_shared_variables
   get_local_logical_log_backup_files 
   delete_old_logs
   get_log_index
   logs_report
   get_ids_mode
   start_logging
   stop_logging
   log_die
   log_print
   log_warn
   validate_ltapedev
   validate_tapedev
   parse_onconfig
   locate_cmd
   get_set_environment_variables
   set_signal_data
   get_signal_number
   get_signal_name
   display_time
   chown_informix
   set_mail_host
   set_mail_from
   set_mail_to
   set_mail_cc
   set_mail_subject
   set_running_state
   set_stopped_state
   at_exit
};
our $VERSION = '1.1';

use Config;
use Cwd qw{realpath};
use English qw{-no_match_vars};
use Env qw{@PATH};
use Fcntl qw{:mode :seek :flock};
use File::Basename qw{fileparse};
use File::Spec::Functions qw{splitpath catfile catdir canonpath};
use File::stat;
use IO::Dir;
use IO::File;
use List::Util qw{first};
use Net::Domain qw{hostname};
use Net::SMTP;
use POSIX qw{strftime};
#use Data::Dumper;
#$Data::Dumper::Terse = 1;
#$Data::Dumper::Sortkeys = 1;
#$Data::Dumper::Indent = 3;
sub set_shared_variables ;
sub get_local_logical_log_backup_files;
sub delete_old_logs;
sub get_log_index;
sub logs_report;
sub get_ids_mode;
sub start_logging;
sub stop_logging;
sub log_die;
sub log_print;
sub log_warn;
sub get_mem_log;
sub validate_tapedev;
sub validate_ltapedev;
sub parse_onconfig;
sub locate_cmd;
sub get_set_environment_variables;
sub set_signal_data;
sub get_signal_number;
sub get_signal_name;
sub display_time;
sub chown_informix;
sub set_mail_host;
sub set_mail_from;
sub set_mail_to;
sub set_mail_cc;
sub set_mail_subject;
sub send_mail;
sub set_running_state;
sub set_stopped_state;
sub at_exit;

# Informix Dynamic Server default values (some values are mentioned in POD)
my $informixdir_default = '/Medic/APPS/Informix1';
my $informixserver_default = 'ifx1';
my $onconfig_file_default = 'onconfig.ifx1';
my $informixsqlhosts_file_default = 'sqlhosts';

# Informix Dynamic Server environment variable and subdirectory names
my $informixdir_env_name = 'INFORMIXDIR';
my $informixserver_env_name = 'INFORMIXSERVER';
my $onconfig_env_name = 'ONCONFIG';
my $informixsqlhosts_env_name = 'INFORMIXSQLHOSTS';
my $informix_bin_subdir = 'bin';
my $informix_etc_subdir = 'etc';

our $hostname;
our $progname;
our $log_match_regex;
our $mail_opt;
our $verbose_opt;
our $print_opt;
our $log_opt;
our $test_opt;

sub set_shared_variables {
   no strict 'refs';
   my $href = shift;
   for my $varname (keys %{$href}) {
      ${$varname} = $href->{$varname};
   }
}

sub get_local_logical_log_backup_files {
# get names and sizes of local (disaster recovery) logical log backup files
   my $logs_aref = shift;       # ref array of names of logical log backup files
   my $logs_href = shift;       # ref hash keyed by name of logical log backup file
   my $logdir = shift;
   log_print "Local ($hostname) logical log backup files -"
      if $verbose_opt;
   my $log_dir_fh = IO::Dir->new($logdir)
      or log_die "Cannot open logical log backup directory $logdir ($OS_ERROR)";
   @{$logs_aref} = sort grep { m{$log_match_regex}o } $log_dir_fh->read;
   # grep has filtered entries that match logical log backup names
   for my $name ( @{$logs_aref} ) {
      my $log_stat = stat($name) or
         log_die "Stat of $name failed ($OS_ERROR)";
      log_die "File $name is not a plain file"
         unless S_ISREG $log_stat->mode;
      log_print
         sprintf('%9d %s %s', $log_stat->size, display_time($log_stat->mtime), $name)
         if $verbose_opt;
      # remember names, sizes and mtimes of logical log backup files
      $logs_href->{$name} = {size => $log_stat->size, mtime => $log_stat->mtime};
   } 
   $log_dir_fh->close
      or log_die "Cannot close logical log backup directory $logdir ($OS_ERROR)";
}

sub delete_old_logs {
# delete logical log backups that were selected for removal
   my $logs = shift;            # ref array of names of log files
   my $log_attrs = shift;       # ref hash of names with size and mtime
   my $last_applied_lognum = shift;
   my $latest_mtime = shift;
   my $last_log_index = get_log_index($logs, $last_applied_lognum);
   my $files_deleted = 0;
   my $exit_code = 0;
   my $log_index = -1;
   for my $name (@{$logs}) {
      $log_index++;
      # quit when at unapplied logs
      last if defined $last_log_index and $log_index > $last_log_index; 
      # quit when files are too recent
      last if $log_attrs->{$name}{mtime} >= $latest_mtime;
      if ($test_opt or unlink $name) {
         $files_deleted++;
         $log_attrs->{$name}{deleted} = 1;
         log_print "Deleted $name"
            if $verbose_opt;
      } else {
         $exit_code = 1;
         log_warn "Unlink failed for $name ($OS_ERROR)";
      }
   }
   return ($exit_code, $files_deleted);
}

sub get_log_index {
   my $logs = shift;    # ref array of names of log files
   my $lognum = shift;  # log number to find
   return undef unless defined $lognum;
   my $lognum1;
   my $lognum2;
   my $ix = 0;
   for my $log (@{$logs}) {
      ($lognum1, $lognum2) = $log =~ m{$log_match_regex}o;
      if (defined $lognum2) {
        return $ix if $lognum1 <= $lognum and $lognum <= $lognum2;
      } else {
        return $ix if $lognum == $lognum1;
      }
      $ix++;
   }
   return undef; 
}

sub logs_report {
   my $log_names = shift;       # ref array of log file names
   my $log_attrs = shift;       # ref hash of names with size and mtime
   my @loginfo;                 # holds data for sorting and reporting
   return unless @{$log_names};
   log_print 'Logical log backup files report',
      sprintf("%-30s %4s %10s %10s %3s %3s %3s", 'File', 'Tape', 'Begin Log', 'End Log', 'Cpy', 'Apl', 'Del') ,
      sprintf("%30s %4s %10s %10s %3s %3s %3s", '-' x 30, '-' x 4, '-' x 10, '-' x 10, '-' x 3, '-' x 3, '-' x 3);
   for my $logfile (@{$log_names}) {
      my $attr = $log_attrs->{$logfile};
      my ($tapenum, $lognum, $lognum2, $copied, $applied, $deleted);
      if (exists $attr->{tapenum}) {
         $tapenum = $attr->{tapenum};
         $lognum  = $attr->{lognum};
         $lognum2 = (exists $attr->{lognum2} and defined $attr->{lognum2}) ? $attr->{lognum2} : '';
         $applied = (exists $attr->{applied} and defined $attr->{applied}) ? 'y' : '';
      } else {
         $tapenum = $lognum = $lognum2 = $applied = '';
      }
      $copied = exists $attr->{copied} ? 'y' : '';
      $deleted = exists $attr->{deleted} ? 'y' : '';
      log_print sprintf("%-30s %4s %10s %10s %3s %3s %3s", $logfile, $tapenum, $lognum, $lognum2, $copied, $applied, $deleted); 
   }
}

{
# private to these subs
my $onstat_path;
my $onstat_name;
my $onstat_output;
my $onstat_hdr_only_opt;

sub get_ids_mode {
# run onstat - and regex match output for mode
   unless (defined $onstat_path) {
      $onstat_name = 'onstat';
      $onstat_path = locate_cmd $onstat_name;
      $onstat_output = '2>&1';
      $onstat_hdr_only_opt = '-';
   }
   my $onstat_cmdline = join(' ',
      $onstat_path,
      $onstat_hdr_only_opt,
      $onstat_output,
   );
   my $mode;
   my $onstat_out = qx{$onstat_cmdline};        # here's where onstat is run
   my $onstat_sig = $CHILD_ERROR & 127;         # signal
   my $onstat_rc = $CHILD_ERROR >> 8;           # return code
   if ($CHILD_ERROR == -1) {
      log_die "Failed to execute $onstat_name ($OS_ERROR)";
   } elsif ($onstat_sig) {
      log_die "$onstat_name died with signal $onstat_sig";
   }
   ($mode) = $onstat_out =~ m{^IBM Informix Dynamic Server Version .+-- (.+) -- Up}m;
   $mode = 'Stopped' unless defined $mode;
   return $mode;
}

}

{
# private to these subs
my $our_logging;
my $our_log_path;
my $our_log_fh;
my @our_mem_log;
my $test_prefix;

sub start_logging {
# open our log file
   if ($log_opt) {
      $our_log_path = shift;
      $our_log_fh = IO::File->new($our_log_path, '>>')
         or die "Cannot open log file $our_log_path ($OS_ERROR)";
      chown_informix $our_log_path
         or die "Cannot chown log file $our_log_path";
   }
   @our_mem_log = ();
   $our_logging = 1;
   $test_prefix = $test_opt ? '[test] ' : '';
   log_print 'Begin execution';
   if ($test_opt) {
      log_print 'Test mode - no changes will be made';
      log_warn "Test mode warning message"; 
   }
}

sub stop_logging {
   log_print 'End execution';
   undef $our_logging;
# close our log file
   $our_log_fh->close
      or die "Cannot close log file $our_log_path ($OS_ERROR)"
      if defined $our_log_fh;
}

sub log_print {
# write to stdout and log with timestamp and perhaps test indication
   if (defined $our_logging) {
      for my $arg (@_) {
         # each defined item in arglist is at least one line
         if (defined $arg) {
            # each list item may have had newlines imbedded - split into multiple lines
            my @lines = map( {
               # each line has timestamp, program name, test flag and maybe some text
               display_time(time()) . " $progname: $test_prefix$_\n";
               } split(m{\r?\n}, $arg));
            print @lines
               or die "Print to standard output failed ($OS_ERROR)"
               if $print_opt;
            $our_log_fh->print(@lines)
               or die "Print to log file $our_log_path failed ($OS_ERROR)"
               if $log_opt;
            push @our_mem_log, @lines;
         }
      }
   }
}

sub get_mem_log {
   return \@our_mem_log;
}

}

sub validate_ltapedev {
# confirm LTAPEDEV is OK
   my $onconfig_parms = shift; # reference to hash
   # validate LTAPEDEV - logical log backup file full path
   my $ltapedev = $onconfig_parms->{LTAPEDEV};
   log_die "Onconfig LTAPEDEV parameter is not defined"
      unless defined $ltapedev;
   log_die "Onconfig LTAPEDEV parameter is invalid. $ltapedev does not exist" 
      unless -e $ltapedev;
   log_die "Onconfig LTAPEDEV parameter is invalid. $ltapedev is not a plain file"
      unless -f $ltapedev;
   my (undef, $pathname, $filename) = splitpath($ltapedev);
   #  get any real file that ltapedev may indirectly specify
   my $real_path = realpath($pathname);
   log_die "Onconfig LTAPEDEV parameter target is invalid. $real_path does not exist" 
      unless -e $real_path;
   log_die "Onconfig LTAPEDEV parameter target is invalid. $real_path is not a directory"
      unless -d $real_path;
   return(
      $ltapedev,
      canonpath($pathname),
      $filename,
      $real_path,
      );
}

sub validate_tapedev {
# confirm TAPEDEV is OK
   my $onconfig_parms = shift; # reference to hash
   # validate TAPEDEV - level-0 physical backup file full path
   my $tapedev = $onconfig_parms->{TAPEDEV};
   log_die "Onconfig TAPEDEV parameter is not defined"
      unless defined $tapedev;
   log_die "Onconfig TAPEDEV parameter is invalid. $tapedev does not exist" 
      unless -e $tapedev;
   my $tapedev_stat = stat($tapedev) or
      log_die "Stat failed for entry $tapedev ($OS_ERROR)";
   log_die "Onconfig TAPEDEV $tapedev is not a plain file"
      unless S_ISREG $tapedev_stat->mode;
   my (undef, $pathname, $filename) = splitpath($tapedev);
   #  get any real file that tapedev may indirectly specify
   my $real_path = realpath($tapedev);
   log_die "Onconfig TAPEDEV parameter target is invalid. $real_path does not exist" 
      unless -e $real_path;
   # get a gzipped (.gz suffix) version if it exists
   my ($basename, $dirpath, $suffix) = fileparse($real_path, qr{\.[^.]*});
   log_die "Onconfig TAPEDEV parameter target is invalid. $dirpath is not a directory" 
      unless -d $dirpath;
   my $zip_path = catfile($dirpath, $basename . '.gz');
   my ($zip_stat, $zip_mtime, $zip_size);
   if (-e $zip_path) {
      $zip_stat = stat($zip_path)
         or log_die "Stat failed for entry $zip_path ($OS_ERROR)";
      log_die "$zip_path is not a plain file"
         unless S_ISREG $zip_stat->mode;
      $zip_mtime = $zip_stat->mtime;
      $zip_size = $zip_stat->size;
   } else {
      ($zip_path, $zip_mtime, $zip_size) = (undef, undef, undef);
   }
   return (
      $tapedev,
      canonpath($pathname),
      $filename,
      $tapedev_stat->mtime,
      $tapedev_stat->size,
      $real_path,
      $zip_path,
      $zip_mtime,
      $zip_size,
   );
}

{
# private to these subs
my $onconfig_path;

sub get_set_environment_variables {
# set up environment variables for IDS commands if not established
   $ENV{$informixdir_env_name} = $informixdir_default
      unless defined $ENV{$informixdir_env_name};
   $ENV{$informixserver_env_name} = $informixserver_default
      unless defined $ENV{$informixserver_env_name};
   $ENV{$onconfig_env_name} = $onconfig_file_default
      unless defined $ENV{$onconfig_env_name};
   # use canonpath() to clean up trailing delimiters
   my $informixdir = canonpath $ENV{$informixdir_env_name};
   log_die "$informixdir_env_name value $informixdir is not a directory"
      unless -d $informixdir;
   $ENV{$informixsqlhosts_env_name} = 
      catfile($informixdir,
              $informix_etc_subdir,
              $informixsqlhosts_file_default
             )
      unless defined $ENV{$informixsqlhosts_env_name};
   my $informix_bin = catdir($informixdir, $informix_bin_subdir);
   push @PATH, $informix_bin 
      unless grep {canonpath($_) eq $informix_bin} @PATH;
   $onconfig_path = catfile($informixdir,
                            $informix_etc_subdir,
                            $ENV{$onconfig_env_name}
                           );
   log_die "Onconfig file $onconfig_path is not a plain file"
      unless -f $onconfig_path;
}

sub parse_onconfig {
# process onconfig file
# captured parameters and values are stored in 
#  %onconfig_parms hash, keyed by parameter name
   my $onconfig_parms = shift; # reference to %onconfig_params
   my ($pname, $pvalue, $pnum);
   my $onc_line_num = 0;
   my $onconfig_fh = IO::File->new($onconfig_path, '<')
      or log_die "Cannot open $onconfig_path ($OS_ERROR)";
   # onconfig file lines can be comments or blank
   # parameter lines are of this format:
   # PARAMETER_NAME parameter_value #optional comment
   # names, values and comments are separated by whitespace
   # Parameter names must be uppercase
   for my $onconfig_line (<$onconfig_fh>) {
      $onc_line_num++;
      chomp $onconfig_line;
      my $onc_line = $onconfig_line;    # the line gets munged; keep original mostly intact
      next if $onc_line =~ m{^\s+#};    # skip comment lines
      $onc_line =~ s{#.*$}{};           # strip trailing comments
      $onc_line =~ s{\s+$}{};           # strip trailing whitespace
      next if $onc_line =~ m{^$};       # skip blank lines (empty by now)
      # number of list items, the two items we care about
      $pnum = ($pname, $pvalue) = $onc_line =~
         m{
            ^                           # beginning of string/line
            ([[:upper:][:digit:]_]+)    # capture uppercase letters, digits, underscores
            \s+                         # whitespace
            (\S+)                       # capture nonwhitespace characters
            $                           # end of string/line
         }x;
      if ($pnum != 2) {                 # both captures must be successful
#         log_warn 'Ignoring invalid onconfig file line ' .
#              "(#$onc_line_num): \"$onconfig_line\"";
         next;
      }
      $onconfig_parms->{$pname} = $pvalue; # stash parameter, value in hash
   }
   $onconfig_fh->close
      or log_die "Cannot close $onconfig_path ($OS_ERROR)";
}
}

{
# private to these subs
my $which_name;
my $which_path;

sub locate_cmd {
# returns full path of command
   my $command_name = shift;
   unless (defined $which_path) {
      $which_name = 'which';
      $which_path = '/usr/bin/which';
      log_die "\"$which_name\" command was not found at $which_path"
         unless -x $which_path;
   }
   my $whichout = qx{$which_path $command_name 2>/dev/null};
   unless ($CHILD_ERROR) {
      chomp $whichout;
      return $whichout;
   } else {
      log_die "$command_name was not found";
   }
}
}

{
# private to these subs
my @signame;
my %signo;

sub set_signal_data {
# set up arry and hash for signal name<->number conversion
    defined $Config{sig_name} or log_die 'No sigs?';
    my $i = 0;
    for my $name (split(' ', $Config{sig_name})) {
        $signo{$name} = $i;
        $signame[$i] = $name;
        $i++;
    }
}

sub get_signal_number {
# convert signal name to number
   return $signo{$_[0]};
}

sub get_signal_name {
# convert signal number to name
   return $signame[$_[0]];
}

}

sub display_time {
   return strftime('%Y-%m-%d %H:%M:%S', localtime($_[0]));
}

sub chown_informix {
   my ($iuid, $igid) = (getpwnam 'informix')[2, 3];
   my $file = shift;
   my $st = stat($file)
      or log_die "Can't stat $file";
   ($st->uid() == $iuid && $st->gid() == $igid) ? 1 : chown $iuid, $igid, $file;
}

{
# private to these subs
my %mail_info = (
#   mailhost => '',
#   from => '',
   to => [],
   cc => [],
#   subject => '',
);

sub set_mail_host {
   $mail_info{mailhost} = $_[0];
}

sub set_mail_from {
   $mail_info{from} = $_[0];
}

sub set_mail_to {
   push @{$mail_info{to}}, @_;
}

sub set_mail_cc {
   push @{$mail_info{cc}}, @_;
}

sub set_mail_subject {
   $mail_info{subject} = $_[0];
}

sub send_mail {
   my $mo = Net::SMTP->new($mail_info{mailhost}, Debug=>0)
      or die "Failed to connect to $mail_info{mailhost} to send mail\n";
   $mo->mail($mail_info{from})
      or die "$mail_info{mailhost} did not accept sender $mail_info{from}\n";
   for my $recipient (@{$mail_info{to}}, @{$mail_info{cc}}) {
      $mo->recipient($recipient)
         or die "$mail_info{mailhost} did not accept recipient $recipient\n";
   }
   $mo->data(
      @{$mail_info{to}} ? 'To: ' . join(', ', @{$mail_info{to}}) . "\n" : (),
      @{$mail_info{cc}} ? 'Cc: ' . join(', ', @{$mail_info{cc}}) . "\n" : (),
      "From: $mail_info{from}\n",
      'Subject: ' . $mail_info{subject} . "\n",
      "\n",
      map({$_ =~ m{\n\Z} ? $_ : "$_\n"} @_),
   );
   $mo->quit();
}

}

{
# private to these subs
my $state_file;
my $state_fh;
my $state_pos;
my $state_open = 0;

sub set_running_state {
   my $success;
   $state_file = $progname . '.state';
   my $open_mode = -f $state_file ? '+<' : '+>';
   $state_fh = IO::File->new($state_file, $open_mode)
      or log_die "Cannot open state file $state_file ($OS_ERROR)";
   $state_open = 1;
   if (flock $state_fh, LOCK_EX | LOCK_NB) {
      $state_pos = $state_fh->tell;
      my $state = $state_fh->getline;
      if (defined($state)) {
         chomp($state);
      } else {
         $state = '';
      }
      if ($state eq 'running') {
         flock($state_fh, LOCK_UN)
            or log_die "Cannot unlock state file $state_file ($OS_ERROR)";
         $state_fh->close
            or log_die "Cannot close state file $state_file ($OS_ERROR)";
         $state_open = 0;
         $success = 0;
      } else {
         $state_fh->truncate(0)
            or log_die "Cannot truncate state file $state_file ($OS_ERROR)";
         $state_fh->seek($state_pos, SEEK_SET)
            or log_die "Cannot position state file $state_file ($OS_ERROR)";
         $state_fh->print("running\n")
            or log_die "Cannot write state file $state_file ($OS_ERROR)";
         $state_fh->flush
            or log_die "Cannot flush state file $state_file ($OS_ERROR)";
         $success = 1;
      }
   } else {
      $state_fh->close
         or log_die "Cannot close state file $state_file ($OS_ERROR)";
      $state_open = 0;
      $success = 0;
   }
   log_die "Unable to set exclusive execution state. Perhaps another execution of $progname is active."
      unless $success;
   return $success;
}

sub set_stopped_state {
   if ($state_open) {
      $state_fh->truncate(0)
         or log_die "Cannot truncate state file $state_file ($OS_ERROR)";
      $state_fh->seek($state_pos, SEEK_SET)
         or log_die "Cannot position state file $state_file ($OS_ERROR)";
      $state_fh->print("stopped\n")
         or log_die "Cannot write state file $state_file ($OS_ERROR)";
      flock($state_fh, LOCK_UN)
         or log_die "Cannot unlock state file $state_file ($OS_ERROR)";
      $state_fh->close
         or log_die "Cannot close state file $state_file ($OS_ERROR)";
      $state_open = 0;
   }
   return 1;
}

}

{
# private to these subs
my @warn_log;

sub log_warn {
   push @warn_log, @_;
   log_print @_;
   warn map {"$_\n"} @_
     unless $mail_opt;
}

sub log_die {
   push @warn_log, @_;
   log_print @_;
   at_exit;
   die map {"$_\n"} @_;
}

sub at_exit {
   stop_logging;
   send_mail(
      "Problem(s) occurred during the execution of $progname on @{[hostname()]}:",
      @warn_log,
      @{get_mem_log()} ? ('', "Log:", @{get_mem_log()}) : (),
   ) if $mail_opt and @warn_log;
   set_stopped_state;
}

}
1;
