use strict;
use warnings;
use Test::More;
use DBI;
use HTTP::Session;
use HTTP::Session::State::Test;
use HTTP::Session::Store::DBI::Lite;
use Test::Requires qw(DBD::SQLite File::Temp CGI);

my $tmp = File::Temp->new;
$tmp->close();
my $tmpf = $tmp->filename;
my $dbh = DBI->connect("dbi:SQLite:dbname=$tmpf", '', '', {RaiseError => 1}) or die $DBI::err;

my $SCHEMA = <<'SQL';
CREATE TABLE session (
        sid          VARCHAR(32) PRIMARY KEY,
        data         TEXT,
        expires      INTEGER UNSIGNED NOT NULL,
        UNIQUE(sid)
);
SQL

$dbh->begin_work;
$dbh->do($SCHEMA);
$dbh->commit;

my $store = HTTP::Session::Store::DBI::Lite->new(
    dbh => $dbh 
);
my $key = "jklj352krtsfskfjlafkjl235j1" . rand();
is $store->select($key), undef;
$store->insert($key, {foo => 'bar'});
is $store->select($key)->{foo}, 'bar';
$store->update($key, {foo => 'replaced'});
is $store->select($key)->{foo}, 'replaced';
$store->delete($key);
is $store->select($key), undef;
ok $store;

my $session = HTTP::Session->new(
    store   => HTTP::Session::Store::DBI::Lite->new( {
        dbh => $dbh
    } ),
    state   => HTTP::Session::State::Test->new( {
        session_id => $key
    } ),
    request => new CGI(),
);

$session->set($key, { foo => 'baz' } );
is $session->get($key)->{foo}, 'baz';

done_testing;
