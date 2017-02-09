# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "socket" # for Socket.gethostname

# Generate a repeating message.
#
# This plugin is intented only as an example.

class LogStash::Inputs::Vatflog < LogStash::Inputs::Base
  config_name "vatflog"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain"

  # The base directory where all test logs are stored
  config :baselogdir, :validate => :uri, :required => true

  # The farm setup whose logs must be process
  config :farm, :validate => :string, :required => true

  # Set how frequently messages should be sent.
  #
  # The default, `3600`, means send a message every hour.
  config :interval, :validate => :number, :default => 3600

  public
  def register
    @host = Socket.gethostname
  end # def register

  def run(queue)
    begin
      while !stop?
        date = Time.now.strftime("%m_%d_%Y")
        sessions = Dir.glob("#{@baselogdir}/#{@farm}/*/#{@farm}#{date}*/session.html").select{|f| (Time.now - File.mtime(f)) <= @interval }
        puts "#{sessions.size} new sessions detected"
        sessions.each {|session_log|
          iter_log =  Dir.glob("#{File.dirname(session_log)}/**/iterZummary.html")[0]
          dut_log = Dir.glob("#{File.dirname(session_log)}/**/dut1*")[0]
          platform_log = `cat #{session_log} | grep Platform`
          message = "#{File.read(dut_log)} =@=@=@ Start of vatf log =@=@=@\n #{File.read(iter_log)} =@=@=@ Start of session log =@=@=@\n #{platform_log}"
          event = LogStash::Event.new("message" => message, "host" => @host)
          decorate(event)
          queue << event
        }
        # because the sleep interval can be big, when shutdown happens
        # we want to be able to abort the sleep
        # Stud.stoppable_sleep will frequently evaluate the given block
        # and abort the sleep(@interval) if the return value is true
        Stud.stoppable_sleep(@interval) { stop? }
      end # loop
    rescue Exception => e
      puts e.to_s
      puts e.backtrace
      raise
    end
  end # def run

  def stop
    # nothing to do in this case so it is not necessary to define stop
    # examples of common "stop" tasks:
    #  * close sockets (unblocking blocking reads/accepts)
    #  * cleanup temporary files
    #  * terminate spawned threads
  end
end # class LogStash::Inputs::Vatflog
