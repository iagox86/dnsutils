# Dnsutils

This package includes several handy DNS utilities that were written to
demonstrate the DNS library I wrote, [Nesser](https://github.com/iagox86/nesser)!

See the Usage section below for details.

## Installation

Simply run:

    $ gem install dnsutils

...as root, if you want it to install as a system utility. If you're using rvm,
you probably don't need root.

## Usage

This currently comes with several different utilities, and will likely have more
in the future!

### dnslogger

`dnslogger` is a simple DNS server that listens for queries, displays them, and
responds with :NXDomain (domain not found) by default.

The simplest usage is to run it without any arguments:

    # dnslogger
    Starting dnslogger (DnsUtils) 2.0.0 DNS server on 0.0.0.0:53

Then to make requests, either directly:

    $ dig @localhost -t A example.org
    
    ; <<>> DiG 9.10.3-P4-Ubuntu <<>> @localhost -t A example.org
    ; (1 server found)
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 48472
    ;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 0
    
    ;; QUESTION SECTION:
    ;example.org.                   IN      A
    
    ;; Query time: 1 msec
    ;; SERVER: 127.0.0.1#53535(127.0.0.1)
    ;; WHEN: Sun Jul 09 19:04:11 PDT 2017
    ;; MSG SIZE  rcvd: 29

Or, if you're on an authoritative server, indirectly:

    $ dig -t A test.skullseclabs.org
    
    ; <<>> DiG 9.10.3-P4-Ubuntu <<>> -t A test.skullseclabs.org
    ; (1 server found)
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 31731
    ;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 0
    
    ;; QUESTION SECTION:
    ;test.skullseclabs.org.         IN      A
    
    ;; Query time: 0 msec
    ;; SERVER: 127.0.0.1#53535(127.0.0.1)
    ;; WHEN: Sun Jul 09 19:05:10 PDT 2017
    ;; MSG SIZE  rcvd: 39

You'll notice that in both cases, the status came back as NXDOMAIN (name not
found), and no answers were given. That's expected! In the dnslogger window,
you will see the requests:

    IN: Request for example.org [A IN]
    OUT: Response for example.org [A IN]: error: :NXDomain (RCODE_NAME_ERROR)
    IN: Request for test.skullseclabs.org [A IN]
    OUT: Response for test.skullseclabs.org [A IN]: error: :NXDomain (RCODE_NAME_ERROR)

You can also provide records of various types that will always be returned (note
that I'm running this on a non-privileged port now, so I don't have to use
root):

    $ dnslogger --port 53535 --A 1.2.3.4 --TXT 'this is txt'
    Starting dnslogger (DnsUtils) 2.0.0 DNS server on 0.0.0.0:53535

And that will be returned:

    $ dig @localhost +short -t A -p 53535 test.com
    1.2.3.4
    $ dig @localhost +short -t ANY -p 53535 test.com
    1.2.3.4
    "this is txt"

You can also provide a passthrough address, which will send all requests that
don't match one of the records you handle upstream:

    $ dnslogger --port 53535 --A 1.2.3.4 --passthrough 8.8.8.8:53
    Starting dnslogger (DnsUtils) 2.0.0 DNS server on 0.0.0.0:53535

And on the client:

    $ dig @localhost +short -t A -p 53535 google.com
    1.2.3.4
    $ dig @localhost +short -t MX -p 53535 google.com
    20 alt1.aspmx.l.google.com.
    50 alt4.aspmx.l.google.com.
    30 alt2.aspmx.l.google.com.
    10 aspmx.l.google.com.
    40 alt3.aspmx.l.google.com.

That can be useful for stealth, although I kinda prefer using the :NXDomain
approach, since it looks like literally nothing is there. :)

Note that this only makes sense to use if you expect somebody to query you
directly - you don't want to send your own authoritative requests upstream
because that would cause an infinite loop. So definitely use passthrough
sparingly. :)

### dnstest

`dnstest` is used to determine whether or not you're actually running on an
authoritative DNS server for the domain you specify.

This is done by generating a random subdomain, and prepending that in front of
the domain name. That domain is sent to an upstream DNS server (8.8.8.8 by
default), and we check if the request makes it back to us.

Typically, you'll simply run it with `--domain` set to your domain name:

    # dnstest --domain skullseclabs.org
    This script determines if you hold the authoritative record for a domain by
    sending a request for a random subdomain. If the request goes through, you hold
    the record!
    --
    Starting dnstest (DnsUtils) 2.0.0 DNS server on 0.0.0.0:53...
    
    (Listening for yzpvshufndyqkhdd.skullseclabs.org)
    (Requesting yzpvshufndyqkhdd.skullseclabs.org from 8.8.8.8:53)
    Got a response from the DNS server, but didn't see the request... you probably don't have the authoritative server. :(
    
    DNS RESPONSE: id=0x50f1, opcode = OPCODE_QUERY, flags = RD|RA, rcode = :ServFail (RCODE_SERVER_FAILURE)
    , qdcount = 0x0001, ancount = 0x0000
        Question: yzpvshufndyqkhdd.skullseclabs.org [A IN]

In that case, it failed because I'm not running on the authoritative server; in
fact, nothing is running there, so the upstream DNS server returned :ServFail.

If you try to request a domain that exists, but that you aren't the authority
for, you get a similar error:

    # dnstest --domain google.com
    This script determines if you hold the authoritative record for a domain by
    sending a request for a random subdomain. If the request goes through, you hold
    the record!
    --
    Starting dnstest (DnsUtils) 2.0.0 DNS server on 0.0.0.0:53...
    
    (Listening for jqjvzkyhttbxoqlt.google.com)
    (Requesting jqjvzkyhttbxoqlt.google.com from 8.8.8.8:53)
    Got a response from the DNS server, but didn't see the request... you probably don't have the authoritative server. :(
    
    DNS RESPONSE: id=0x2ef4, opcode = OPCODE_QUERY, flags = RD|RA, rcode = :NXDomain (RCODE_NAME_ERROR), qd
    count = 0x0001, ancount = 0x0000
        Question: jqjvzkyhttbxoqlt.google.com [A IN]

You'll notice that this time, the rcode was :NXDomain, aka, not found. And
finally, if you ARE running on the authoritative server, you'll get a happy
little message telling you so:

    $ dnstest --domain skullseclabs.org
    This script determines if you hold the authoritative record for a domain by
    sending a request for a random subdomain. If the request goes through, you hold
    the record!
    --
    Starting dnstest (DnsUtils) 2.0.0 DNS server on 0.0.0.0:53...
    
    (Listening for blyonrwrwjpyugvc.google.com)
    (Requesting blyonrwrwjpyugvc.google.com from localhost:53535)
    (Received: blyonrwrwjpyugvc.google.com [A IN])
    You have the authoritative server!

And that's pretty much all there is to it!

### dnslazy

A simple utility that lets you put the IP address you want in the domain name.
For example, 1.2.3.4.domain.com will resolve to 1.2.3.4.

It's simply run with no special arguments

    $ dnslazy

It currently only supports IPv4.

### dnsmastermind

`dnsmastermind` is a silly little game I wrote to demonstrate how DNS works.

It's based on the classic Mastermind game, where the player guesses a sequence
(in this case, of letters), and the server tells them how many are right, and
how many of them are in the right place.

I don't imagine any real-world use for it, so I'm not going to spend a lot of
time talking about usage. It essentially works the same way as other scripts.

I'll simply demonstrate it running locally on a non-privileged port (but it
will, like other scripts, work just fine indirectly if you're on the
authoritative server for the domain):

    $ dnsmastermind --port 53535 --solution ABCD
    Starting dnsmastermind (DnsUtils) 2.0.0 DNS server on 0.0.0.0:53535

The players can simply send a TXT request to get the instructions:

    $ dig @localhost +short -t TXT -p 53535 instructions.test.com
    "Instructions: guess the 4-character string: dig -t txt [guess].test.com! 'O' = correct, 'X' = correct, but wrong position"

And guess the solution the same way:

    $ dig @localhost +short -p 53535 AAAA.test.com
    "O"
    $ dig @localhost +short -p 53535 AAAB.test.com
    "OX"
    $ dig @localhost +short -p 53535 ABCC.test.com
    "OOO"
    $ dig @localhost +short -p 53535 ABCD.test.com
    "YOU WIN!!"

An 'O' represents the right character in the right place, and an 'X' represents
the right character in the wrong place.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iagox86/dnsutils

I'm also happy to take requests on other simple DNS utilities that can be
written with this library.

If you sent a pull request, please try to follow my style as much as possible!
There are no tests for these utilities, so be warned. :)

## Version history / changelog

* 0.x and 1.x - Old versions - never built as gems
* 2.0.0 - Initial port from the old DNS architecture
* 2.0.1 - Small documentation updates
* 2.0.2 - Add support for PTR records (reverse DNS)
* 2.0.3 - Added dnslazy
