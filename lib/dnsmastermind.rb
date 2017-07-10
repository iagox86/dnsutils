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

module DnsUtils
  MY_NAME = "dnsmastermind (#{NAME}) #{VERSION}"

  Thread.abort_on_exception = true

  # Options
  opts = Trollop::options do
    version(MY_NAME)

    opt :version, "Get the #{MY_NAME} version (spoiler alert!)", :type => :boolean, :default => false
    opt :host, "The ip address to listen on", :type => :string, :default => "0.0.0.0"
    opt :port, "The port to listen on", :type => :integer, :default => 53
    opt :timeout, "The amount of time (seconds) to wait for a response", :type => :integer, :default => 10
    opt :solution,"The answer; should be four letters, unless you're a jerk", :type => :string, :default => nil, :required => true
    opt :win, "The message to display to winners", :type => :string, :default => "YOU WIN!!"
  end

  if(opts[:port] < 0 || opts[:port] > 65535)
    Trollop::die :port, "must be a valid port (between 0 and 65535)"
  end

  if(opts[:solution].include?('.'))
    Trollop::die :solution, "must not contain period; SHOULD only contain [a-z]{4} :)"
  end
  solution = opts[:solution].upcase()

  puts("Starting #{MY_NAME} DNS server on #{opts[:host]}:#{opts[:port]}")

  s = UDPSocket.new()
  nesser = Nesser::Nesser.new(s: s, host: opts[:host], port: opts[:port]) do |transaction|
    begin
      request = transaction.request

      if(request.questions.length < 1)
        puts("The request didn't ask any questions!")
        next
      end

      if(request.questions.length > 1)
        puts("The request asked multiple questions! This is super unusual, if you can reproduce, please report!")
        next
      end

      guess, domain = request.questions[0].name.split(/\./, 2)
      guess.upcase!()

      if(guess == solution)
        puts("WINNER!!!")
        answer = opts[:win]
      elsif(guess.length == solution.length)
        saved_guess = guess
        tmp_solution = solution.chars.to_a()
        guess = guess.chars.to_a()
        answer = ""

        0.upto(tmp_solution.length() - 1) do |i|
          if(tmp_solution[i] == guess[i])
            answer += "O"
            tmp_solution[i] = ""
            guess[i] = ""
          end
        end

        guess.each do |c|
          if(c == "")
            next
          end

          if(tmp_solution.include?(c))
            tmp_solution[tmp_solution.index(c)] = ""
            answer += "X"
          end
        end

        if(answer == "")
          answer = "No correct character; keep trying!"
        end

        puts("Guess: #{saved_guess} => #{answer}")
      else
        puts("Invalid; sending instructions: #{guess}")
        answer = "Instructions: guess the #{solution.length}-character string: dig -t txt [guess].#{domain}! 'O' = correct, 'X' = correct, but wrong position"
      end

      rr = Nesser::TXT.new(data: answer)
      answer = Nesser::Answer.new(
        name: request.questions[0].name,
        type: Nesser::TYPE_TXT,
        cls: Nesser::CLS_IN,
        ttl: 10,
        rr: rr,
      )
      transaction.answer!([answer])
    rescue StandardError => e
      puts("Error: #{e}")
      puts(e.backtrace)
    end
  end

  nesser.wait()
end
