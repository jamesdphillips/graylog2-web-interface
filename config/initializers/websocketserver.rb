require "#{RAILS_ROOT}/lib/graylog2-websocket.rb"

Thread.new do
  server = Graylog2::WebSocketServer.new
  server.launch
end
