require "git"
require "json"
require "erb"
require "ostruct"
require "time"

RAILS_GIT_PATH   = ENV['RAILS_GIT_PATH']   || "../rails"
RESULT_JSON_PATH = ENV['RESULT_JSON_PATH'] || "results.json"

# $ rake -f bench.rake backfill_commits[100]
task :backfill_commits, [:count] do |t, args|
  count = (args[:count] || 10).to_i
  results = begin
    JSON.parse(File.read(RESULT_JSON_PATH))
  rescue
    {}
  end

  # Get latest commits from rails
  git = Git.open RAILS_GIT_PATH
  commits = git.log(count)
  commits.each do |commit|
    if results[commit.sha].nil?
      results[commit.sha] = { commit: { sha: commit.sha,
                                        message: commit.message,
                                        date: commit.date.iso8601,
                                        author: commit.author.email,
                                        committer: commit.committer.email } }
    end
  end

  # Write the results to the file
  File.open(RESULT_JSON_PATH, "w+") { |file| file.write results.to_json }
end

task :backfill_perf do
  results = JSON.parse(open(RESULT_JSON_PATH).read || "{}")

  results.keys.each do |sha|
    if results[sha]["gc:/users/sign_in"].nil?
      run_perf_for sha
    end
  end
end

task :build_perf_html do
  results = JSON.parse(open(RESULT_JSON_PATH).read || "{}")

  ips_home = results.keys.map do |sha|
    results[sha]["commit"].merge(results[sha]["ips:/"]) unless results[sha]["ips:/"].nil?
  end.reject(&:nil?).sort_by { |commit| commit["date"] }
  ips_login = results.keys.map do |sha|
    results[sha]["commit"].merge(results[sha]["ips:/users/sign_in"]) unless results[sha]["ips:/users/sign_in"].nil?
  end.reject(&:nil?).sort_by { |commit| commit["date"] }
  gc_home = results.keys.map do |sha|
    results[sha]["commit"].merge(results[sha]["gc:/"]) unless results[sha]["gc:/"].nil?
  end.reject(&:nil?).sort_by { |commit| commit["date"] }
  gc_login = results.keys.map do |sha|
    results[sha]["commit"].merge(results[sha]["gc:/users/sign_in"]) unless results[sha]["gc:/users/sign_in"].nil?
  end.reject(&:nil?).sort_by { |commit| commit["date"] }

  namespace = OpenStruct.new ips_home: ips_home, ips_login: ips_login,
                             gc_home:   gc_home, gc_login:   gc_login

  html = ERB.new(html_erb).result(namespace.instance_eval { binding })
  File.open("report.html", "w+") { |file| file.write html }
  `open report.html`
end

def run_perf_for sha
  opts = { KO1RAILS_SHA: sha }

  env = opts.map { |k,v| "#{k}=#{v}" }.join " "
  puts `rm Gemfile.lock`
  puts `#{env} bundle update`
  puts `#{env} bundle install`

  opts[:KO1TEST_PATH] = "/"
  env = opts.map { |k,v| "#{k}=#{v}" }.join " "
  puts `#{env} bundle exec rake -f perf.rake test_ips`

  opts[:KO1TEST_PATH] = "/users/sign_in"
  env = opts.map { |k,v| "#{k}=#{v}" }.join " "
  puts `#{env} bundle exec rake -f perf.rake test_ips`

  opts[:KO1TEST_PATH] = "/"
  env = opts.map { |k,v| "#{k}=#{v}" }.join " "
  puts `#{env} bundle exec rake -f perf.rake gc`

  opts[:KO1TEST_PATH] = "/users/sign_in"
  env = opts.map { |k,v| "#{k}=#{v}" }.join " "
  puts `#{env} bundle exec rake -f perf.rake gc`

  # Reset the gemfile afterwards
  puts `git checkout -- Gemfile*`

end

def html_erb
  <<-eos
    <html><head>
    <link rel="stylesheet" href="http://cdn.oesmith.co.uk/morris-0.4.3.min.css">
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js"></script>
    <script src="http://cdnjs.cloudflare.com/ajax/libs/raphael/2.1.0/raphael-min.js"></script>
    <script src="http://cdn.oesmith.co.uk/morris-0.4.3.min.js"></script>
    </head><body>

    <h2>IPS: Homepage</h2>
    <div id="ips_home" style="height: 250px;"></div>

    <h2>IPS: Login</h2>
    <div id="ips_login" style="height: 250px;"></div>

    <h2>GC: Homepage</h2>
    <div id="gc_home" style="height: 250px;"></div>

    <h2>GC: Login</h2>
    <div id="gc_login" style="height: 250px;"></div>

    <script language="javascript">
      $(function() {
        Morris.Line({
          element: 'ips_home',
          data: <%= ips_home.to_json %>,
          xkey: 'date',
          ykeys: ['ips'],
          labels: ['ips'],
          hideHover: 'auto',
          hoverCallback: function (index, options, content) {
            var row = options.data[index];
            return '<p><b><a href="https://github.com/rails/rails/commit/' + row.sha + '">' + row.sha + '</a></b>' +
                    '<br>by ' + row.author + ' on ' + row.date + '</p>' +
                   $('<p/>').text(row.message).html() +
                   '<p><b>ips:</b> ' + row.ips + '<br>' +
                   '<b>iterations:</b> ' + row.iterations + '<br>' +
                   '<b>ips_sd:</b> ' + row.ips_sd + '<br>' +
                   '<b>measurement_cycle:</b> ' + row.measurement_cycle + '</p>';
          }
        });

        Morris.Line({
          element: 'ips_login',
          data: <%= ips_login.to_json %>,
          xkey: 'date',
          ykeys: ['ips'],
          labels: ['ips'],
          hideHover: 'auto',
          hoverCallback: function (index, options, content) {
            var row = options.data[index];
            return '<p><b><a href="https://github.com/rails/rails/commit/' + row.sha + '">' + row.sha + '</a></b>' +
                    '<br>by ' + row.author + ' on ' + row.date + '</p>' +
                   $('<p/>').text(row.message).html() +
                   '<p><b>ips:</b> ' + row.ips + '<br>' +
                   '<b>iterations:</b> ' + row.iterations + '<br>' +
                   '<b>ips_sd:</b> ' + row.ips_sd + '<br>' +
                   '<b>measurement_cycle:</b> ' + row.measurement_cycle + '</p>';
          }
        });

        Morris.Line({
          element: 'gc_home',
          data: <%= gc_home.to_json %>,
          xkey: 'date',
          ykeys: ['gc_count'],
          labels: ['gc_count'],
          hideHover: 'auto',
          hoverCallback: function (index, options, content) {
            var row = options.data[index];
            return '<p><b><a href="https://github.com/rails/rails/commit/' + row.sha + '">' + row.sha + '</a></b>' +
                    '<br>by ' + row.author + ' on ' + row.date + '</p>' +
                   $('<p/>').text(row.message).html() +
                   '<p><b>gc_count:</b> ' + row.gc_count + '<br>' +
                   '<b>total_time:</b> ' + row.total_time + '</p>' +
                   '<p><a href="javascript:alert(\\'' + row.result + '\\');">report</a></p>';
          }
        });

        Morris.Line({
          element: 'gc_login',
          data: <%= gc_login.to_json %>,
          xkey: 'date',
          ykeys: ['gc_count'],
          labels: ['gc_count'],
          hideHover: 'auto',
          hoverCallback: function (index, options, content) {
            var row = options.data[index];
            return '<p><b><a href="https://github.com/rails/rails/commit/' + row.sha + '">' + row.sha + '</a></b>' +
                    '<br>by ' + row.author + ' on ' + row.date + '</p>' +
                   $('<p/>').text(row.message).html() +
                   '<p><b>gc_count:</b> ' + row.gc_count + '<br>' +
                   '<b>total_time:</b> ' + row.total_time + '</p>' +
                   '<p><a href="javascript:alert(\\'' + row.result + '\\');">report</a></p>';
          }
        });
      });
    </script>
    </body></html>
  eos
end
