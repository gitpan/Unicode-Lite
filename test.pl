use Unicode::Map;
$\ = "\n\n";
$_ = 'value';

my $map = new Unicode::Map();
unless($_ eq 'value'){ print <DATA> }
else  { print "The Module 'Unicode::Map' OK!" }



use Unicode::Lite;
$Unicode::Lite::TEST = 1;


$_ = "drüben, Straße";

print convert( 'latin1', 'utf8' );
print convert( 'latin1', 'utf7' );
print convert( 'latin1', 'ucs2' );
print convert( 'latin1', 'ucs4' );

convert( 'latin1', 'utf8' );

print convert( 'utf8', 'latin1' );
print convert( 'utf8', 'unicode' );
print convert( 'utf8', 'utf7' );

convert( 'utf8', 'utf16' );

print convert( 'utf16', 'latin1' );
print convert( 'utf16', 'utf7' );




$_ = "¯à¨¢¥â ñ¦¨ª¨!";

print convert( 'ibm866', 'utf8' );
print convert( 'ibm866', 'utf7' );
print convert( 'ibm866', 'ucs2' );
print convert( 'ibm866', 'ucs4' );

convert( 'ibm866', 'utf8' );

print convert( 'utf8', 'ibm866' );
print convert( 'utf8', 'utf16' );

convert( 'utf8', 'utf16' );

print convert( 'utf16', 'utf8' );
print convert( 'utf16', 'ibm866' );

convert( 'utf16', 'windows-1251' );

print convert 'windows-1251', 'ibm866';
print convert 'windows-1251', 'latin1';
print convert 'windows-1251', 'latin1', $_, UL_7BT;


__DATA__

The module Unicode::Map has bug!
To fix bug it, add BUGFIXER LINE at perl/site/lib/Unicode/Map.pm
                   vvvvvvvvvvvvv

    sub _load_registry 
    {
         local $_; # !!! BUGFIXER LINE

