package WWW::SuperAgent;

use LWP::UserAgent;
use Carp qw/croak carp/;
use utf8;
use Encode qw/encode_utf8/;
use URI;

=head1 NAME

WWW::SuperAgent - An enhanced UserAgent

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

WWW::SuperAgent is an anonymising user agent for getting web pages. By default SuperAgent presents 1 of 10 useragent handles when requesting web pages, randomly selecting from Windows, OSX and Linux and browsers IE, Chrome, Firefox and Safari. Additionally, SuperAgent can limit requests per ip address and domain. This is helpful when a domain sets a limit on how many requests it will accept from a unique IP - if this limit is reached, SuperAgent will return an empty string and carp a warning instead of requesting the page.

SuperAgent also maintains a history, can dump and restore the history - this is useful when tracking a large scraping operation, which may occur over several disconnected sessions.

SuperAgent encodes all webpages as UTF-8, and is based on LWP::UserAgent;

    use WWW::SuperAgent;
    my $ip = '127.0.0.1'; # insert your actual ip here
    my $sa = WWW::SuperAgent->new($ip);
    my $html = $sa->get_url('http://google.com');
    ...


=head1 SUBROUTINES/METHODS

=head2 new (ip_address)

Instantiates a new SuperAgent object - if an ip address is provided, SuperAgent will store it and track requests against it. If not, SuperAgent will use localhost (127.0.0.1).

=cut

sub new {
    my $class = shift;
    my $self = {
        ip              => shift || '127.0.0.1',
        _alias_mode     => 1,
        _history        => [],
        _domain_ip_limit=> 0,
        _aliases        => [
            'Mozilla/5.0 (X11; Linux x86_64; rv:20.0) Gecko/20100101 Firefox/20.0',
            'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)',
            'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)',
            'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Trident/6.0)',
            'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 5.1; Trident/5.0)',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.22 (KHTML, like Gecko) Chrome/25.0.1364.172 Safari/537.22',
            'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.22 (KHTML, like Gecko) Chrome/25.0.1364.172 Safari/537.22',
            'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.15 (KHTML, like Gecko) Chrome/24.0.1295.0 Safari/537.15',
            'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/125.2 (KHTML, like Gecko) Safari/125.8',
            'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/537.22 (KHTML like Gecko) Safari/537.22',
            ],
        _ua => LWP::UserAgent->new,
    };
    bless $self, $class;
    return $self;
}

=head2 get_url ($url)

Gets and returns a utf8 encoded file via http.

=cut

sub get_url {
    my ($self, $url) = @_;

    # Check url
    if (not $url) {
        carp "Error: no url provided";
        return '';
    }

    # Check domain ip limit
    if (not $self->_check_domain_ip_limit($url)){
        carp "Error: domain ip limit reached for $self->{ip} and $url. Change ip or the domain ip count limit";
        return '';
    }

    # Set alias
    if ($self->{_alias_mode}) {
        $self->_set_alias($self->_get_random_alias); 
    }

    # Get page
    my $response = $self->{_ua}->get($url);
    $self->_log_request($self->{ip}, $url, $self->{_ua}->agent, $response->code); 
    if ($response->is_success) {
        return encode_utf8($response->decoded_content);
    }
    else {
        carp "response received: $response->code not successful";
        return '';
    }
}

=head2 get_domain_count (url)

Returns the count of requests to the domain in the history.

=cut

sub get_domain_count {
    my ($self, $url) = @_;
    if ($url) {
        my $uri = URI->new($url);
        my $domain =  $uri->host =~ s/^www\.//r;
        return grep { $_->{url} =~ /$domain/ } @{$self->get_history};
    }
    carp "Missing parameters url and/or ip";
    return 0;
}

=head2 get_domain_ip_count ($domain, $ip)

Returns the count of requests to the domain and ip in the history.

=cut

sub get_domain_ip_count {
    my ($self, $url, $ip) = @_;
    if ($url and $ip) {
        my $uri = URI->new($url);
        my $domain =  $uri->host =~ s/^www\.//r;
        return grep { $_->{ip} =~ /$ip/ } grep { $_->{url} =~ /$domain/ } @{$self->get_history};
    }
    carp "Missing parameters url and/or ip";
    return 0;
}

=head2 get_url_count ($url)

Returns the count of requests to the url in the history.

=cut

sub get_url_count {
    my ($self, $url) = @_;
    if ($url) {
        return grep { $_->{url} =~ /$url/ } @{$self->get_history};
    }
    carp "No url count parameter received";
    return 0;
}

=head2 get_ip_count ($ip)

Returns the count of requests to the ip in the history.

=cut

sub get_ip_count {
    my ($self, $ip) = @_;
    return grep { $_->{ip} =~ /$ip/ } @{$self->get_history};
}

=head2 clear_history

=cut

sub clear_history {
    my $self = shift;
    $self->{_history} = [];
    return 1;
}

=head2 get_history

=cut

sub get_history {
    my $self = shift;
    return $self->{_history};
}

=head2 print_history ($filepath)

This method requires a path as a parameter, and will write the history to the path, appending its contents.

=cut

sub print_history {
    my ($self, $path) = @_;
    open my $fh, '>>', $path or croak "Error: unable to open filehandle to $path";
    foreach my $line (@{$self->get_history}) {
        print $fh $line->{ip} . "\t" . $line->{url} . "\t" . $line->{agent} . "\t" . $line->{response_code} . "\n";
    }
    close $fh;
    return 1;
}

=head2 load_history ($filepath)

Loads a SuperAgent browsing history from a tab delimited file in the format: ip url agent response_code.

=cut

sub load_history {
    my ($self, $path) = @_;
    open my $fh, '<', $path or croak "Error: unable to open filehandle to $path";
    while (<$fh>) {
        my @line_args = split("\t");
        $self->_log_request($line_args[0], $line_args[1], $line_args[2], $line_args[3]);
    }
    return 1;
}

=head2 set_alias_mode_on

Turns on the alias mode which shuffles the user agent header for every subsequent request. The default is on.

=cut

sub set_alias_mode_on {
    my $self = shift;
    $self->{_alias_mode} = 1;
    return 1;
}


=head2 set_alias_mode_off

Turns the alias mode off which retains the current user agent header for every subsequent request.

=cut

sub set_alias_mode_off {
    my $self = shift;
    $self->{_alias_mode} = 0;
    return 1;
}

=head2 get_alias

Returns the current agent string for the request header.

=cut

sub get_alias {
    my $self = shift;
    return $self->{_ua}->agent;
}


=head2 get_domain_ip_limit

Returns the current limit per unique ip address and domain.

=cut

sub get_domain_ip_limit {
    my $self = shift;
    return $self->{_domain_ip_limit};
}

=head2 set_domain_ip_limit ($limit)

Sets the number of times a request can be made per domain.

=cut

sub set_domain_ip_limit {
    my ($self, $domain_limit) = @_;
    if ($domain_limit) {
        $self->{_domain_ip_limit} = $domain_limit;
        return 1;
    }
    carp "No domain_limit parameter received";
    return 0;
}

=head1 INTERNAL SUBROUTINES/METHODS


=head2 _log_request

Logs requests into the history.

=cut

sub _log_request {
    my ($self, $ip, $url, $agent, $response_code) = @_;
    if ($ip and $url and $agent and $response_code) {
        push @{$self->{_history}}, { 
            ip              => $ip,
            url             => $url,
            agent           => $agent,
            response_code   => $response_code,
        };
    return 1;
    }
    carp "Error: _log_request called with missing parameters (ip: $ip, url: $url, agent: $agent, response_code: $response_code)";
    return 0;
}

=head2 _set_alias($alias)

Sets the agent string for the request header.

=cut

sub _set_alias {
    my ($self, $alias) = @_;
    if ($alias) {
        $self->{_ua}->agent($alias);
        return 1;
    }
    carp "No alias parameter received";
    return 0;
}

=head2 _get_random_alias

Returns a random alias from the alias array;

=cut

sub _get_random_alias {
    my $self = shift;
    my $alias_index = int(rand($#{$self->{_aliases}}));
    return $self->{_aliases}->[$alias_index];
}

=head2 _check_domain_limit

Checks a request is not breaching the domain limit.

=cut

sub _check_domain_ip_limit {
    my ($self, $url) = @_;
    if (not $url) {
        carp "Error: no url parameter provided for _check_domain_ip_limit method";
        return 0;
    }
    return 1 unless $self->get_domain_ip_limit;
    return $self->get_domain_ip_count($url, $self->{ip}) < $self->get_domain_ip_limit ? 1 : 0;
}


=head1 AUTHOR

David Farrell, C<< <davidnmfarrell at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-superagent at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-SuperAgent>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SuperAgent


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-SuperAgent>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-SuperAgent>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-SuperAgent>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-SuperAgent/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 David Farrell.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of WWW::SuperAgent
