
require 'RMagick'
require 'stringio'

class Thumbnailer
  include Webgen
  include SourceHandler::Base
  include WebsiteAccess

  def self.setup
    config = Webgen::WebsiteAccess.website.config

    config.patterns('Thumbnailer' => ['**/*.image'])
    
    config['sourcehandler.invoke'][5] << 'Thumbnailer'
    config['sourcehandler.default_meta_info']['Thumbnailer'] = {
      "image.width" => 500,
      "image.height" => 500,
      "thumb.width" => 100,
      "thumb.height" => 100,
      "resize" => true,
      "thumb" => true
    }
  end

  def create_node(path)
    nodes = []

    dest_path = Path.new(path.path.gsub(/\.image/,''), path.source_path)
    dest_path.meta_info.update(path.meta_info)

    nodes << website.blackboard.invoke(:create_nodes, dest_path, self) do |cn_path|
      super(cn_path)
    end
    nodes.flatten!
    main_node = nodes.first

    if main_node["resize"]
      update_node(main_node,
        main_node["image.width"],
        main_node["image.height"])
    end

    thumb_path = Path.new(dest_path.path.gsub(dest_path.ext, "thumb." + dest_path.ext), path.source_path)
    thumb_path.meta_info.update(path.meta_info)

    if main_node["thumb"]
      nodes << website.blackboard.invoke(:create_nodes, thumb_path, self) do |cn_path|
        update_node(super(cn_path),
          main_node["thumb.width"],
          main_node["thumb.height"])
      end
    end

    nodes.flatten!
  end

  def content(node)
    info = node.node_info

    io = website.blackboard.invoke(:source_paths)[info[:src]].io
    image = Magick::Image.from_blob(io.data).first

    if info.has_key? :image_width and info.has_key? :image_height
      image.resize_to_fit!(info[:image_width], info[:image_height])
    end
      
    Path::SourceIO.new { StringIO.new(image.to_blob) }
  end

  private

  def update_node(node, width, height)
    node.node_info[:image_width] = width
    node.node_info[:image_height] = height
    node
  end
end