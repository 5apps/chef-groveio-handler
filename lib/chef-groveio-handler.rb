require 'rubygems'
require 'chef'
require 'chef/handler'
require 'net/https'
require 'uri'

class ChefGroveIOHandler < Chef::Handler
  VERSION = '0.0.4'

  def initialize(url_hash, options={})
    @options = options
    @url = "https://grove.io/api/notice/#{url_hash}/"
    @timestamp = Time.now.getutc
  end

  def report
    status = failed? ? "failed" : "succeeded"
    messages = ["chef-client run on #{node[:fqdn]} has #{status}"]

    if failed?
      messages << "Error: #{run_status.formatted_exception}"
      if @options[:backtrace]
        messages << "Backtrace:"
        messages += Array(backtrace)[0..4]
      end
    end

    # notify stdout and via log.error if we have a terminal
    unless STDOUT.tty?
      begin
        timeout(10) do
          uri = URI.parse @url
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          messages.each do |error_message|
            request = Net::HTTP::Post.new(uri.request_uri)
            request.set_form_data({"service" => "Chef", "message" => error_message})
            http.request(request)
          end

          Chef::Log.info("Notified chefs via grove.io")
        end
      rescue Timeout::Error
        Chef::Log.error("Timed out while attempting to message chefs via grove.io")
      end
    end
  end

end
