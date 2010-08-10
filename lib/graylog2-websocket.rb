require 'em-websocket'
require 'json'

module Graylog2

  class WebSocketServer
    def launch
      EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |@socket|
        @socket.onmessage do |msg|
          handle msg
        end
      end
    end

    def handle msg
      begin
        request = ActiveSupport::JSON.decode msg
        case request["type"]
          when "status":
            if Message.count_of_last_minutes(request["interval"].to_i) > request["maximum"].to_i
              glsend "0", "status"
            else
              glsend "1", "status"
            end

          when "lastmessage":
            message = Message.all_with_blacklist 0, 1
            message = message[0]
            glsend "#{Time.at(message.created_at).to_s}: #{message.message}", "lastmessage"

          when "messagecount":
            count = Message.count_of_last_minutes request["interval"]
            glsend count.to_s, "messagecount"

          when "lastmessages":
        end
      rescue => e
        puts "ERROR: " + e
        glsend "error"
      end
    end

    def glsend msg, type = "system"
      begin
        @socket.send ActiveSupport::JSON.encode({ "m" => msg, "t" => type })
      rescue
      end
    end
  end

end