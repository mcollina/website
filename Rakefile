# -*- ruby -*-

require 'webgen/webgentask'
require 'net/ssh'
require 'net/scp'

task :default => :webgen

Webgen::WebgenTask.new do |website|
  website.clobber_outdir = true
  website.config_block = lambda do |config|
    # you can set configuration options here
  end
end

desc "Render the website automatically on changes"
task :auto_webgen do
  puts 'Starting auto-render mode'
  time = Time.now
  abort = false
  old_paths = []
  Signal.trap('INT') {abort = true}

  while !abort
    # you may need to adjust the glob so that all your sources are included
    paths = Dir['src/**/*'].sort
    if old_paths != paths || paths.any? {|p| File.mtime(p) > time}
      begin
        Rake::Task['webgen'].execute({})
      rescue Webgen::Error => e
        puts e.message
      end
    end
    time = Time.now
    old_paths = paths
    sleep 2
  end
end

desc "Runs both clobber_webgen and webgen tasks"
task :clear_and_run => [:clobber_webgen, :webgen]

HOST = "matteocollina.com"
USER = "matteo"
GROUP = "www-data"
REMOTE_DIR = "/home/matteo/public_html"

desc 'Upload the site'
task :deploy => :webgen do

  tmpdir = REMOTE_DIR + ".tmp"
  
  puts "# Logging in to #{HOST}"
  Net::SSH.start(HOST, USER) do |ssh|
    
    puts "# Removing #{tmpdir}"
    ssh.exec! "rm -rf #{tmpdir}/"

    puts "# Uploading out/ to the remote #{HOST}:#{tmpdir}"
    ssh.scp.upload!("out", tmpdir, :recursive => true) do |ch, name, sent, total|
      puts "#{name}: #{sent}/#{total}"
    end
    
    puts "# Changing group to #{GROUP}"
    ssh.exec! "chgrp #{GROUP} #{tmpdir} -R"

    puts "# Removing #{REMOTE_DIR}"
    ssh.exec! "rm -rf #{REMOTE_DIR}/"

    puts "# Moving the generated website to #{REMOTE_DIR}"
    ssh.exec! "mv #{tmpdir} #{REMOTE_DIR}"

    puts "# Removing #{tmpdir}"
    ssh.exec! "rm -rf #{tmpdir}"
  end
end

task :set_disqus_developer do
  Kernel.const_set(:DISQUS_DEVELOPER,true)
end


desc "Generates the site with disqus_developer=1"
task :run_with_disqus_developer => [:set_disqus_developer, :clear_and_run]
