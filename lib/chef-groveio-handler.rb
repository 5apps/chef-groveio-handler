require 'rubygems'
require 'chef'
require 'chef/handler'
require 'net/https'
require 'uri'

class ChefGroveIOHandler < Chef::Handler
  VERSION = '0.0.3'

  def initialize(url_hash)
    @url = "https://grove.io/api/notice/#{url_hash}/"
    @timestamp = Time.now.getutc
  end

  def report
    # build the message
    status = failed? ? "failed" : "succeeded"
   
    message = "chef-client run on #{node[:fqdn]} has #{status}"
    error_lines = []
    
    if failed?
      error_lines << "Error: #{run_status.formatted_exception}"
      error_lines << "Backtrace:"
      error_lines += Array(backtrace)[0..4]
    end

    # notify stdout and via log.error if we have a terminal
    unless STDOUT.tty?
      begin
        timeout(10) do
          uri = URI.parse @url
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri.request_uri)
          request.set_form_data({"service" => "Chef", "message" => message})
          http.request(request)

          error_lines.each do |error_message|
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
