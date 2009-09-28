require 'i18n'
require 'date'

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
# <tt>{t: {key: a_key, object: the_object}}</tt> will search for a string
# identified by <tt>:a_key</tt> and all occurrences of <tt>{{object}}</tt> in
# such string will be replaced by <tt>the_object</tt>.
# However all meta informations provided by the node will be available.
#
# This class provides also the tag +l+ which allows a look-up based localization
# of times and dates like rails does. This tag requires changes behaviour 
# through the use of different parameters, so only the long tag form is
# possibile.
# The first optional parameter is +key+ and its used to specify an optional
# format for times and dates, which will be looked up in the locale files.
# The second mandatory parameter must be one of the following:
#  * +meta+: identifies a meta information of the node to use as the time
#  (or date) to format, if the node as the meta-info 'created_at' it's possible
#  to use it specifying <tt>{l: {key: a_key, meta: created_at}}</tt>;
#  * +time+: a time in a format parsable by Time.parse;
#  * +date+: a date in a format parsable by Date.parse;
#  * +datetime+: a string identifying a time and a date in a format parsable by
#  DateTime.parse.
class I18nTag

  include Webgen
  include Tag::Base

  KEY = "key"
  META = "meta"
  TIME = "time"
  DATE = "date"
  DATETIME = "datetime"

  attr_reader :params

  def self.setup()
    WebsiteAccess.website.config.data["contentprocessor.tags.map"]['t'] = 'I18nTag'
    WebsiteAccess.website.config.data["contentprocessor.tags.map"]['l'] = 'I18nTag'
  end
  
  def self.build_translation_params(context, params)
    translation_params = {}
    params.each do |key, value|
      translation_params[key.to_sym] = value
    end
    context.node.meta_info.each do |key, value|
      translation_params[key.to_sym] = value
    end

    translation_params[:locale] = context.node.lang.to_s
    translation_params
  end

  def self.t(context, params)
    translation_params = build_translation_params(context, params)
    key = translation_params.delete(KEY.to_sym)
    I18n.translate(key, translation_params)
  end

  def self.l(context, params)
    format_key = (params[KEY]) ? params.delete(KEY).to_sym : nil # nil if there is no KEY
    options = build_translation_params(context, params)
    options[:format] = I18n.translate(format_key, options.dup) if format_key

    if params.size != 1
      raise "Wrong parameters for tag 'l', only one of 'meta', 'time', 'date',"+
      "'datetime' must be provided."
    end

    if params.has_key? META
      object = context.node[params[META]]
    elsif params.has_key? DATE
      object = Date.parse(params[DATE])
    elsif params.has_key? TIME
      object = Time.parse(params[DATETIME])
    elsif params.has_key? DATETIME
      object = DateTime.parse(params[DATETIME])
    end
    
    I18n.localize(object, options)
  end

  def call(tag, body, context)
    self.class.send(tag, context, params)
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