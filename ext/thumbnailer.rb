# Copyright (c) 2009 Matteo Collina
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

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
      "image.width" => 300,
      "image.height" => 300,
      "thumb.width" => 100,
      "thumb.height" => 100,
      "resize" => true,
      "thumb" => true,
      "image.polaroid" => false,
      "thumb.polaroid" => false
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
        main_node["image.height"],
        main_node["image.polaroid"])
    end

    thumb_path = Path.new(dest_path.path.gsub(dest_path.ext, "thumb." + dest_path.ext), path.source_path)
    thumb_path.meta_info.update(path.meta_info)

    if main_node["thumb"]
      nodes << website.blackboard.invoke(:create_nodes, thumb_path, self) do |cn_path|
        update_node(super(cn_path),
          main_node["thumb.width"],
          main_node["thumb.height"],
          main_node["thumb.polaroid"])
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

    if info[:polaroid]
      image.background_color = "none"
      image.format = "PNG"
      image = image.polaroid
    end
   
    image.strip! 

    Path::SourceIO.new do 
	StringIO.new(image.to_blob) { self.quality = 25 }
    end
  end

  private

  def update_node(node, width, height, polaroid)
    node.node_info[:image_width] = width
    node.node_info[:image_height] = height
    node.node_info[:polaroid] = polaroid
    node
  end
end
