#!/usr/bin/env ruby

require 'pty'
require 'goliath'

$connection = nil

class Server < Goliath::API
  def response(env)
    case env['PATH_INFO']
    when '/qualifi.js'
      [200, {}, File.read('qualifi.js')]
    when '/events'
      $connection = env
      streaming_response(200, {'Content-Type' => "text/event-stream"})
    else
      [200, {}, '<script src="qualifi.js"></script>']
    end
  end
end

def read_all(io, n=1)
  buffer = String.new
  loop { buffer << io.read_nonblock(1) }
rescue IO::WaitReadable
  return buffer
end

MAC_REGEX = /[ST]A:((?:[0-9a-f]{2}:){5}(?:[0-9a-f]){2})/
DB_REGEX = /-(\d+)dB signal/
MAX_MAC = 281_474_976_710_655

MIN_FREQ = 300
MAX_FREQ = 1200

Thread.abort_on_exception = true

Thread.new do
  filter = 'type mgt or type ctl' # + 'and not wlan host 88:1f:a1:00:e8:ae'
  PTY.spawn("tcpdump -I -e -ttt -B 1 -i en0 #{filter}") do |tcpdump, _, _|
    while IO.select([tcpdump])
      Thread.new(read_all(tcpdump, 1024)) do |bytes|
        bytes.lines.inject(nil) do |offset, line|
          db = line.scan(DB_REGEX)[0]
          db.nil? ? next : db = db.first.to_i

          mac = line.scan(MAC_REGEX)[0]
          mac.nil? ? next : mac = mac.first.delete!(':').to_i(16)

          # if offset.nil?
          #  offset = 0
          # else
          #  offset += line[6..14].to_f
          # end

          amplitude = (100 - db) / 100.0
          frequency = mac.fdiv(MAX_MAC)*(MAX_FREQ-MIN_FREQ) + MIN_FREQ
          $connection.stream_send("data:#{amplitude},#{frequency}\n\n") unless $connection.nil?

          # next offset
        end
      end
    end
  end
end
