use Unicode::Map;

$_ = 'value';
my $map = new Unicode::Map();
die <DATA> unless $_ eq 'value';

__DATA__

The module Unicode::Map has bug!
To fix bug, add BUGFIXER LINE.
                vvvvvvvvvvvvv

    sub _load_registry 
    {
         local $_; # !!! BUGFIXER LINE

