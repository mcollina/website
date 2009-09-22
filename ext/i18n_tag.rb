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

# This class provides the tag +t+ which allows a look-up based translation like
# rails i18n. If <tt>{t: a_key}</tt> is provided an string identified
# by <tt>:a_key</tt> will be looked up in the translation files.
# This tag supports object interpolation like rails does, i.e.
# <tt>{t: {key => a_key, object => the_object}}</tt> will search for a string
# identified by <tt>:a_key</tt> and all occurrences of <tt>{{object}}</tt> in
# such string will be replaced by <tt>the_object</tt>.
class I18nTag

  include Webgen
  include Tag::Base

  KEY = "key"

  attr_reader :params

  def self.setup()
    WebsiteAccess.website.config.data["contentprocessor.tags.map"]['t'] = 'I18nTag'
  end

  def call(tag, body, context)
    translation_params = {}
    params.each do |key, value|
      translation_params[key.to_sym] = value
    end
    key = translation_params.delete(KEY.to_sym)
    
    translation_params[:locale] = context.node.lang
    I18n.translate(key, translation_params)
  end

  def create_params_hash(config, node)
    if config.kind_of? Hash
      result = config
    else
      result = {KEY => config}
    end

    result
  end
end
