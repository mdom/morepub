package App::morepub::Epub;
use strict;
use warnings;
use parent 'Exporter';
use IO::Uncompress::Unzip qw($UnzipError);
use XML::Tiny 'parsefile';

our @EXPORT_OK = qw(parsebook);

sub parsestring {
    my ($string) = @_;
    return parsefile( '_TINY_XML_STRING_' . $string );
}

sub find_node {
    my ( $nodes, $sub ) = @_;
    for my $node (@$nodes) {
        if ( $sub->($node) ) {
            return $node;
        }
        if ( ref( $node->{content} ) ) {
            my $n = find_node( $node->{content}, $sub );
            return $n if $n;
        }
    }
    return;
}

sub read_archive {
    my ($file) = @_;

    my $u = IO::Uncompress::Unzip->new( $file, transparent => 0 )
      or die "Cannot open $file: $UnzipError\n";

    my %contents;
    my $status;
    for ( $status = 1 ; $status > 0 ; $status = $u->nextStream() ) {
        my $header = $u->getHeaderInfo();
        my $buffer;
        while ( ( $status = $u->read($buffer) > 0 ) ) {
            $contents{files}->{ $header->{Name} } .= $buffer;
        }
    }

    die "Error processing $file: $!\n"
      if $status < 0;

    my $mimetype = $contents{files}->{'mimetype'};
    $mimetype =~ s/[\r\n]+//;
    if ( !$mimetype ) {
        die "Missing mimetype for $file (is it an epub file?)\n";
    }
    if ( $mimetype ne 'application/epub+zip' ) {
        die "Unknown mimetype $mimetype for $file (is it an epub file?)\n";
    }
    return \%contents;
}

sub parsebook {
    my ($file)     = @_;
    my $contents   = read_archive($file);
    my $root_nodes = get_root_nodes($contents);

}

sub find_root_file {
    my ( $contents, $node ) = @_;

    my $root_file = find_node(
        find_node( $node,
            sub { $_[0]->{type} eq 'e' && $_[0]->{name} eq 'rootfiles' } )
          ->{content},
        sub {
            $_[0]->{type} eq 'e' && $_[0]->{name} eq 'rootfile';
        }
    )->{attrib}->{'full-path'};
    return $root_file;
}

sub get_root_nodes {
    my ($contents)      = @_;
    my $container       = $contents->{files}->{'META-INF/container.xml'};
    my $container_nodes = parsestring($container);
    my $root_file = find_root_file( $contents, $container_nodes );
    return parsestring( $contents->{files}->{$root_file} );
}

# sub nav_doc {
# my $nodes = shift;
# for my $node (
# find_node( $nodes,
# sub { $_[0]->{type} eq 'e' && $_[0]->{name} eq 'manifest' } )->{
# ->{
# ;
# ->map( attr => 'href' )->first;
# return if !$href;
# return App::termpub::NavDoc->new(
# href => Mojo::URL->new($href),
# epub => $self,
# );
# }
# }

sub toc {
    my $self = shift;

    ## http://www.idpf.org/epub/20/spec/OPF_2.0.1_draft.htm#Section2.6

    my $toc =
      $self->root_dom->find('guide reference[type="toc"]')
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
        my $filename = $self->root_file->sibling($ncx)->to_rel->to_string;
        use Mojo::Util;
        my $root = Mojo::Util::decode 'UTF-8',
          $self->archive->contents($filename);
    }

    $toc->fragment(undef);

    for ( my $i = 0 ; $i < @{ $self->chapters } ; $i++ ) {
        if ( $self->chapters->[$i]->href eq $toc ) {
            return $i;
        }
    }
    return;
}

sub start_chapter {
    my $self = shift;
    my $start_chapter =
      $self->root_dom->find('guide reference[type="text"]')
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
}

sub chapters {
    my $self = shift;
    my @idrefs =
      $self->root_dom->find('spine itemref')->map( attr => 'idref' )->each;

    my @chapters;
    for my $idref (@idrefs) {
        my $item = $self->root_dom->at(qq{manifest item[id="$idref"]});
        next
          if !$item
          || $item->attr('media-type') ne 'application/xhtml+xml';
        my $href = $item->attr('href');
        next if !$href;

        my $title;
        if ( $self->nav_doc ) {
            my $text_node =
              $self->nav_doc->find("a[href=$href]")->map('content')->first;
            if ($text_node) {
                $title = Mojo::DOM->new($text_node)->all_text;
            }
        }

        push @chapters,
          App::termpub::Epub::Chapter->new(
            archive  => $self->archive,
            filename => $self->root_file->sibling($href)->to_rel->to_string,
            href     => $href,
            $title ? ( title => $title ) : (),
          );
    }
    return \@chapters;
}

sub root_dom {
    my $self = shift;
    my $root = Mojo::Util::decode 'UTF-8',
      $self->archive->contents( $self->root_file->to_string );
    if ( !$root ) {
        die "Missing root file "
          . $self->root_file . " for "
          . $self->filename . "\n";
    }
    return Mojo::DOM->new($root);
}

sub language {
    my $self = shift;
    return html_unescape(
        eval { $self->root_dom->at('metadata')->at('dc\:language')->content; }
    );
}

sub creator {
    my $self = shift;
    return html_unescape(
        eval { $self->root_dom->at('metadata')->at('dc\:creator')->content; }
          || 'Unknown' );
}

sub title {
    my $self = shift;
    return html_unescape(
        eval { $self->root_dom->at('metadata')->at('dc\:title')->content; }
          || 'Unknown' );
}

1;
