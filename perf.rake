'.:lib:test:config'.split(':').each { |x| $: << x }

require 'application'
require 'benchmark/ips'

TEST_CNT  = (ENV['KO1TEST_CNT'] || 1_000).to_i
TEST_PATH = ENV['KO1TEST_PATH'] || '/'

Ko1TestApp::Application.initialize!

class NullLog
  def write str
  end
end
$null_logger = NullLog.new

def rackenv path
  {
    "GATEWAY_INTERFACE" => "CGI/1.1",
    "PATH_INFO"         => path,
    "QUERY_STRING"      => "",
    "REMOTE_ADDR"       => "127.0.0.1",
    "REMOTE_HOST"       => "localhost",
    "REQUEST_METHOD"    => "GET",
    "REQUEST_URI"       => "http://localhost:3000#{path}",
    "SCRIPT_NAME"       => "",
    "SERVER_NAME"       => "localhost",
    "SERVER_PORT"       => "3000",
    "SERVER_PROTOCOL"   => "HTTP/1.1",
    "SERVER_SOFTWARE"   => "WEBrick/1.3.1 (Ruby/1.9.3/2011-04-14)",
    "HTTP_USER_AGENT"   => "curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3",
    "HTTP_HOST"         => "localhost:3000",
    "HTTP_ACCEPT"       => "*/*",
    "rack.version"      => [1, 1],
    "rack.input"        => StringIO.new,
    "rack.errors"       => $null_logger,
    "rack.multithread"  => true,
    "rack.multiprocess" => false,
    "rack.run_once"     => false,
    "rack.url_scheme"   => "http",
    "HTTP_VERSION"      => "HTTP/1.1",
    "REQUEST_PATH"      => path
  }
end

def do_test_task app
  _, _, body = app.call(rackenv(TEST_PATH))
  body.each { |_| }
  body.close
end

task :test do
  app = Ko1TestApp::Application.instance
  app.app

  Benchmark.bm { |x|
    x.report("#{TEST_CNT} requests") {
      TEST_CNT.times {
        do_test_task(app)
      }
    }
  }
end

task :test_ips do
  app = Ko1TestApp::Application.instance
  app.app

  Benchmark.ips do |x|
    x.report("requsts") {
      do_test_task(app)
    }
  end
end
