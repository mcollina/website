
Webgen::WebsiteAccess.website.config.data["contentprocessor.tags.map"]['t'] = 'I18n'

Webgen::WebsiteAccess.website.config.tag.i18n.key(nil, :doc => 'The key to translate', :mandatory => 'default')

unless Object.const_defined?(:I18n)
  class I18n

    include Webgen
    include Tag::Base

    def call(tag, body, context)
      current_locale = locales[context.node.lang]

      key = param('tag.i18n.key').strip
      [current_locale, locales[context.website.config["website.lang"]]].each do |loc|
        value = select_value(key.split("."), loc)
        return value unless value.nil?
      end
      raise "Missing translation of value: #{key}"
    end

    def locales
      return @locales if @locales

      @locales = Hash.new({})
      
      require 'yaml'
      Dir.glob(File.join(WebsiteAccess.website.directory, "locales", "*")) do |file|
        lang = File.basename(file).gsub(/\.yml$/,'')
        @locales[lang] = YAML.load_file(file)
      end
      @locales
    end

    private

    def select_value(keys, hash)
      key = keys.shift
      return nil unless hash.has_key? key
      return hash[key] if keys.empty?
      select_value(keys, hash[key])
    end

    def tag_config_base
      "tag.i18n"
    end
  end
end
