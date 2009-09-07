
config = Webgen::WebsiteAccess.website.config

config.patterns('Thumbnailer' => ['**/*.image'])
config['sourcehandler.invoke'][5] << 'Thumbnailer'
config['sourcehandler.default_meta_info']['Thumbnailer'] = {
  "image.width" => nil,
  "image.height" => nil,
  "thumb.width" => nil,
  "thumb.height" => nil,
  "resize" => true,
  "thumb" => true
}

config.thumbnailer.image.width(500, :doc => 'The max width of the processed image.')
config.thumbnailer.image.height(500, :doc => 'The max height of the processed image.')

config.thumbnailer.thumb.width(75, :doc => 'The max width of the processed thumbnail.')
config.thumbnailer.thumb.height(75, :doc => 'The max height of the processed thumbnail.')

config.thumbnailer.resize(true, :doc => 'The thumbnailer resize every image by default, but you can disable it.')
config.thumbnailer.thumb(true, :doc => 'The thumbnailer thumb every image by default, but you can disable it.')

unless Object.const_defined?(:Thumbnailer)
  require 'RMagick'
  require 'stringio'

  class Thumbnailer
    include Webgen
    include SourceHandler::Base
    include WebsiteAccess

    def create_node(path)
      nodes = []
      
      dest_path = Path.new(path.path.gsub(/\.image/,''), path.source_path)
      dest_path.meta_info.update(path.meta_info)

      if info(dest_path,"resize")
        nodes << website.blackboard.invoke(:create_nodes, dest_path, self) do |cn_path|
          update_node(super(cn_path),
            info(cn_path,"image.width"),
            info(cn_path,"image.height"))
        end
      end

      thumb_path = Path.new(dest_path.path.gsub(dest_path.ext, "thumb." + dest_path.ext), path.source_path)
      thumb_path.meta_info.update(path.meta_info)

      if info(dest_path,"thumb")
        nodes << website.blackboard.invoke(:create_nodes, thumb_path, self) do |cn_path|
          update_node(super(cn_path),
            info(cn_path,"thumb.width"),
            info(cn_path,"thumb.height"))
        end
      end

      nodes.flatten
    end

    def content(node)
      info = node.node_info

      unless info.has_key? :image_width and info.has_key? :image_height
        raise "Missing :image_width and :image_height"
      end

      io = website.blackboard.invoke(:source_paths)[info[:src]].io
      image = Magick::Image.from_blob(io.data).first
      image.resize_to_fit!(info[:image_width], info[:image_height])
      Path::SourceIO.new { StringIO.new(image.to_blob) }
    end

    private

    def update_node(node, width, height)
      node.node_info[:image_width] = width
      node.node_info[:image_height] = height
      node
    end

    def info(node, key)
      node.meta_info[key] ? node.meta_info[key] : website.config["thumbnailer." + key]
    end

  end
end