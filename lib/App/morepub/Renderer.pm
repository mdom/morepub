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
        my $type = $node->type;
        if ( $type eq 'text' ) {
            push @events, [ 'start_text', $node ];
        }
        elsif ( $type eq 'tag' ) {
            my $tag = $node->tag;
            push @events, [ "start_$tag", $node ];
            if ( my @childs = @{ $node->child_nodes } ) {
                push @events, nodes(@childs);
            }
            push @events, [ "end_$tag", $node, $tag ];
        }
    }
    return @events;
}

has line => sub { 1 };

has targets => sub { {} };
has links   => sub { [] };

sub render {
    my ( $self, $content, $file ) = @_;

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

    $self->targets->{$file} = $line;

    foreach my $event (@events) {
        my $key  = $event->[0];
        my $node = $event->[1];
        my $tag  = $event->[2];

        if ( $node->type eq 'tag' && $node->attr('id') ) {
            $self->targets->{ $file . '#' . $node->attr('id') } = $line;
        }

        if ( $tag && $block{$tag} ) {
            if ( substr( $buffer, -2, 2 ) ne "\n\n" ) {
                $buffer .= "\n\n";
                $line += 2;
            }
            elsif ( substr( $buffer, -1, 1 ) ne "\n" ) {
                $buffer .= "\n";
                $line += 1;
            }
            $column = 0;
        }

        my $content;
        if ( $key eq 'start_text' ) {
            $content = $node->content;
        }
        elsif ( $key eq 'start_a' ) {
            my $href = $node->attr('href');
            next if !$href;

            my $url = Mojo::URL->new($href);
            next if $url->host;
            next if $url->scheme;

            my $path = $url->path;
            my $target_name;

            if ( $path->to_string ) {
                $target_name =
                  Mojo::File->new($file)->sibling($path)->to_rel->to_string;
                if ( $url->fragment ) {
                    $target_name .= '#' . $url->fragment;
                }
            }
            elsif ( $url->fragment ) {
                $target_name = Mojo::File->new($file)->to_rel->to_string . '#'
                  . $url->fragment;
            }

            my $num = scalar @{ $self->links } + 1;
            push @{ $self->links }, [ $num, $target_name ];
            $content = "[$num]";
        }
        elsif ( $key eq 'start_pre' ) {
            $preserve_whitespace = 1;
        }
        elsif ( $key eq 'end_pre' ) {
            $preserve_whitespace = 0;
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
            $content = ( "=" x $1 ) . " ";
        }
        elsif ( $key eq 'start_ol' ) {
            push @$ol_stack, 1;
        }
        elsif ( $key eq 'end_ol' ) {
            pop @$ol_stack;
        }

        next if not defined $content;

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
    $buffer .= "\n\n";

    $self->line( $self->line + $buffer =~ tr/\n/\n/ );

    return $buffer;
}

1;
