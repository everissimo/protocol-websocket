use strict;
use warnings;

use Test::More;

use_ok 'Protocol::WebSocket::Frame';

is(Protocol::WebSocket::Frame->new->max_payload_size,
    65536, 'default max_payload_size');
is(Protocol::WebSocket::Frame->new(max_payload_size => 22)->max_payload_size,
    22, 'override max_payload_size');
is(Protocol::WebSocket::Frame->new(max_payload_size => 0)->max_payload_size,
    0, 'turn off max_payload_size');
is(
    Protocol::WebSocket::Frame->new(max_payload_size => undef)
      ->max_payload_size,
    undef,
    'turn off max_payload_size'
);

subtest 'payload too large (to_bytes)' => sub {
    my $frame = Protocol::WebSocket::Frame->new(buffer => 'x' x 65537);

    eval { $frame->to_bytes };

    like $@, qr/Payload is too big\. Send shorter messages or increase max_payload_size/;
};

subtest 'payload larger than 65536, but under max (to_bytes)' => sub {
    my $frame = Protocol::WebSocket::Frame->new(
        buffer           => 'x' x 65537,
        max_payload_size => 65537
    );

    eval { $frame->to_bytes };

    is $@, '';
};

subtest 'turn off payload size checking (to_bytes)' => sub {
    my $frame = Protocol::WebSocket::Frame->new(
        buffer           => 'x' x 65537,
        max_payload_size => 0
    );

    eval { $frame->to_bytes };

    is $@, '';
};

my $large_frame =
  Protocol::WebSocket::Frame->new(buffer => 'x' x 65537, max_payload_size => 0);

subtest 'payload too large (next_bytes)' => sub {
    my $frame = Protocol::WebSocket::Frame->new;
    $frame->append($large_frame->to_bytes);

    eval { $frame->next_bytes };

    like $@, qr/Payload is too big\. Deny big message/;
};

subtest 'payload larger than 65536, but under max (next_bytes)' => sub {
    my $frame = Protocol::WebSocket::Frame->new(max_payload_size => 65537);
    $frame->append($large_frame->to_bytes);

    eval { $frame->next_bytes };

    is $@, '';
};

subtest 'turn off payload size checking (next_bytes)' => sub {
    my $frame = Protocol::WebSocket::Frame->new(max_payload_size => 0);
    $frame->append($large_frame->to_bytes);

    eval { $frame->next_bytes };

    is $@, '';
};

my $first_fragment = Protocol::WebSocket::Frame->new(buffer => 'x', type => 'text', fin => 0);
my $a_fragment = Protocol::WebSocket::Frame->new(buffer => 'x', type => 'continuation', fin => 0);

subtest 'maximum number or fragments exceeded' => sub {
    local $Protocol::WebSocket::Frame::MAX_FRAGMENTS_AMOUNT = 42;
    my $frame = Protocol::WebSocket::Frame->new();
    is $frame->{max_fragments_amount}, 42;

    $frame->append($first_fragment->to_bytes);
    $frame->append($a_fragment->to_bytes) for ( 1 .. $frame->{max_fragments_amount} );

    eval { $frame->next_bytes };
    like $@, qr/Too many fragments/;
};

done_testing;
