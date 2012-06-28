package HTTP::Session::Store::DBI::Lite;
use strict;
use warnings;
use 5.008008;
our $VERSION = '0.01';

use parent qw(Class::Accessor::Fast);

use DBI;
use Storable qw/nfreeze thaw/;
use Carp qw(croak);
use MIME::Base64 qw(encode_base64 decode_base64);

__PACKAGE__->mk_accessors(qw(expires));

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    unless ($args{dbh} || $args{get_dbh}) {
        croak "Missing mandatory parameter: dbh or get_dbh";
    }
    return bless {
        expires => 3600,
        table_name   => 'session',
        serializer => sub {
            MIME::Base64::encode_base64( Storable::nfreeze( $_[0] ) )
        },
        deserializer => sub {
            Storable::thaw( MIME::Base64::decode_base64( $_[0] ) )
        },
        %args
    }, $class;
}

sub _dbh {
    my $self = shift;
    ( exists $self->{get_dbh} ) ? $self->{get_dbh}->() : $self->{dbh};
}

sub select {
    my ( $self, $session_id ) = @_;

    my $sth = $self->_dbh->prepare( q{SELECT data, expires FROM session WHERE sid=?} ); 
    $sth->execute( $session_id );
    my ($data, $expires) = $sth->fetchrow_array;

    return unless ($data);
    return unless ( $expires > time() );

    return $self->{deserializer}->($data);
}

sub insert {
    my ($self, $session_id, $data) = @_;
    
    $data = $self->{serializer}->($data);
    
    my $dbh = $self->_dbh;
    my $sql =qq!INSERT INTO $self->{table_name} (sid, data, expires) VALUES (?, ?, ?)!;
    my $sth = $dbh->prepare($sql);
    $sth->execute( $session_id, $data, time() + $self->expires );
}

sub update {
    my ($self, $session_id, $data) = @_;

    $data = $self->{serializer}->($data);
    
    my $dbh = $self->_dbh;
    my $sql =qq{UPDATE $self->{table_name} SET data = ?, expires = ? WHERE sid = ?};
    my $sth = $dbh->prepare($sql);
    $sth->execute( $data, time() + $self->expires, $session_id );
}

sub delete {
    my ($self, $session_id) = @_;
    
    my $dbh = $self->_dbh;
    my $sql =qq{DELETE FROM $self->{table_name} WHERE sid = ?};
    my $sth = $dbh->prepare($sql);
    $sth->execute( $session_id );
}

1;
__END__

=encoding utf8

=head1 NAME

HTTP::Session::Store::DBI::Lite - A module for you

=head1 SYNOPSIS

  use HTTP::Session::Store::DBI::Lite;

=head1 DESCRIPTION

HTTP::Session::Store::DBI::Lite is

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
