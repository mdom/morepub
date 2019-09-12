package App::morepub::Renderer;
use Mojo::Base -base;
use Mojo::DOM;

has columns => sub {
    my $max_width = qx(tput cols);
    return $max_width > 80 ? 80 : $max_width;
};

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
    my @events;
    for my $node (@_) {
        my $type;
        if ( $node->type eq 'tag' ) {
            $type = $node->tag;
        }
        elsif ( $node->type eq 'text' ) {
            $type = 'text';
        }
        else {
            next;
        }
        push @events, [ "start_$type", $node ],
          nodes( $node->child_nodes->each ),
          [ "stop_$type", $node ];
    }
    return @events;
}

has line => sub { 1 };

sub render {
    my ( $self, $content ) = @_;

    my $dom    = Mojo::DOM->new($content)->at('body');
    my @events = nodes( $dom->child_nodes->each );

    return '' if !@events;

    my $buffer = '';

    my $left_margin         = 0;
    my $preserve_whitespace = 0;
    my $columns             = $self->columns;
    my $column              = 0;
    my $pad                 = ' ';
    my $newline             = 1;
    my $buffered_newline    = 0;
    my $ol_stack            = [];
    my $line                = $self->line;

    foreach my $event (@events) {
        my $key  = $event->[0];
        my $node = $event->[1];

        my $content;
        if ( $key eq 'start_text' ) {
            $content = $node->{content};
        }
        elsif ( $key eq 'start_a' ) {
            $buffer .= '[';
            $column++;
        }
        elsif ( $key eq 'stop_a' ) {
            my $link = '](' . $node->attr('href') . ')';
            $buffer .= $link;
            $column += length $link;
        }
        elsif ( $key eq 'start_pre' ) {
            $buffer .= "\n";
            $line++;
            $preserve_whitespace = 1;
        }
        elsif ( $key eq 'end_pre' ) {
            $buffer .= "\n";
            $line++;
            $preserve_whitespace = 0;
        }
        elsif ( $key eq 'start_p' || $key eq 'start_div' ) {
            if ( $buffer !~ /\n\n\z/sm ) {
                $buffer .= "\n\n";
                $line += 2;
            }
            elsif ( $buffer !~ /\n\z/sm ) {
                $buffer .= "\n";
                $line += 1;
            }
            $column = 0;
        }
        elsif ( $key eq 'start_ol' ) {
            push @$ol_stack, 1;
            $left_margin += 2;
        }
        elsif ( $key eq 'start_ul' ) {
            $left_margin += 2;
        }
        elsif ( $key eq 'end_ul' ) {
            $left_margin -= 2;
        }
        elsif ( $key eq 'end_ol' ) {
            pop @$ol_stack;
            $left_margin -= 2;
        }
        elsif ( $key eq 'start_li' ) {
            $buffer .= "\n";
            $line += 1;
            my $parent = $node->parent->tag;

            if ( $parent eq 'ul' ) {
                $buffer .= ( $pad x $left_margin ) . '* ';
                $column = $left_margin + 2;
            }
            elsif ( $parent eq 'ol' ) {
                my $number = $ol_stack->[-1]++;
                $buffer .= ( $pad x $left_margin ) . $number . '. ';
                $column = $left_margin + 2 + length($number);
            }
            else {
                die "Unknown parent $parent for start_li\n";
            }
        }
        elsif ( $key =~ /start_h(\d+)/ ) {
            $buffer .= "\n\n" . ( "=" x $1 ) . " ";
            $column = $1 + 1;
            $line += 2;
        }
        elsif ( $key =~ /end_h(\d+)/ ) {
            $buffer .= "\n\n";
            $line += 2;
            $column = 0;
        }
        elsif ( $key eq 'start_ol' ) {
            push @$ol_stack, 1;
        }
        elsif ( $key eq 'end_ol' ) {
            pop @$ol_stack;
        }

        next if $key ne 'start_text';

        if ($preserve_whitespace) {
            $buffer .= $content;
            $line += $content =~ tr/\n/\n/;
            next;
        }

        $content =~ s/\s+/ /smg;

        my @words = grep { $_ ne '' } split( /(\s)/, $content );

        for my $word (@words) {

            my $word_length;

			if ( $word =~ /[^[:ascii:]]/ ) {
				$word_length = () = $word =~ /\X/g;
			}
			else {
				$word_length = length $word;
			}

            my $max = $columns - $column - $left_margin - 1;

            if ( $word_length > $max ) {
                $buffer .= "\n";
                $line += 1;
                $column = 0;
            }

            next if $column == 0 && $word eq ' ';

            if ( $left_margin && $column == 0 ) {
                $buffer .= $pad x $left_margin;
                $column += $left_margin;
            }

            $buffer .= $word;
            $column += length $word;
        }
    }

    $buffer =~ s/\A\n+//sm;
    $buffer =~ s/\n+\z//sm;
    $buffer =~ s/[ ]+$//gm;

    $self->line( $self->line + $buffer =~ tr/\n/\n/ );

    return $buffer;
}

1;
