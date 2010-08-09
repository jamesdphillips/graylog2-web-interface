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
      request = ActiveSupport::JSON.decode(msg)
      case request["type"]
        when 'status':
          # okay/problems
        when 'lastmessage':
          message = Message.all_with_blacklist(0, 1)
          message = message[0]
          glsend message.message
        when 'messagecount':
          glsend "maximum: #{request["maximum"]}"
        when 'lastmessages':
      end
    end

    def glsend msg
      puts "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA SENDING: #{msg}"
      @socket.send msg
    end
  end

end