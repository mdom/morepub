package App::morepub::Epub;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::URL;
use Mojo::File;
use Mojo::Util qw(decode encode html_unescape);
use App::morepub::NavDoc;
use App::morepub::Archive;

has 'file';

has archive => sub {
    App::morepub::Archive->new( file => shift->file );
};

has nav_doc => sub {
    my $self = shift;
    my $href = $self->root_dom->find('manifest item[properties="nav"]')
      ->map( attr => 'href' )->first;
    return if !$href;
    return App::morepub::NavDoc->new(
        href => Mojo::URL->new($href),
        epub => $self,
    );
};

has toc => sub {
    my $self = shift;

    ## http://www.idpf.org/epub/20/spec/OPF_2.0.1_draft.htm#Section2.6

    my $toc = $self->root_dom->find('guide reference[type="toc"]')
      ->map( attr => 'href' )->map( sub { Mojo::URL->new($_) } )->first;

    ## http://www.idpf.org/epub/30/spec/epub30-publications.html#sec-item-elem

    if ( !$toc && $self->nav_doc ) {
        $toc = $self->nav_doc->toc;
    }

    if ( !$toc && $self->nav_doc ) {
        $toc = $self->nav_doc->href;
    }

    if ( !$toc ) {
        my $ncx = $self->root_dom->find(
            'manifest item[media-type="application/x-dtbncx+xml"]')
          ->map( attr => 'href' )->first;
        my $filename = $self->root_file->sibling($ncx)->to_rel->to_string,;
        my $root     = Mojo::Util::decode 'UTF-8',
          $self->archive->contents($filename);
        use Data::Dumper;
        die "$root";
    }

    $toc->fragment(undef);

    for ( my $i = 0 ; $i < @{ $self->chapters } ; $i++ ) {
        if ( $self->chapters->[$i]->href eq $toc ) {
            return $i;
        }
    }
    return;
};

has start_chapter => sub {
    my $self          = shift;
    my $start_chapter = $self->root_dom->find('guide reference[type="text"]')
      ->map( attr => 'href' )->first;

    if ( !$start_chapter && $self->nav_doc ) {
        $start_chapter = $self->nav_doc->find(
            'nav[epub\:type="landmarks"] a[epub\:type="bodymatter"]')
          ->map( attr => 'href' )->first;
    }

    return 0 if !$start_chapter;

    for ( my $i = 0 ; $i < @{ $self->chapters } ; $i++ ) {
        if ( $self->chapters->[$i]->href eq $start_chapter ) {
            return $i;
        }
    }
    return 0;
};

has chapters => sub {
    my $self = shift;
    my @idrefs =
      $self->root_dom->find('spine itemref')->map( attr => 'idref' )->each;

    my %items = map { ( $_->attr('id') => $_->attr('href') ) } @{
        $self->root_dom->find(
            qq{manifest item[id][href][media-type="application/xhtml+xml"})
    };

    my @chapters;
    for my $idref (@idrefs) {
        my $href = $items{$idref};
        next if !$href;

        push @chapters, $self->root_file->sibling($href)->to_rel->to_string;
    }
    return \@chapters;
};

has root_file => sub {
    my $self          = shift;
    my $filename      = $self->file;
    my $container     = $self->archive->contents('META-INF/container.xml');
    my $container_dom = Mojo::DOM->new($container);
    my $root_file = $container_dom->at('rootfiles rootfile')->attr("full-path");
    if ( !$root_file ) {
        die "No root file defined for $filename\n";
    }
    return Mojo::File->new($root_file);
};

has root_dom => sub {
    my $self = shift;
    my $root = $self->archive->contents( $self->root_file->to_string );
    if ( !$root ) {
        die "Missing root file "
          . $self->root_file . " for "
          . $self->file . "\n";
    }
    return Mojo::DOM->new($root);
};

has language => sub {
    my $self = shift;
    return html_unescape(
        eval { $self->root_dom->at('metadata')->at('dc\:language')->content } );
};

has creator => sub {
    my $self = shift;
    return html_unescape(
        eval { $self->root_dom->at('metadata')->at('dc\:creator')->content }
          || 'Unknown' );
};

has title => sub {
    my $self = shift;
    return html_unescape(
        eval { $self->root_dom->at('metadata')->at('dc\:title')->content }
          || 'Unknown' );
};

sub render_book {
    my ( $self, $fh ) = @_;
    my $html = '';

    for my $chapter_file ( @{ $self->chapters } ) {
        my $marker = Mojo::DOM->new('<a />');
        $marker->at('a')->attr( id => '{' . $chapter_file . '}-{}' );
        $html .= $marker->to_string;
        for my $node (
            Mojo::DOM->new( $self->archive->contents($chapter_file) )
            ->at('body')->child_nodes->each )
        {
            for my $node ( $node->find('[id]')->each ) {
                $node->attr( id => '{'
                      . $chapter_file . '}-{'
                      . $node->attr('id')
                      . '}' );
            }

            for my $node ( $node->find('[href]')->each ) {
                my $href = $node->attr('href');
                next if !$href;

                my $url = Mojo::URL->new($href);
                next if $url->host;
                next if $url->scheme;

                my $path     = $url->path;
                my $fragment = $url->fragment;

                if ($path) {
                    $path =
                      Mojo::File->new($chapter_file)->sibling($path)
                      ->to_rel->to_string;
                }

                if ( $path && $fragment ) {
                    $href = "#{$path}-{$fragment}";
                }
                elsif ($path) {
                    $href = "#{$path}-{}";
                }
                elsif ($fragment) {
                    $href = "#{}-{$path}";
                }
                $node->attr( href => $href );
            }
            $html .= $node->to_string;
        }
    }
    print {$fh} encode 'UTF-8', $html;
}

1;
