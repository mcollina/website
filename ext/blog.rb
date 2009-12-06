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
  
# Adaptations by Damien Pollet, Nov/Dec 2009
  
class Blog

  FILTER = "blog.filter"
  POST_PER_PAGE = "blog.post_per_page"
  POSTS_ITERATOR = "posts"
  LANGUAGES = "blog.languages"
  TAGS = "tags"
  TAG_CLOUD = "tag_cloud"

  def self.setup()
    config = Webgen::WebsiteAccess.website.config

    config.patterns('Blog' => ['**/*.blog'])
    config['sourcehandler.invoke'][5] << 'Blog'
    config['sourcehandler.default_meta_info']['Blog'] = {
      Blog::POST_PER_PAGE => 5
    }
  end

  include Webgen
  include SourceHandler::Base
  include WebsiteAccess

  alias :old_create_node :create_node

  def initialize #:nodoc:
    website.blackboard.add_listener(:node_meta_info_changed?, method(:meta_info_changed?))
  end

  def create_node(path)
    path_page = Page.from_data(path.io.data, path.meta_info)
    meta_info = path_page.meta_info

    unless meta_info.has_key? FILTER
      raise "Missing meta_info '#{FILTER}' for path: #{path.path}"
    end
    if meta_info[POST_PER_PAGE] <= 0
      raise "The meta_info #{POST_PER_PAGE} should be greater than one for path: #{path.path}"
    end

    # select only blog's posts
    posts = website.tree.node_access[:path].values.select do |n|
      Webgen::Path.match(n.path, meta_info[FILTER])
    end
    raise "No node selected by the key: #{FILTER}" if posts.size == 0

    languages = meta_info[LANGUAGES].split(",").map do |lang|
      LanguageManager.language_for_code(lang)
    end
    
    results = create_blog_nodes(path, posts, meta_info[POST_PER_PAGE])

    tags = {}
    posts.each do |post|
      next if post[TAGS].nil?
      post[TAGS] = post[TAGS].split(",")
      post[TAGS].each do |tag|
        tag.strip!
        tags[tag] ||= []
        tags[tag] << post
      end
    end
    
    main_tags_pages = TagsContainer.new

    tags.each do |tag, nodes|
      blog_nodes = create_blog_nodes(path, nodes, meta_info[POST_PER_PAGE]) do |index,total|
        suffix = index == total ? "#{tag.downcase}.html" : "#{tag.downcase}.#{index + 1}.html"
        path.source_path.gsub(/blog$/, suffix)
      end

      main_tags_pages << Tag.new(tag, blog_nodes.first, nodes.size)

      blog_nodes.each do |node|
        node["tag"] = tag
        node["in_menu"] = false
        node["title"] = tag.downcase
      end

      results.concat blog_nodes
    end

    results.each do |blog_node|
      blog_node[TAGS] = main_tags_pages.dup
    end
     
    results.dup.each do |blog_node|
      languages.each do |lang|
        unless blog_node.in_lang(lang)
          blog_node = Blog.create_translated_node(blog_node, lang.to_s)
          
          blog_node[POSTS_ITERATOR] = blog_node[POSTS_ITERATOR].translate(lang)
          blog_node[TAGS] = blog_node[TAGS].translate(lang)

          results << blog_node
        end
      end
    end
    results
  end

  def self.tags(node_path, lang=website.config["website.lang"]) 
    nodes = website.tree.node_access[:acn][node_path]
    raise "There is no node: #{node_path}" if nodes.nil? or nodes.empty?

    nodes.first.in_lang(lang)[TAGS]
  end

  def self.tag_cloud(current_node, blog_node_path, options={})
    TagCloud.new(current_node, tags(blog_node_path, current_node.lang), options)
  end

  def self.create_translated_node(source_node, lang)
    return source_node.in_lang(lang) if source_node.in_lang(lang)

    dest_path = Webgen::Path.lcn(source_node.path, lang)
    dest_info = source_node.meta_info.dup
    dest_info["lang"] = lang

    new_node = Webgen::Node.new(source_node.parent, dest_path, source_node.cn, dest_info)
    new_node.node_info.merge!(source_node.node_info)
    new_node
  end

  private

  # Checks if the meta information provided by the file in Webgen Page Format changed.
  # Or if the
  def meta_info_changed?(node)
    return unless node.node_info.has_key? :created_by_blog

    path = website.blackboard.invoke(:source_paths)[node.node_info[:src]]
      
    if !path
      node.flag(:dirty)
      return
    end

    old_mi = node.node_info[:sh_page_node_mi]
    new_mi = Webgen::Page.meta_info_from_data(path.io.data)
    if old_mi && old_mi != new_mi
      node.flag(:dirty)
      return
    end

    node[POSTS_ITERATOR].each do |post|
      path = website.blackboard.invoke(:source_paths)[post.node_info[:src]]
      node.flag(:dirty) unless path && !path.changed?
    end

  end

  def create_blog_nodes(path, posts, posts_per_page, &path_builder)
    path_builder ||= lambda { |index,total|
      suffix = index == total ? "html" : "#{index + 1}.html"
      path.source_path.gsub(/blog$/, suffix)
    }

    # order them by their creation date, newer posts first
    posts.sort! do |a,b|
      a.meta_info["created_at"] <=> b.meta_info["created_at"]
    end

    # divide posts in pages, starting from the oldest posts
    posts_pages = [[]]
    posts.each do |post|
      posts_pages << [] if posts_pages.last.size >= posts_per_page
      posts_pages.last.unshift post
    end

    # generates nodes
    created_nodes = []
    sourcehandler = SourceHandler::Page.new
    posts_pages.each_index do |index|
      dest_path = Path.new(path_builder.call(index, posts_pages.size-1), path.source_path) do
        StringIO.new(path.io.data)
      end
      created_nodes << website.blackboard.invoke(:create_nodes, dest_path, sourcehandler)
    end
    created_nodes.flatten!

    # fill every node with its meta informations
    # the lower the index, the oldest the articles
    # the articles are displaied starting from the latest, so the next node
    # as an index lower than the current node, while the previous node is the
    # element with index greater than the current node.
    created_nodes.each_with_index do |node, index|
      next_node = (index > 0) ? created_nodes[index-1] : nil
      prev_node = (index < created_nodes.size - 1) ? created_nodes[index+1] : nil
      node[POSTS_ITERATOR] = PostsIterator.new(posts_pages[index],prev_node,next_node)
      node['in_menu'] = node['in_menu'] && prev_node.nil?

      [:used_meta_info_nodes, :used_nodes].each do |key|
        node[key] ||= []
        node[key] = node[key].concat(posts_pages[index])
      end

      node.node_info[:created_by_blog] = true
    end
    created_nodes
  end

  private

  class PostsIterator

    include Enumerable

    attr_reader :next_node
    attr_reader :prev_node
    attr_reader :posts

    def initialize(posts, prev_node, next_node)
      @posts = posts
      @prev_node = prev_node
      @next_node = next_node
    end

    def each(&block)
      @posts.each(&block)
    end

    def first?
      prev_node.nil?
    end

    def last?
      next_node.nil?
    end

    def dup
      PostsIterator.new(posts.dup, prev_node, next_node)
    end

    alias :clone :dup

    def translate!(lang)
      posts.map! do |n|
      	Blog.create_translated_node(n, lang)
      end
      self
    end
    
    def translate(lang)
      dup.translate!(lang)
    end
  end

  class Tag

    include Webgen
    include WebsiteAccess

    attr_accessor :name, :size

    def initialize(name=nil, node=nil, size=nil)
      self.name = name
      self.node = node
      self.size = size
    end

    def node
      node = website.tree.node_access[:alcn][@node_alcn]
      raise "There is no node: #{blog_node_path}" unless node
      node
    end

    def node=(node)
      if node.respond_to?(:alcn)
        @node_alcn = node.alcn
      else
        @node_alcn = node
      end
      node
    end

    def dup
      Tag.new(@name, @node_alcn, @size)
    end
  end

  class TagsContainer

    include Enumerable

    def initialize(tags=[])
      fill(tags)
    end

    def each(&block)
      @tags.values.each(&block)
    end

    def tags
      @tags.values
    end

    def tags=(tags)
      fill(tags)
    end

    def [](name)
      @tags[name]
    end

    def dup
      new_tags = tags.map { |tag| tag.dup }
      TagsContainer.new(new_tags)
    end

    def add(tag)
      @tags[tag.name] = tag
    end

    def delete(tag)
      @tags.delete(tag.name)
    end

    alias :<< :add

    def map!(&block)
      self.tags = map(&block)
    end

    def translate!(lang)
      each do |tag|		
        tag.node = Blog.create_translated_node(tag.node, lang)
      end
      self
    end

    def translate(lang)
      dup.translate!(lang)
    end

    private
    def fill(tags)
      reset
      tags.each { |tag| add(tag) }
      tags
    end

    def reset()
      @tags = Hash.new
    end
  end

  # Create a Tag Cloud from an array of tags
  class TagCloud
    attr_accessor :css_class, :base_tag_size, :line_length
    attr_accessor :node, :tags

    def initialize(node, tags, options={})
      @tags = tags.sort { |a,b| a.name <=> b.name }
      @cloud = nil
      @css_class = options[:css_class]
      @base_tag_size = options[:base_tag_size] || 5
      @line_length = options[:line_length] || 4
      @node = node
    end

    def font_ratio
      min, max = 1000000, -1000000
      tags.each do |tag|
        max = tag.size if tag.size > max
        min = tag.size if tag.size < min
      end
      18 / (max - min)
    end

    def build

      cloud = String.new
      i = 0
      tags.each do |tag|
        cloud << "<div>" if i % line_length == 0
        i += 1

        font_size = (base_tag_size + (tag.size * font_ratio))
        cloud << %Q{<span#{" class=\"" + css_class + "\"" unless css_class.nil? }>}
        cloud << %Q{<a href="#{node.route_to(tag.node)}" }
        cloud << %Q{style="font-size: #{font_size}pt;">#{tag.name}</a></span>}

        cloud << "</div>" if i % line_length == 0

        cloud << "\n"
      end

      cloud << "</div>" if i % line_length != 0

      cloud
    end

    def to_s
      return @cloud unless @cloud.nil?
      @cloud = build
    end
  end
end


