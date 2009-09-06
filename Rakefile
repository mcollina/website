# -*- ruby -*-
#
# This is a sample Rakefile to which you can add tasks to manage your website. For example, users
# may use this file for specifying an upload task for their website (copying the output to a server
# via rsync, ftp, scp, ...).
#
# It also provides some tasks out of the box, for example, rendering the website, clobbering the
# generated files, an auto render task,...
#

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

HOST = "95.154.208.211"
USER = "matteo"
GROUP = "www-data"
REMOTE_DIR = "/var/www/mysite"

desc 'Upload the site'
task :deploy => :default do
  Net::SSH.start(HOST, USER) do |ssh|
    puts "Removing #{REMOTE_DIR}"
    ssh.exec! "rm -rf #{REMOTE_DIR}/*"

    Net::SCP.start(HOST, USER) do |scp|
      Dir.glob("out/*") do |filename|
        puts "Uploading recursively #{filename}"
        scp.upload! filename,  REMOTE_DIR, :recursive => true
      end
    end

    puts "Changing group to #{GROUP}"
    ssh.exec! "chgrp #{GROUP} #{REMOTE_DIR} -R"
  end
end
