package FlipDot::Hanover::Display;
use strictures 2;
no warnings 'experimental';
use feature 'signatures';
use POSIX 'ceil', 'floor';
use Moo;

has 'width', is => 'rw';
has 'height', is => 'rw';

=item address

C<address> should be the value printed on the dial-switch on the main board in the display.  The module will add one for you, as required by the protocol.

=cut

has 'address', is => 'rw';;

sub imager_to_packet($self, $image) {
    $image = $image->to_paletted({
        make_colors => 'mono',
        translate => 'errdiff'
    });

    if ($image->getwidth != $self->width) {
        die sprintf("Passed image is wrong width (passed %d, expected %d)", $image->getwidth, $self->width);
    }

    if ($image->getheight != $self->height) {
        die sprintf("Passed image is wrong height (passed %d, expected %d)", $image->getheight, $self->height);
    }


    # effectively pad on the bottom such that every column starts on an even byte boundry.
    my $bits_height = 8*ceil($self->height / 8);
    my $data_length_bits = $self->width * $bits_height;
    my $data_length_bytes = $data_length_bits / 8;

    #print "bits height: $bits_height\n";
    
    # fixme: this is horribly inefficent, but profile, or at least see how many fps we actually pump out, before we worry about it too much.
    my $data;
    my $white = Imager::Color->new('white');
    for my $x (0..$self->width-1) {
        for my $y (0..$self->height-1) {
	    my ($pixel) = $image->getpixel(x=>$x, y=>$y)->equals(other=>$white) ? 1 : 0;
	    my $linear = $x * $bits_height + $y;
	    #print "x,y linear pixel = $x, $y $linear $pixel\n";
            vec($data, $linear, 1) = $pixel;
        }
    }
    
    # convert from raw data into printable hex (uppercase).  Why they decided it should be printable hex I do not know, ask hanover.
    $data = join '', map {sprintf '%02X', ord $_} split //, $data;

    # the section of the packet that the checksum is computed across.
    # constant '1', address, length of payload, EOT.
    my $packet_body = sprintf "1%1X%02X%s\x03", $self->address+1, $data_length_bytes, $data;
    my $checksum = 0;
    for my $c (split //, $packet_body) {
        $checksum += ord($c);
    }
    $checksum &= 0xFF;
    $checksum = ($checksum ^ 0xFF) + 1;

    $packet_body = sprintf "\x02%s%02X", $packet_body, $checksum;

    #my $extra_hexy = $packet_body;
    #$extra_hexy =~ s/(.)/sprintf "%02X", ord $1/eg;
    #print "full packet, extra hexy: $extra_hexy\n";

    # node/working: 0231363534303037303730373030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030033938
    # ours/broken:  0231363534303037303730373030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030033936

    
    return $packet_body;
}

sub write_frame($self) {
    
}

1;
