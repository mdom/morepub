package App::morepub::Archive;
use Mojo::Base -base;
use IO::Uncompress::Unzip qw($UnzipError);
use Mojo::Util 'decode';

has 'file';
has '_content' => sub {
    my $self = shift;
    my $file = $self->file;

    my $u = IO::Uncompress::Unzip->new( $file, transparent => 0 )
      or die "Cannot open $file: $UnzipError\n";

    my %contents;
    my $status;
    for ( $status = 1 ; $status > 0 ; $status = $u->nextStream() ) {
        my $header = $u->getHeaderInfo();
        my $buffer;
        while ( ( $status = $u->read($buffer) > 0 ) ) {
            $contents{ $header->{Name} } .= $buffer;
        }
    }

    die "Error processing $file: $!\n"
      if $status < 0;

    my $mimetype = $contents{'mimetype'};
    $mimetype =~ s/[\r\n]+//;
    if ( !$mimetype ) {
        die "Missing mimetype for $file (is it an epub file?)\n";
    }
    if ( $mimetype ne 'application/epub+zip' ) {
        die "Unknown mimetype $mimetype for $file (is it an epub file?)\n";
    }
    return \%contents;
};

sub contents {
    my ( $self, $file ) = @_;
    decode 'UTF-8', $self->_content->{$file};
}

1;
