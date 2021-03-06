# = webgen extensions directory
#
# All init.rb files anywhere under this directory get automatically loaded on a webgen run. This
# allows you to add your own extensions to webgen or to modify webgen's core!
#
# If you don't need this feature you can savely delete this file and the directory in which it is!
#
# The +config+ variable below can be used to access the Webgen::Configuration object for the current
# website.

config = Webgen::WebsiteAccess.website.config

# to add pdfs auto-copy to destination.
config['sourcehandler.patterns']['Webgen::SourceHandler::Copy'] << '**/*.pdf'
config['sourcehandler.patterns']['Webgen::SourceHandler::Copy'] << '**/*.swf'

require File.dirname(__FILE__) + "/i18n_tag.rb"

I18nTag.setup

require File.dirname(__FILE__) + "/thumbnailer.rb"

Thumbnailer.setup

require File.dirname(__FILE__) + "/blog.rb"

Blog.setup

#Webgen::WebsiteAccess.website.logger.verbosity = :verbose


