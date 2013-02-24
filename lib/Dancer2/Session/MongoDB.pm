use 5.008001;
use strict;
use warnings;

package Dancer::SessionFactory::MongoDB;
# ABSTRACT: Dancer 2 session storage with MongoDB
# VERSION

use Moo;
use MongoDB::MongoClient;
use MongoDB::OID;
use Dancer::Core::Types;

#--------------------------------------------------------------------------#
# Public attributes
#--------------------------------------------------------------------------#

=attr database_name (required)

Name of the database to hold the sessions collection.

=cut

has database_name => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

=attr collection_name

Collection name for storing session data. Defaults to 'dancer_sessions'.

=cut

has collection_name => (
    is      => 'ro',
    isa     => Str,
    default => sub { "dancer_sessions" },
);

=attr client_options

Hash reference of configuration options to pass through to
L<MongoDB::MongoClient> constructor.  See that module for details on
configuring authentication, replication, etc.

=cut

has client_options => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

#--------------------------------------------------------------------------#
# Private attributes
#--------------------------------------------------------------------------#

has _client => (
    is  => 'lazy',
    isa => InstanceOf ['MongoDB::MongoClient'],
);

sub _build__client {
    my ($self) = @_;
    return MongoDB::MongoClient->new( $self->client_options );
}

has _collection => (
    is  => 'lazy',
    isa => InstanceOf ['MongoDB::Collection'],
);

sub _build__collection {
    my ($self) = @_;
    my $db = $self->_client->get_database( $self->database_name );
    return $db->get_collection( $self->collection_name );
}

#--------------------------------------------------------------------------#
# Role composition
#--------------------------------------------------------------------------#

with 'Dancer::Core::Role::SessionFactory';

# When saving/retrieving, we need to add/strip the _id parameter
# because the Dancer::Core::Session object keeps them as separate
# attributes

sub _retrieve {
    my ( $self, $id ) = @_;
    my $doc = $self->_collection->find_one( { _id => $id } );
    return $doc->{data};
}

sub _flush {
    my ( $self, $id, $data ) = @_;
    $self->_collection->save( { _id => $id, data => $data }, { safe => 1 } );
}

sub _destroy {
    my ( $self, $id ) = @_;
    $self->_collection->remove( { _id => $id }, { safe => 1 } );
}

sub _sessions {
    my ($self) = @_;
    my $cursor = $self->_collection->query->fields( { _id => 1 } );
    return [ map { $_->{_id} } $cursor->all ];
}

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  # In Dancer 2 config.yml file

  session: MongoDB
  engines:
    session:
      MongoDB:
        database_name: myapp_db
        client_options:
          host: mongodb://localhost:27017

=head1 DESCRIPTION

This module implements a session factory for Dancer 2 that stores session
state within L<MongoDB>.

=cut

# vim: ts=4 sts=4 sw=4 et:
