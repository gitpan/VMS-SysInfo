package VMS::SysInfo;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require DynaLoader;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();
@EXPORT_OK = qw(&sys_info_names        &get_all_sys_info_items
                &get_one_sys_info_item &decode_sys_info_bitmap
                &sys_parm_names        &get_all_sys_parm_items
                &get_one_sys_parm_item &decode_sys_parm_bitmap);
$VERSION = '0.03';

bootstrap VMS::SysInfo $VERSION;

# Preloaded methods go here.
sub new {
  my($pkg,$node) = @_;
  my $self = { __NODE => $node };
  bless $self, $pkg; 
}

sub one_info { get_one_sys_info_item($_[0]->{__NODE}, $_[1]); }
sub all_info { get_all_sys_info_items($_[0]->{__NODE}) }

sub TIEHASH { my $obj = new VMS::SysInfo @_; $obj; }
sub FETCH   { $_[0]->one_info($_[1], $_[0]->{__NODE}); }
sub EXISTS  { grep(/$_[1]/, sys_info_names($_[0]->{__NODE})) }

# Can't STORE, DELETE, or CLEAR--this is readonly. We'll Do The Right Thing
# later, when I know what it is...
#sub STORE   {
#  my($self,$priv,$val) = @_;
#  if (defined $val and $val) { $self->add([ $priv ],$self->{__PRMFLG});    }
#  else                       { $self->remove([ $priv ],$self->{__PRMFLG}); }
#}
#sub DELETE  { $_[0]->remove([ $_[1] ],$_[0]->{__PRMFLG}); }
#sub CLEAR   { $_[0]->remove([ keys %{$_[0]->current_privs} ],$_[0]->{__PRMFLG}) }

sub FIRSTKEY {
  $_[0]->{__SYS_INFO_ITERLIST} = [ sys_info_names($_[0]->{__NODE}) ];
  $_[0]->one_info(shift @{$_[0]->{__SYS_INFO_ITERLIST}},$_[0]->{__NODE} );
}
sub NEXTKEY { $_[0]->one_info(shift @{$_[0]->{__SYS_INFO_ITERLIST}}, $_[0]->{__NODE}); }

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

VMS::SysInfo - Perl extension to retrieve lots of system info for a node.

=head1 SYNOPSIS

  use VMS::SysInfo;

VMS::SysInfo will can access either system info for any node in the cluster
(what info is available depends on whether you're local to the node being
accessed or not), or parameters set by SYSGEN for the local node.

Routine to return a reference to a hash with all the system info for the
node loaded into it:

  $SysInfo = VMS::SysInfo::get_all_sys_info_items([nodename]);
  $archtype = $SysInfo->{ARCH_TYPE};

  $SysParm = VMS::SysInfo::get_all_sys_parm_items();
  $Channelcnt = $SysInfo->{CHANNELCNT}

Fetch a single piece of info:

  $archtype = VMS::SysInfo::get_one_sys_info_item("ARCH_TYPE"[, nodename]);
  $ChannelCnt = VMS::SysInfo::get_one_sys_parm_item("CHANNELCNT");

Decode a bitmap into a hash filled with names, with their values set to
true or false based on the bitmap.

  $hashref = VMS::SysInfo::decode_sys_info_bitmap("ARCHFLAGS", Bitmap);
  $hashref = VMS::SysInfo::decode_sys_parm_bitmap(<some bitmapped parameter>);

Get a list of valid info names:

  @InfoNames = VMS::SysInfo::sys_info_names(<nodename>);
  @ParmNames = VMS::SysInfo::sys_parm_names();

Tied hash interface (Info items only, not system parameters):
  
  tie %SysInfohash, VMS::SysInfo<, nodename>;
  $diolm = $SysInfohash{ARCH_TYPE};

Object access (Info items only, not system parameters):

  $SysInfoobj = new VMS::SysInfo <nodename>;
  $archtype = $SysInfoobj->one_info("ARCH_TYPE");
  $hashref = $SysInfoobj->all_info();

=head1 DESCRIPTION

Retrieve info for a node. Access is via function call, object and method,
or tied hash. Choose your favorite.

Note that this module does not completely duplicate the DCL F$GETSYI
lexical function. Quick rule of thumb is only single pieces of info are
returned.

=head1 BUGS

May leak memory. May not, though.

=head1 LIMITATIONS

Quadword and hexword values are returned as string values rather than
integers.

List info (like rightslists) is not returned.

The decode bitmap function doesn't currently decode anything.

You can't get all system info for all nodes in the cluster. This is a VMS
limitation.

You can't get system parameter info for non-local cluster nodes. This is
also a VMS limitation.

You can't access system parameters via the tied hash or the object
interface. This'll likely change later.

=head1 AUTHOR

Dan Sugalski <sugalsd@lbcc.cc.or.us>

=head1 SEE ALSO

perl(1), VMS::ProcInfo.

=cut
