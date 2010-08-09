require "#{RAILS_ROOT}/lib/graylog2-websocket.rb"

Thread.new {
  server = Graylog2::WebSocketServer.new
  server.launch
}
