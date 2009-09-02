
Webgen::WebsiteAccess.website.config.data["contentprocessor.map"]['translator'] = 'Translator'

unless Object.const_defined?(:Translator)
  class Translator

    KEY = :translated

    def call(context)
      node = context.node
      if not node.node_info.has_key? KEY
        node.node_info[KEY] = true

        destination_languages = languages(context).dup
        destination_languages.delete_if { |lang| node.in_lang(lang) }

        destination_languages.each do |lang|
          dest_path = Webgen::Path.lcn(node.path, lang)
          dest_info = node.meta_info.dup
          dest_info["lang"] = lang

          new_node = Webgen::Node.new(node.parent, dest_path, node.cn, dest_info)
          new_node.node_info.merge!(node.node_info)
        end
      end
      context
    rescue Exception => e
      raise "Error while creating post nodes: #{e.message}"
    end

    def languages(context)
      context.website.config['translator.languages']
    end
  end

end