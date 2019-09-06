package App::morepub::Renderer;
use strict;
use warnings;
use XML::Tiny 'parsefile';
use parent 'Exporter';

our @EXPORT_OK = ('render');

my $hyphenator;

my %noshow =
  map { $_ => 1 } qw[base basefont bgsound meta param script style];

my %empty = map { $_ => 1 } qw[br canvas col command embed frame
  img is index keygen link];

my %inline = map { $_ => 1 }
  qw[a abbr area b bdi bdo big button cite code dfn em font i
  input kbd label mark meter nobr progress q rp rt ruby s
  samp small span strike strong sub sup time tt u var wbr];

my %block = map { $_ => 1 }
  qw[address applet article aside audio blockquote body caption
  center colgroup datalist del dir div dd details dl dt
  fieldset figcaption figure footer form frameset h1 h2 h3
  h4 h5 h6 head header hgroup hr html iframe ins legend li
  listing map marquee menu nav noembed noframes noscript
  object ol optgroup option p pre select section source summary
  table tbody td tfoot th thead title tr track ul video];

sub nodes {
    my (@nodes) = @_;
    return if !@nodes;
    my @collection;
    for my $node (@nodes) {
        my $type = $node->{type};
        if ( $type eq 'e' ) {
            $type = $node->{name};
        }
        elsif ( $type eq 't' ) {
            $type = 'text';
        }
        push @collection, [ "start_" . $type, $node ];
        if ( ref( $node->{content} ) ) {
            push @collection, nodes( @{ $node->{content} } );
        }
        push @collection, [ "end_" . $type, $node ];
    }
    return @collection;
}

sub render {
    my ($content) = @_;

    my $elements = parsefile( '_TINY_XML_STRING_' . $content );

    return [] if !@$elements;

    my @nodes = nodes(@$elements);

    my @lines;
    my $buffer = '';

    my $left_margin         = 0;
    my $preserve_whitespace = 0;
    my $columns             = qx(tput cols) || 80;
    my $pad                 = '';
    my $newline             = 1;
    my $buffered_newline    = 0;
    my $ol_stack            = [];

    foreach my $event (@nodes) {
        my $key  = $event->[0];
        my $node = $event->[1];

        my $content;
        if ( $key eq 'start_text' ) {
            $content = $node->{content};
        }
        elsif ( $key eq 'start_pre' ) {
            $preserve_whitespace = 1;
        }
        elsif ( $key eq 'end_pre' ) {
            $preserve_whitespace = 0;
        }
        elsif ( $key eq 'start_p' || $key eq 'start_div' ) {
            if ( @lines && $lines[-1] ne '' ) {
                push @lines, "";
            }
        }
        elsif ( $key eq 'start_ol' ) {
            push @$ol_stack, 1;
            $left_margin += 2;
            $pad = ' ' x $left_margin;
        }
        elsif ( $key eq 'start_ul' ) {
            $left_margin += 2;
            $pad = ' ' x $left_margin;
        }
        elsif ( $key eq 'end_ul' ) {
            $left_margin -= 2;
            $pad = ' ' x $left_margin;
        }
        elsif ( $key eq 'end_ol' ) {
            pop @$ol_stack;
            $left_margin -= 2;
            $pad = ' ' x $left_margin;
        }
        elsif ( $key eq 'start_li' ) {
            if ($buffer) {
                $buffer =~ s/\s+$//;
                push @lines, $buffer;
                $buffer = '';
            }

            my $parent = $node->parent->tag;
            if ( $parent eq 'ul' ) {
                $content = "* ";
            }
            elsif ( $parent eq 'ol' ) {
                $content = $ol_stack->[-1]++ . '. ';
            }
            else {
                die "Unknown parent $parent for start_li\n";
            }
        }
        elsif ( $key eq 'end_li' ) {
            if ($buffer) {
                push @lines, $buffer;
                $buffer = '';
            }
            next;
        }
        elsif ( $key =~ /start_h(\d+)/ ) {
            $content = "=" x $1;
            push @lines, $buffer;
            $buffer = '';
            if ( @lines && $lines[-1] ne '' ) {
                push @lines, "";
            }
        }
        elsif ( $key eq 'start_ol' ) {
            push @$ol_stack, 1;
        }
        elsif ( $key eq 'end_ol' ) {
            pop @$ol_stack;
        }
        elsif ( $key eq 'end_p' || $key eq 'end_div' ) {
            if ( $buffer && $buffer !~ m/^\s*$/ ) {
                push @lines, $buffer;
                $buffer = '';
            }
        }
        elsif ( $key eq 'end_body' ) {
            if ( $buffer && $buffer !~ m/^\s*$/ ) {
                push @lines, $buffer;
            }
            last;
        }

        next if not defined $content;

        my @words = grep { $_ ne '' } split( /(\s+)/, $content );

        if ( !$preserve_whitespace ) {
            @words = map { s/\s+/ /; $_ } @words;
        }
        else {
            @words = map { split /(\n)/ } @words;
        }

        for my $word (@words) {

            my $word_length   = () = $word =~ /\X/g;
            my $buffer_length = () = $buffer =~ /\X/g;

            my $max = $columns - $buffer_length - $left_margin - 1;

            if ( $word_length > $max ) {
                $buffer =~ s/\s+$//;    ## Remove trailing whitespace
                next if !$preserve_whitespace && $word =~ /^\s+$/;

                push @lines, $buffer;
                $buffer = '';
            }

            if ( $word eq "\n" ) {
                push @lines, $buffer;
                $buffer = '';
                next;
            }

            next if !$preserve_whitespace && $buffer eq "" && $word =~ /^\s+$/;

            if ( $left_margin && $buffer eq "" ) {
                $buffer .= $pad;
            }

            $buffer .= $word;
        }
    }

    if ( @lines && $lines[-1] eq '' ) {
        delete $lines[-1];
    }

    return @lines;
}

1;
