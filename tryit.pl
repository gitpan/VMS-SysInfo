use VMS::SysInfo;

$foo = VMS::SysInfo::get_all_sys_info_items("CEDAR");

foreach $keys (sort(keys %$foo)){
print $keys, "=", $foo->{$keys};
print "\n";
}

print "\n------\n";

$foo = VMS::SysInfo::get_all_sys_parm_items();

foreach $keys (sort(keys %$foo)){
print $keys, "=", $foo->{$keys};
print "\n";
}
