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
REMOTE_DIR = "/home/matteo/public_html"
REMOTE_REPO = "/home/matteo/website/.git"

desc 'Upload the site'
task :deploy do

  git = fork do 
    puts "Uploading to remote git repo"

    git_command = "git push ssh://#{HOST}#{REMOTE_REPO} master"
    puts git_command

    exec *git_command.split(" ")
  end
  Process.waitpid(git)

  Net::SSH.start(HOST, USER) do |ssh|

    remote_basedir = REMOTE_REPO.gsub("/.git","")
    tmpdir = remote_basedir + ".tmp"

    puts "# Creating #{tmpdir}"
    ssh.exec! "rm -rf #{tmpdir}"

    puts "# Cloning #{tmpdir}"
    puts ssh.exec! "git clone #{remote_basedir} #{tmpdir}"

    puts "# Remotely generating the website"
    puts ssh.exec! "cd #{tmpdir} && rake clear_and_run"

    puts "# Removing #{REMOTE_DIR}"
    ssh.exec! "rm -rf #{REMOTE_DIR}/*"

    puts "# Moving the generated website to #{REMOTE_DIR}"
    ssh.exec! "mv #{tmpdir}/out/* #{REMOTE_DIR}"

    puts "# Changing group to #{GROUP}"
    ssh.exec! "chgrp #{GROUP} #{REMOTE_DIR} -R"

    puts "# Cleaning #{tmpdir}"
    ssh.exec! "rm -rf #{tmpdir}"
  end
end
