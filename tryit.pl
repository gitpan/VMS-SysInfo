use VMS::SysInfo;

#$foo = VMS::SysInfo::get_all_sys_info_items("PLUTO");

#foreach $keys (sort(keys %$foo)){
#print $keys, "=", $foo->{$keys};
#print "\n";
#}

#print "\n------\n";

$foo = VMS::SysInfo::get_all_sys_info_items();

foreach $keys (sort(keys %$foo)){
print $keys, "=", $foo->{$keys};
print "\n";
}

if ($foo->{DECIMAL_EMULATED}) {
print "decimal_emulated = yes\n"} else {
print "decimal_emulated = no\n"}

