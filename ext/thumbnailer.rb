
config = Webgen::WebsiteAccess.website.config

config.patterns('Thumbnailer' => ['**/*.image'])
config['sourcehandler.invoke'][5] << 'Thumbnailer'

config.thumbnailer.image.width(500, :doc => 'The max width of the processed image.')
config.thumbnailer.image.height(500, :doc => 'The max height of the processed image.')

config.thumbnailer.thumbnail.width(75, :doc => 'The max width of the processed thumbnail.')
config.thumbnailer.thumbnail.height(75, :doc => 'The max height of the processed thumbnail.')


unless Object.const_defined?(:Thumbnailer)
  require 'RMagick'
  require 'stringio'
  
  #  class Thumbnailer
  #
  #    include Webgen
  #    include Tag::Base
  #
  #    def initialize
  #      @source_handler = ImageSourceHandler.new
  #    end
  #
  #    def call(tag, body, context)
  #      self.send(tag.to_sym,context)
  #    end
  #
  #    def image(context)
  #      source_node = find_image_node(context)
  #      dest_path = Path.new(source_node.path)
  #      #dest_path = source_node.path
  #      source_node.tree.delete_node(source_node)
  #      result_node = @source_handler.create_node(dest_path,
  #        param('tag.thumbnailer.image.width'),
  #        param('tag.thumbnailer.image.height')
  #      )
  #      build_img_tag(result_node)
  #    end
  #
  #    def linktoimage(context)
  #      raise NotImplementedError.new
  #    end
  #
  #    def thumbnail(context)
  #      source_node = find_image_node(context)
  #
  #      match = /(\.[a-z]+)$/.match(source_node.path)
  #      dest_path = Path.new(source_node.path.gsub(match[1], ".thumb" + match[1]))
  #      dest_node = @source_handler.create_node(dest_path,
  #        param('tag.thumbnailer.thumbnail.width'),
  #        param('tag.thumbnailer.thumbnail.height')
  #      )
  #      build_img_tag(dest_node)
  #    end
  #
  #    private
  #    def tag_config_base
  #      "tag.thumbnailer"
  #    end
  #
  #    def find_image_node(context)
  #      image_name = param("tag.thumbnailer.image.source")
  #
  #      if context.website.tree.node_access[:path].has_key? image_name
  #        source_node = context.website.tree.node_access[:path][image_name]
  #      elsif context.website.tree.node_access[:path].has_key? File.join(context.node.parent.path, image_name)
  #        source_node = context.website.tree.node_access[:path][File.join(context.node.parent.path, image_name)]
  #      else
  #        potential_nodes = context.website.tree.node_access[:path].values.select do |node|
  #          puts node.path
  #          Webgen::Path.match(node.path,"**/#{image_name}") or node.path == image_name
  #        end
  #        puts potential_nodes.size
  #        source_node = potential_nodes.first
  #      end
  #
  #      raise "No image found: #{image_name}" if source_node.nil?
  #      source_node
  #    end
  #
  #    def build_img_tag(node)
  #      "<img src=\'#{node.path}\'/>"
  #    end
  #  end

  class Thumbnailer
    include Webgen
    include SourceHandler::Base
    include WebsiteAccess

    def create_node(path)
      nodes = []
      
      dest_path = Path.new(path.path.gsub(/\.image/,''), path.source_path)
      dest_path.meta_info.update(path.meta_info)

      nodes << website.blackboard.invoke(:create_nodes, dest_path, self) do |cn_path|
        update_node(super(cn_path),
          website.config["thumbnailer.image.width"],
          website.config["thumbnailer.image.height"])
      end

      thumb_path = Path.new(dest_path.path.gsub(dest_path.ext, "thumb." + dest_path.ext), path.source_path)
      thumb_path.meta_info.update(path.meta_info)
      
      nodes << website.blackboard.invoke(:create_nodes, thumb_path, self) do |cn_path|
        update_node(super(cn_path),
          website.config["thumbnailer.thumbnail.width"],
          website.config["thumbnailer.thumbnail.height"])
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

  end
end