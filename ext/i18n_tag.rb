require 'i18n'

Dir.glob(File.join(Webgen::WebsiteAccess.website.directory, "locales", "*")) do |file|
  I18n.load_path << file
end

module I18n
  # Overriding the default_locale method to reflect webgen configuration.
  def default_locale
    Webgen::WebsiteAccess.website.config["website.lang"]
  end
end

class I18nTag

  include Webgen
  include Tag::Base

  def self.setup()
    WebsiteAccess.website.config.data["contentprocessor.tags.map"]['t'] = 'I18nTag'
    WebsiteAccess.website.config.tag.i18n.key(nil, :doc => 'The key to translate', :mandatory => 'default')
  end

  def call(tag, body, context)
    key = param('tag.i18n.key')
    I18n.translate(key, :locale => context.node.lang)
  end

  private

  def tag_config_base
    "tag.i18n"
  end
end
