package Unicode::Lite;

use 5.005_62;
use strict;
use warnings;
use base qw/Exporter/;
use Carp qw/croak carp/;

our @EXPORT  = qw(convert convertor addequal UL_CHR UL_ENT UL_EQV UL_SEQ UL_7BT UL_ALL);
our $VERSION = 0.04;
our %MAPPING;
our %CONVERT;
our %EQUIVAL;

#use enum qw/BITMASK: RP_CHR RP_ENT EQ_CHR EQ_SEQ EQ_7BT/;
use constant RP_CHR => 0x01;
use constant RP_ENT => 0x02;
use constant EQ_CHR => 0x04;
use constant EQ_SEQ => 0x08;
use constant EQ_7BT => 0x10;

use constant UL_CHR => RP_CHR;          # REPLACE TO CHAR   (default <Space>)
use constant UL_ENT => RP_CHR | RP_ENT; # REPLACE TO ENTITY (like    &#0000;)
use constant UL_EQV => EQ_CHR;          # EQUIVALENT char
use constant UL_SEQ => EQ_CHR | EQ_SEQ; # EQUIVALENT sequence of chars
use constant UL_7BT => EQ_7BT | UL_SEQ; # EQUIVALENT sequence of 7bit chars
use constant UL_ALL => UL_CHR | UL_ENT | UL_EQV | UL_SEQ;

#use enum qw/nil dst src all/;
use constant nil => 0x0;
use constant src => 0x1;
use constant dst => 0x2;
use constant all => 0x3;
use constant uni => qr/^utf16|utf8|utf7|ucs4|uchr|uhex|latin1$/;

sub convertor($$;$$)
{
    my ($src, $dst, $mod, $chr) = (lc shift, lc shift, shift||0, shift||'');

    return $CONVERT{$src}{$dst}{$mod}{$chr} if exists
           $CONVERT{$src}{$dst}{$mod}{$chr};
    require 'Unicode/String.pm' unless defined %Unicode::String::;

    my  ($SRC, $DST) = ($src, $dst);
    for ($SRC, $DST){
        next if $_=~uni or s/^ucs2|unicode$/utf16/o or s/^iso-8859-1$/latin1/o;
        next if exists $MAPPING{$_};
        require "Unicode/Map.pm" unless defined %Unicode::Map::;
        $_ = lc new Unicode::Map->id( uc $_ ) ||
            croak "Character Set '$_' not defined!";
        $_ = 'latin1' if $_ eq 'iso-8859-1';
    }

    return $CONVERT{$src}{$dst}{$mod}{$chr} =
           $CONVERT{$SRC}{$DST}{$mod}{$chr} if exists
           $CONVERT{$SRC}{$DST}{$mod}{$chr};

    my $map = ($SRC !~ uni) | ($DST !~ uni) << 1;

    for ([$src, $SRC, $map&src], [$dst, $DST, $map&dst]){
        next unless $$_[2] and !$MAPPING{$$_[0]};
        $MAPPING{$$_[0]} = $MAPPING{$$_[1]} ||
       ($MAPPING{$$_[1]} = new Unicode::Map($$_[1])) ||
        croak "Can't create Unicode::Map object for '$$_[1]' charset!";
    }

    $map = all if $mod & EQ_7BT and
        $map == src && $DST eq 'latin1' or
        $map == dst && $SRC eq 'latin1' or
        $map == nil && $SRC eq 'latin1' && $DST eq 'latin1';

    # Situation checking
    croak "FLAG param can be only for SBCS->SBCS!" if $map != all and $mod;
    croak "CHAR param can be only for SBCS->SBCS!" if $map != all and length $chr;
    croak "Can't convert to the same codepage!"    if $SRC eq $DST and
                                                      $map != all || not $mod & EQ_7BT;
    my $mutator;
    if ($map != all){
        $mutator =
            ($map & src) ? "\$MAPPING{'$SRC'}->to_unicode(\$_)" :
            ($map & dst) ? "\$_" : "Unicode::String::$SRC(\$_)" .
            ($SRC ne 'utf16' && $DST ne 'utf8' ? '->utf16' : '' );
        $mutator =
            ($map & dst) ? "\$MAPPING{'$DST'}->from_unicode($mutator)" :
            ($map & src) ? "Unicode::String::utf16($mutator)->$DST" :
            $mutator."->$DST" if $DST ne 'utf16';
        $mutator = '$_='.$mutator;
    }
    else{ $mutator = __sbcs_convertor($SRC, $DST, $mod, $chr) }
    #warn "$mutator\n";

    return
        $CONVERT{$src}{$dst}{$mod}{$chr} =
        $CONVERT{$SRC}{$DST}{$mod}{$chr} = eval 'sub(;$){
        my $str = @_ ? $_[0] : defined wantarray ? $_ : \$_;
        for( ref$str?$$str:$str ){ if(length){'.$mutator.'}
        return $_ if defined wantarray}
        $_ = $str if defined $_[0] and not ref $str }';
}

sub convert($$;$$$){
    my $fn = convertor( shift, shift, $_[1], $_[2] );
    goto &$fn;
}

sub addequal(@)
{
    return unless
    my @chr = map{
        my @a = map hex, split /\+/;
        $#a ? \@a : $a[0];
    }$#_ ? @_ : split /\s+/, shift;

    return unless $#chr;

    $EQUIVAL{shift @chr} = \@chr;

    @chr = map{
        (ref || !exists $EQUIVAL{$_}) ? $_ :
        ($_, @{$EQUIVAL{$_}})
    }@chr;
}

sub __sbcs_convertor($$$$)
{
    my ($src, $dst, $mod, $chr) = (shift, shift, shift, shift);
    my (@src, %src, @dst, %dst, @dif, %dif);

    croak "Unknown flags: $mod!"      if $mod & ~(UL_ALL|UL_7BT);
    croak "CHAR and UL_ENT together!" if length $chr and $mod & RP_ENT;

    $chr = length($chr) ? substr($chr,0,1) : '?' if
        $mod & RP_CHR and not $mod & RP_ENT;

    # fill charsets arrays with U+0000
    for ([$src, \@src], [$dst, \@dst]){
        my $conv = convertor( $$_[0], 'utf16' );
        @{$$_[1]} = map {&$conv(); $_ ? unpack 'n', $_ : 0} map chr, 0x80..0xff;
    }

    my $find = sub(){
        my $chr = $src[$_];
        return 0 unless exists $EQUIVAL{$chr};
        LOOP:
        for (@{$EQUIVAL{$chr}}){
            if (!ref){ next LOOP unless $_ < 0x80 or exists $dst{$_}; return $_ }
            next unless $mod & EQ_SEQ;
            for (@$_){ next LOOP unless $_ < 0x80 or exists $dst{$_}} return $_;
        }
        return 0;
    };

    @dst = (0) x 0x80        if $mod & EQ_7BT;
    @src{@src} = 0x80..0xff  if $mod &~RP_CHR;
    @dst{@dst} = 0x80..0xff;

    # collect positions of unused chars
    if ($mod & ~UL_CHR){                # if need indirect replace
        for (0 .. $#dst){
        push @dif, $_ + 0x80 if
            !$dst[$_] or                # char not used in dst codepage
            !exists $src{$dst[$_]}      # char not used in src codepage
        }
    }

    # read equivalent rules
    if ($mod & UL_EQV and not %EQUIVAL){
        local $_;
        while (<DATA>){ s/\s*#.*//so; addequal($_); }
    }

    my (@map, @eqv, @ent, @chr, @del);

    for (0 .. $#src)
    {
        next if !$src[$_] or            # char not used in src codepage
                 $src[$_] == $dst[$_];  # chars in src and dst maps are equal

        if( exists $dst{$src[$_]} ){
            push @map, [$_, $src[$_]];

        }elsif( $mod & EQ_CHR and my $uni = &$find ){
            next if not ref $uni and
            push @map, [$_, $uni];
            push @eqv, [$_, $uni];

        }elsif( $mod & RP_ENT ){
            push @ent, [$_, $src[$_]];

        }elsif( $mod & RP_CHR ){
            push @chr, $_;

        }else{
            push @del, $_;

        }
    }

    croak "Internal ERROR: not enough additional chars!\n" if @ent + @eqv > @dif;

    ($src, $dst) = ('') x 2;

    $src .= chr $$_[0] + 0x80,
    $dst .= chr($$_[1] < 0x80 ? $$_[1] : $dst{$$_[1]})
                                for @map;
    for (@ent){
        $src .= chr $$_[0] + 0x80;
        $dst .= $$_[0] = chr shift @dif;
    }

    for (@eqv){
        $src .= chr $$_[0] + 0x80;
        $dst .= $$_[0] = chr shift @dif;
        $$_[1] = join '', map{
            chr( $_ < 0x80 ? $_ : $dst{$_} )
        }@{$$_[1]};
        $$_[1] =~ s/([\-\\\/\$])/\\$1/gso;
    }
    $src .= chr $_ + 0x80       for @chr;
    $dst .= $chr x(@del?@chr:1) if  @chr;
    $src .= chr $_ + 0x80       for @del;

    s/(?=[-\\\[\]])/\\/gso      for $src, $dst;

    my
    $res = "tr\n[$src]\n[$dst]" . (@del?'d':'');
    $res.= ";s/$$_[0]/&#$$_[1];/g" for @ent;
    $res.= ";s/$$_[0]/$$_[1]/g"    for @eqv;

    return $res;
}

1;

=head1 NAME

Unicode::Lite - Library for easy charset convertion

=head1 SYNOPSIS

 use Unicode::Lite;

 print convert( 'latin1', 'unicode', "hello world!" );

 local *lat2uni = convertor( 'latin1', 'unicode' );
 print lat2uni( "hello world!" );

 my $lat2uni = convertor( 'latin1', 'unicode' );
 print &$lat2uni( "hello world!" );

=head1 DESCRIPTION

This module includes string converting function from one and to another
charset. Requires installed Unicode::String and Unicode::Map packages.

Supported unicode charsets: unicode, utf16, ucs2, utf8, utf7, ucs4,
uchr, uhex.

Supported Single-Byte Charsets (SBCS): latin1 and all installed maps in 
Unicode::Map package.

=head1 FUNCTIONS

=over 4

=item B<convertor> SRC_CP DST_CP [FLGS] [CHAR]

Creates convertor function and returns reference to her, for further
fast direct call.

The param FLGS operates replacing by SBCS->SBCS converting if any char
from SRC_CP is absent at DST_CP. The order of search of substitution:

 UL_7BT - to equivalent 7bit char or sequence of 7bit chars
 UL_SEQ - to equivalent char or sequence of chars
 UL_EQV - to equivalent char

 UL_ENT - to entity - &#0000;
 UL_CHR - to [CHAR].
 UL_ALL - UL_SEQ or UL_EQV and UL_ENT or UL_CHR

If flag UL_CHR or UL_ENT is not specified, absent chars will be deleted.
Param CHAR used for replacing of absent chars. If CHAR is not specified,
will be used '?' char.

If you are getting message "Character Set '' not defined!", run the 
script test.pl from distribution.

=item B<convert> SRC_CP DST_CP [VAR] [FLGS] [CHAR]

Convert VAR from SRC_CP codepage to DST_CP codepage and returns
converted string.

=item B<addequal> UNICODES...

The function adds a rule for equivalent char finding. Params is a list of
hex unicodes of chars. For substitution on a sequence of characters,
the codes of characters need to be connected in character '+'.

 addequal( qw/2026 2E+2E+2E 3A/ ); # ELLIPSIS ... :

Note! Work of rules for finding of equivalent char is cascade:

 2500 002D      # - -
 2550 2500      # = -

 2550 2500 002D # = - -

=back

 The following rules are correct for converting functions:

 VAR may be SCALAR or REF to SCALAR.
 If VAR is REF to SCALAR then SCALAR will be converted.
 If VAR is omitted, uses $_.
 If function called to void context and VAR is not REF then result placed to $_.

=head1 EXAMPLES

 $_ = "dr�ben, Stra�e";
 convert 'latin1', 'latin1', $_, UL_7BT;
 convert 'latin1', 'latin2', $_, UL_SEQ|UL_CHR, '?';
 convert 'latin1', 'latin2', $_, UL_SEQ|UL_ENT, '?';

 # EQVIVALENT CALLS:

 local *lat2uni = convertor( 'latin1', 'unicode' );

 lat2uni( $str );        # called to void context -> result placed to $_
 $_ = lat2uni( $str );

 lat2uni( \$str );       # called with REF to string -> direct converting
 $str = lat2uni( $str );

 lat2uni();              # with omitted param called -> $_ converted
 lat2uni( \$_ );
 $_ = lat2uni( $_ );

=head1 AUTHOR

Albert MICHEEV <amichauer@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2000, Albert MICHEEV

This module is free software; you can redistribute it or modify it
under the same terms as Perl itself.

=head1 AVAILABILITY

The latest version of this library is likely to be available from:

http://www.perl.com/CPAN

=head1 SEE ALSO

Unicode::String, Unicode::Map.

=cut

__DATA__

# LATIN 1
00C4 41+65 # A"    Ae
00D6 4F+65 # O"    Oe
00DC 55+65 # U"    Ue
00E4 61+65 # a"    ae
00F6 6F+65 # o"    oe
00FC 75+65 # u"    ue
00DF 73+73 # szet  ss

# CYRILLIC
0410 41    # A     A
0411 42    # BE    B
0412 56    # VE    V
0413 47    # GHE   G
0414 44    # DE    D
0415 45    # IE    E
0401 59+4F # IO    YO
0416 5A+48 # ZHE   ZH
0417 5A    # ZE    Z
0418 49    # I     I
0419 4A    # J     J
041A 4B    # KA    K
041B 4C    # EL    L
041C 4D    # EM    M
041D 4E    # EN    N
041E 4F    # O     O
041F 50    # PE    P
0420 52    # ER    R
0421 53    # ES    S
0422 54    # TE    T
0423 55    # U     U
0424 46    # EF    F
0425 58    # HA    X
0426 43    # TSE   C
0427 43+48 # CHE   CH
0428 53+48 # SHA   SH
0429 57    # SHCHA W
042A 7E    # HARD  ~
042B 59    # YERU  Y
042C 27    # SOFT  '
042D 45+27 # E     E'
042E 59+55 # YU    YU
042F 59+41 # YA    YA
0430 61    # a     a
0431 62    # be    b
0432 76    # ve    v
0433 67    # ghe   g
0434 64    # de    d
0435 65    # ie    e
0451 79+6F # io    yo
0436 7A+68 # zhe   zh
0437 7A    # ze    z
0438 69    # i     i
0439 6A    # j     j
043A 6B    # ka    k
043B 6C    # el    l
043C 6D    # em    m
043D 6E    # en    n
043E 6F    # o     o
043F 70    # pe    p
0440 72    # er    r
0441 73    # es    s
0442 74    # te    t
0443 75    # u     u
0444 66    # ef    f
0445 78    # ha    x
0446 63    # tse   c
0447 63+68 # che   ch
0448 73+68 # sha   sh
0449 77    # shcha w
044A 7E    # hard  ~
044B 79    # yeru  y
044C 27    # soft  '
044D 65+27 # e     e'
044E 79+75 # yu    yu
044F 79+61 # ya    ya

# ANGLE QUOTATION MARK
008B 3C    # SINGLE LEFT  <
009B 3E    # SINGLE RIGHT >
00AB 3C+3C # DOUBLE LEFT  <<
00BB 3E+3E # DOUBLE RIGHT >>

# SIGNS
00B2 28+32+29 # SUPERSCRIPT2 (2)
00B3 28+33+29 # SUPERSCRIPT3 (3)
00B9 28+31+29 # SUPERSCRIPT1 (1)
00A9 28+63+29 # COPYRIGHT  c (c)
00AE 28+72+29 # REGISTERED R (r)
2026 2E+2E+2E # ELLIPSIS     ...
0192 28+66+29 # FUNCTION     (f)
2122 28+74+6D+29 # TRADE MARK T (tm)

00BD 31+2F+32 # 1/2
2153 31+2F+33 # 1/3
2154 32+2F+33 # 2/3
00BC 31+2F+34 # 1/4
00BE 33+2F+34 # 3/4
2155 31+2F+35 # 1/5
2156 32+2F+35 # 2/5
2157 33+2F+35 # 3/5
2158 34+2F+35 # 4/5
2159 31+2F+36 # 1/6
215A 35+2F+36 # 5/6
215B 31+2F+38 # 1/8
215C 33+2F+38 # 3/8
215D 35+2F+38 # 5/8
215E 37+2F+38 # 7/8

00BF 3F   # INVERTED      ?
00A8 22   # DIAERESIS     "
00D7 78   # MULTIPLY      x
00F7 27   # DEVISION      /
221A 56   # SQUARE ROOT � V
25A0 6F   # BLACK SQUAR � o
00B0 6F   # DEGREE      � o
2219 2E   # BULLET       .
00B7 2E   # MIDDLE DOT  � .
02dc 7E   # SMALL TILDE   ~
2013 2D   # EN DASH       -
2014 2D   # EM DASH       -
2018 27   # SINGLE LEFT '
2019 27   # SINGLE RIGH '
201A 27   # SINGLE LOW9 '
201C 22   # DOUBLE LEFT "
201D 22   # DOUBLE RIGH "
201E 22   # DOUBLE LOW9 "
00AC 2510 #             � �
00B1 2B+2C# PLUS_MINUS   +-
2030 25+25# PER MILLE    %%
2248 7E+3D# ALMOST EQUAL ~=
2260 21+3D# NOT EQUAL TO !=
2261 3D+3D# IDENTICAL    ==
2264 3C+3D# LESS | EQUAL <=
2265 3E+3D# GREAT| EQUAL >=

# BLOCK
2588 42   # � B
258C 7C   # � |
2590 7C   # � |
2580 2D   # � -
2584 2D   # � -

# SHADE
2591 2588 # � �
2592 2588 # � �
2593 2588 # � �

# BOX DRAWINGS
2502 7C   # � |
2500 2D   # � -
253C 2B   # � +
250C 2F   # � /
2514 5C   # � \
2510 AC 5C# ��\
2518 2F   # � /
252C 2500 # � �
2534 2500 # � �
251C 2502 # � �
2524 2502 # � �

2551 2502 # � �
2550 2500 # � �
256C 253C # � �
2554 250C # � �
255A 2514 # � �
2557 2510 # � �
255D 2518 # � �
2566 252C # � �
2569 2534 # � �
2560 251C # � �
2563 2524 # � �

256B 256C # � �
2553 2554 # � �
2559 255A # � �
2556 2557 # � �
255C 255D # � �
2565 2566 # � �
2568 2569 # � �
255F 2551 # � �
2562 2551 # � �

256A 253C # � �
2552 250C # � �
2558 2514 # � �
2555 2510 # � �
255B 2518 # � �
2564 252C # � �
2567 2534 # � �
255E 251C # � �
2561 2524 # � �
