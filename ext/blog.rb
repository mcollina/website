
unless Object.const_defined?(:Blog)

  require 'stringio'
  
  class Blog

    FILTER = "blog.filter"
    POST_PER_PAGE = "blog.post_per_page"
    POSTS_ITERATOR = "posts"

    include Webgen
    include SourceHandler::Base
    include WebsiteAccess

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
        Webgen::Path.match(n.path,meta_info[FILTER])
      end

      raise "No node selected by the key: #{FILTER}" if posts.size == 0

      # order them by their creation date, newer posts first
      posts.sort! do |a,b|
        a.meta_info["created_at"] <=> b.meta_info["created_at"]
      end

      # divide posts in pages, starting from the oldest posts
      posts_pages = [[]]
      posts.each do |post|
        posts_pages << [] if posts_pages.last.size >= meta_info[POST_PER_PAGE]
        posts_pages.last.unshift post
      end

      # generates nodes
      created_nodes = []
      page_sourcehandler = SourceHandler::Page.new
      posts_pages.each_index do |index|
        dest_path = Path.new(path.source_path.gsub(/blog$/, "#{index + 1}.html"), path.source_path) do
          StringIO.new(path.io.data)
        end
        created_nodes << website.blackboard.invoke(:create_nodes, dest_path, page_sourcehandler)
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
      end
      created_nodes
    end

    def content(node)
      raise "Should not be called!"
    end
  end

  class PostsIterator

    include Enumerable

    attr_reader :next_node
    attr_reader :prev_node

    def initialize(posts, prev_node, next_node)
      @posts = posts
      @prev_node = prev_node
      @next_node = next_node
    end

    def each(&block)
      @posts.each(&block)
    end

    def first?
      prev_page.nil?
    end

    def last?
      next_node.nil?
    end
  end
end


config = Webgen::WebsiteAccess.website.config

config.patterns('Blog' => ['**/*.blog'])
config['sourcehandler.invoke'][5] << 'Blog'
config['sourcehandler.default_meta_info']['Blog'] = {
  Blog::POST_PER_PAGE => 5
}