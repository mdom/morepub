package App::morepub::Epub;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::URL;
use Mojo::File 'path';
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

    $toc->fragment(undef);

    return normalize_filename( $self->root_file, $toc->path );
};

has start_chapter => sub {
    my $self          = shift;
    my $start_chapter = $self->root_dom->find('guide reference[type="text"]')
      ->map( attr => 'href' )->first;

    if ($start_chapter) {
        return normalize_filename( $self->root_file, $start_chapter );
    }

    if ( $self->nav_doc ) {
        $start_chapter = $self->nav_doc->find(
            'nav[epub\:type~="landmarks"] a[epub\:type~="bodymatter"]')
          ->map( attr => 'href' )->first;
        if ($start_chapter) {
            return normalize_filename( $self->nav_doc->file, $start_chapter );
        }
    }

    return;
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
        eval { $self->root_dom->at('metadata')->at('dc\:language')->content }
          || 'en' );
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

sub normalize_filename {
    my ( $base, $file ) = @_;
    path($base)->sibling($file)->to_rel->to_string;
}

sub render_book {
    my ( $self, $fh ) = @_;
    my $language = $self->language;
    my $title    = $self->title;
    my $html     = <<"    EOF";
		<!doctype html>

		<html lang="$language">
		<head>
			<meta charset="utf-8">
			<title>$title</title>
		</head>
		<body>
    EOF

    my $landmarks = '';

    if ( my $start = $self->start_chapter ) {
        $landmarks .= Mojo::DOM->new_tag(
            a => href => "#{$start}-{}",
            'Jump to bodymatter'
        );
        $landmarks .= '<br />';
    }

    if ( my $toc = $self->toc ) {
        $landmarks .= Mojo::DOM->new_tag(
            a => href => "#{$toc}-{}",
            'Jump to table of contents'
        );
        $landmarks .= '<br />';
    }

    if ($landmarks) {
        $html .= "<p>$landmarks</p>";
    }

    for my $chapter_file ( @{ $self->chapters } ) {
        $html .= Mojo::DOM->new_tag( 'a', id => '{' . $chapter_file . '}-{}' );

        my $dom =
          Mojo::DOM->new( $self->archive->contents($chapter_file) )->at('body');

        $dom->find('script')->map('remove');

        for my $node ( @{ $dom->find('[id]') } ) {
            $node->attr(
                id => '{' . $chapter_file . '}-{' . $node->attr('id') . '}' );
        }

        for my $node ( @{ $dom->find('[href]') } ) {
            my $href = $node->attr('href');
            next if !$href;

            my $url = Mojo::URL->new($href);
            next if $url->host || $url->scheme;

            my $path     = $url->path     || '';
            my $fragment = $url->fragment || '';

            next if !$path && !$fragment;

            if ($path) {
                $path =
                  Mojo::File->new($chapter_file)->sibling($path)
                  ->to_rel->to_string;
            }

            $node->attr( href => "#{$path}-{$fragment}" );
        }
        $html .= $dom->content;
    }
    $html .= '</body></html>';
    print {$fh} encode 'UTF-8', $html;
}

1;
