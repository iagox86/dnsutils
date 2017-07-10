##
# dnslogger.rb
# Created July 22, 2015
# By Ron Bowes
#
# See: LICENSE.md
#
# Simply checks if you're the authoritative server.
##

require 'nesser'
require 'socket'
require 'trollop'

require_relative 'version'

Thread.abort_on_exception = true

puts <<EOS
This script determines if you hold the authoritative record for a domain by
sending a request for a random subdomain. If the request goes through, you hold
the record!
--
EOS

module DnsUtils
  MY_NAME = "dnstest (#{NAME}) #{VERSION}"

  # Options
  opts = Trollop::options do
    version(MY_NAME)

    opt :version, "Get the #{MY_NAME} version (spoiler alert)", :type => :boolean, :default => false
    opt :host, "The ip address to listen on", :type => :string, :default => "0.0.0.0"
    opt :port, "The port to listen on", :type => :integer, :default => 53
    opt :domain, "The domain to check", :type => :string, :default => nil, :required => true
    opt :timeout, "The amount of time (seconds) to wait for a response", :type => :integer, :default => 10
    opt :upstream, "The upstream DNS server to send requests to, host:port", :type => :string, :default => "8.8.8.8:53"
  end

  if opts[:port] < 0 || opts[:port] > 65535
    Trollop::die(:port, "must be a valid port (between 0 and 65535)")
  end

  if opts[:domain].nil?
    Trollop::die :domain, "Domain is required!"
  end

  upstream_host, upstream_port = opts[:upstream].split(/:/, 2)
  if upstream_host.nil?
    upstream_host = '8.8.8.8'
  end
  if upstream_port.nil?
    upstream_port = 53
  else
    upstream_port = upstream_port.to_i
  end

  puts("Starting #{MY_NAME} DNS server on #{opts[:host]}:#{opts[:port]}...")
  puts()

  # Generate a random subdomain
  domain = (0...16).map { ('a'..'z').to_a[rand(26)] }.join() + "." + opts[:domain]

  s = UDPSocket.new()

  puts("(Listening for #{domain})")
  Nesser::Nesser.new(s: s, host: opts[:host], port: opts[:port]) do |transaction|
    request = transaction.request

    if(request.questions.length < 1)
      puts("The request didn't ask any questions!")
      next
    end

    if(request.questions.length > 1)
      puts("The request asked multiple questions! This is super unusual, if you can reproduce, please report!")
      next
    end

    question = request.questions[0]
    puts("(Received: #{question})")

    # Check if it's the request that we sent
    if(question.type == Nesser::TYPE_A && question.name == domain)
      puts("You have the authoritative server!")

      # Just sent back a name error
      transaction.error!(Nesser::RCODE_NAME_ERROR)
      exit()
    else
      puts("This is not the request we're looking for!")
      transaction.error!(Nesser::RCODE_NAME_ERROR)
    end
  end

  # Perform the request and ignore the result
  puts("(Requesting #{domain} from #{upstream_host}:#{upstream_port})")

  begin
    result = Nesser::Nesser.query(
      s: s,
      hostname: domain,
      server: upstream_host,
      port: upstream_port,
      type: Nesser::TYPE_A,
      cls: Nesser::CLS_IN,
      timeout: opts[:timeout],
    )
    puts("Got a response from the DNS server, but didn't see the request... you probably don't have the authoritative server. :(")
    puts()
    puts(result)
  rescue Nesser::DnsException => e
    puts("Request returned an error... you probably don't have the authoritative server. :(")
    puts()
    puts(e)
  end
end
