
class PostAdder

  POST_PATH = "/blog/**/*"

  LANGUAGES = ["en", "it"]

  KEY = :post_added

  def call(context)
    node = context.node
    if not node.node_info.has_key? KEY and Webgen::Path.match(node.path, POST_PATH)
      node.node_info[KEY] = true
      destination_languages = LANGUAGES.dup
      destination_languages.delete(node.lang)

      destination_languages.each do |lang|
        dest_path = Webgen::Path.lcn(node.path, lang)
        dest_info = node.meta_info.dup
        dest_info["lang"] = lang

        new_node = Webgen::Node.new(node.parent, dest_path, node.cn, dest_info)
        node.node_info.each do |k,v|
          v = v.clone unless v == true or v == false
          new_node.node_info[k] = v
        end
      end
    end
    context
  rescue Exception => e
    raise "Error while creating post nodes: #{e.message}"
  end
end