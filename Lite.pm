package Unicode::Lite;

use 5.005_02;
use strict;
use Exporter;

$Unicode::Lite::VERSION   = '0.01';
@Unicode::Lite::ISA       = qw(Exporter);
@Unicode::Lite::EXPORT_OK = qw(convert convertor);

sub convert($$;$){
    my $fn = convertor( shift, shift );
    goto &$fn;
}

sub convertor($$){
    my ($src, $dst, $map) = (shift, shift, 0);

    return $Unicode::Lite::Convertors{$src}{$dst} if
        defined $Unicode::Lite::Convertors{$src}{$dst};

    require "Unicode/String.pm" unless defined %Unicode::String::;

    for( $src, $dst )
    {
        $map <<= 1;

        next if
            s/^utf16|utf8|utf7|ucs4|latin1|uchr|uhex$/\L$_/i or
            s/^ucs2|unicode$/utf16/i;

        $map |= 1;

        require "Unicode/Map.pm" unless defined %Unicode::Map::;

        my $cs = $_; # Unicode::Map bugfixer

        $Unicode::Lite::Map{''} = new Unicode::Map() unless
            defined $Unicode::Lite::Map{''};

        $_ = $cs;    # Unicode::Map bugfixer

        $_ = $Unicode::Lite::Map{''}->_real_id( $_ ) ||
            warn "Character Set '$_' not defined!\n";

        $Unicode::Lite::Map{$_} = new Unicode::Map( $_ );
    }

    die "Can't convert to the same codepage!\n" if $src eq $dst;

    return $Unicode::Lite::Convertors{$src}{$dst} if
        defined $Unicode::Lite::Convertors{$src}{$dst};

    my $mut = sprintf( $map & 2 ? '$Unicode::Lite::Map{%s}->to_unicode' :
        'Unicode::String::%s', $src ).'(ref$str?$$str:$str)';

    $mut = $map & 1 ?
        sprintf( '$Unicode::Lite::Map{%s}->from_unicode(%s%s)',
            $dst, $mut, $map&2 ? '' : '->utf16' ) :
        $dst eq 'utf16' && $map&2 ? $mut :
        ($map&2 ? "Unicode::String::utf16($mut)" : $mut)."->$dst";

    return $Unicode::Lite::Convertors{$src}{$dst} = eval sprintf
        q/sub(;$){
        my $str = scalar @_ ? $_[0] : defined wantarray ? $_ : \$_;
        ref$str?$$str:$str = %s if length ref$str?$$str:$str;
        return ref$str?$$str:$str if defined wantarray;
        $_ = $str if defined $_[0] and not ref $str;}/, $mut;
}

1;

__END__

=head1 NAME

Unicode::Lite - Library for easy charset convertion

=head1 SYNOPSIS

 use Unicode::Lite qw/convert convertor/;

 print convert( 'ibm866', 'unicode', "hello world!" );

 local *ibm2uni = convertor( 'ibm866', 'unicode' );
 print ibm2uni( "hello world!" );

 my $ibm2uni = convertor( 'ibm866', 'unicode' );
 print &$ibm2uni( "hello world!" );

=head1 DESCRIPTION

This module includes string converting function from one and to another
charset. Requires installed Unicode::String and Unicode::Map packages.

Supported unicode charsets: unicode, utf16, ucs2, utf8, utf7, ucs4,
latin1, uchr, uhex.

Supported single-byte charsets: all installed maps in Unicode::Map package.

=head1 FUNCTIONS

=over 4

=item B<convert> SRC_CP, DST_CP, [VAR]

Convert VAR from SRC_CP codepage to DST_CP codepage and returns
converted string.

=item B<convertor> SRC_CP, DST_CP

Creates convertor function and returns reference to her, for further
fast direct call.

=back

 The following rules are correct for converting functions:

 VAR may be SCALAR or REF to SCALAR.
 If VAR is REF to SCALAR then SCALAR will be converted.
 If VAR is omitted, uses $_.
 If function called to void context and VAR is not REF
 then result placed to $_.

=head1 EXAMPLES

 local *ibm2uni = convertor( 'ibm866', 'unicode' );


 # EQVIVALENT CALLS:

 ibm2uni( $str );        # called to void context -> result placed to $_
 $_ = ibm2uni( $str );

 ibm2uni( \$str );       # called with REF to string -> direct converting
 $str = ibm2uni( $str );

 ibm2uni();              # with omitted param called -> $_ converted
 ibm2uni( \$_ );
 $_ = ibm2uni( $_ );

=head1 AUTHOR

Albert MICHEEV <Albert@f80.n5049.z2.fidonet.org>

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

