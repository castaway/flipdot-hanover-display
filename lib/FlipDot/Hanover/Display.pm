package FlipDot::Hannover::Display;
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

    my $data_length = ceil($self->width * $self->height / 8);
    
    # fixme: this is horribly inefficent, but profile, or at least see how many fps we actually pump out, before we worry about it too much.
    my $data;
    my $bits_height = 8*ceil($self->width / 8);
    for my $x (0..$self->width) {
        for my $y (0..$self->height) {
            vec($data, $x * $bits_height + $y, 1) = $image->getpixel(x=>$x, y=>$y) ? 1 : 0;
        }
    }

    # the section of the packet that the checksum is computed across.
    # constant '1', address, length of payload, EOT.
    my $packet_body = sprintf "1%1x%02x%s\x03", $self->address+1, $data_length, $data;
    my $checksum = 0;
    for my $c (split //, $packet_body) {
        $checksum += ord($c);
    }

}

sub write_frame($self) {
    
}

1;
