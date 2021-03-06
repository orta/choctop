require "fileutils"
require "yaml"
require "builder"
require "erb"
require "uri"
require "osx/cocoa"
require "RedCloth"
require "escape"

require 'choctop/appcast'
require 'choctop/dmg'
require 'choctop/version_helper'
require 'choctop/rake_tasks'

module ChocTop
  class Configuration
    include Appcast
    include Dmg
    include RakeTasks
  
    VERSION = '0.14.1'
  
    attr_writer :build_opts
    def build_opts
      @build_opts ||= ''
    end

    # Path to the Info.plist
    # Default: project directory
    def info_plist_path
      @info_plist_path ||= File.expand_path(info_plist_name)
    end

    # Name of the Info.plist file
    # Default: "Info.plist"
    def info_plist_name
      @info_plist_name ||= 'Info.plist'
    end
  
  attr_accessor :output_path
  
    # The name of the Cocoa application
    # Default: info_plist['CFBundleExecutable'] or project folder name if "${EXECUTABLE_NAME}"
    attr_accessor :name
  
    # The version of the Cocoa application
    # Default: info_plist['CFBundleVersion']
    attr_accessor :version
  
    # The target name of the distributed DMG file
    # Default: #{name}.app
    attr_accessor :target
    def target
      @target ||= File.basename(target_bundle) if target_bundle
    end
  
    # The name of the target in Xcode, such as MacRuby's Compile or
    # Embed.
    # Uses the application name by default.
    attr_accessor :build_target
    def build_target
      @build_target ||= name
    end
  
    def target_bundle
      @target_bundle ||= Dir["#{build_products}/#{name}.*"].first
    end

    # The build type of the distributed DMG file
    # Default: Release
    attr_accessor :build_type

    # The Sparkle feed URL
    # Default: info_plist['SUFeedURL']
    attr_writer :su_feed_url
    def su_feed_url
      @su_feed_url ||= info_plist['SUFeedURL']
    end
  
    # The host name, e.g. some-domain.com
    # Default: host from base_url
    attr_accessor :host 
  
    # The user to log in on the remote server.
    # Default: empty
    attr_accessor :user
  
    # Rename the app to this.
    # Default: empty
    attr_accessor :app_name
    def app_name
        @app_name
    end
  
    # The url from where the xml + dmg files will be downloaded
    # Default: dir path from appcast_filename
    attr_writer :base_url
    def base_url
      if su_feed_url
        @base_url ||= File.dirname(su_feed_url)
      else
        @base_url
      end
    end
  
    # The file name for generated release notes for the latest release
    # Default: release_notes.html
    attr_accessor :release_notes
  
    # The file name for the project readme file
    # Default: README.txt
    attr_accessor :readme
  
    # List of files/bundles to be packaged into the DMG
    attr_accessor :files

    # The path for an HTML template into which the release_notes.txt are inserted
    # after conversion to HTML
    #
    # The template file is an ERb template, with <%= yield %> as the placeholder
    # for the generated release notes.
    #
    # Currently, any CSS or JavaScript must be inline
    #
    # Default: release_notes_template.html.erb, which was generated by install_choctop into each project
    attr_accessor :release_notes_template

    # The name of the local xml file containing the Sparkle item details
    # Default: info_plist['SUFeedURL'] or linker_appcast.xml
    attr_writer :appcast_filename
    def appcast_filename
      @appcast_filename ||= su_feed_url ? File.basename(su_feed_url) : 'my_feed.xml'
    end  
  
    # The remote directory where the xml + dmg files will be uploaded
    attr_accessor :remote_dir
  
    # Defines the transport to use for upload, default is :rsync, :scp is also available
    attr_accessor :transport
    def transport
      @transport ||= :rsync # other option is scp
    end
  
    # The argument flags passed to rsync
    # Default: -aCv
    attr_accessor :rsync_args
  
    # Additional arguments to pass to scp
    # e.g. -P 11222
    attr_accessor :scp_args

    attr_accessor :build_products
    def build_products
      @build_products ||= "build/#{build_type}"
    end
  
    # Folder from where all files will be copied into the DMG
    # Files are copied here if specified with +add_file+ before DMG creation
    attr_accessor :dmg_src_folder
    def dmg_src_folder
      @dmg_src_folder ||= "build/#{build_type}/dmg"
    end
  
    def safe_name
      name.gsub(/ /, '_')
    end
  
    # Generated filename for a distribution, from name, version and .dmg
    # e.g. MyApp-1.0.0.dmg
    def pkg_name
      version ? "#{safe_name}-#{version}.dmg" : versionless_pkg_name
    end
  
    # Version-less generated filename for a distribution, from name and .dmg
    # e.g. MyApp.dmg
    def versionless_pkg_name
      "#{safe_name}.dmg"
    end
  
    # Path to generated package DMG
    def pkg
      "#{build_path}/#{pkg_name}"
    end
  
    # Path to built DMG, sparkle's xml file and other assets to be uploaded to remote server
    def build_path
      "appcast/build"
    end
  
    def mountpoint
      # @mountpoint ||= "/tmp/build/mountpoint#{rand(10000000)}"
      @mountpoint ||= "/Volumes"
    end
  
    # Path to Volume when DMG is mounted
    def volume_path
      "#{mountpoint}/#{name}"
    end
  
    #
    # Custom DMG properties
    #
  
    # Path to background .icns image file for custom DMG
    # Value should be file path relative to root of project
    # Default: a choctop supplied background image
    # that matches to default app_icon_position + applications_icon_position
    # To have no custom background, set value to +nil+
    attr_accessor :background_file
  
    # x, y position of this project's icon on the custom DMG
    # Default: a useful position for the icon against the default background
    attr_accessor :app_icon_position
  
    # x, y position of the Applications symlink icon on the custom DMG
    # Default: a useful position for the icon against the default background
    attr_accessor :applications_icon_position
  
    # Path to an .icns file for the DMG's volume icon (looks like a disk or drive)
    # Default: a DMG icon provided within choctop
    # To get default, boring blank DMG volume icon, set value to +nil+
    attr_accessor :volume_icon
  
    # Custom icon for the Applications symlink icon
    # Default: none
    attr_accessor :applications_icon
  
    # Size of icons, in pixels, within custom DMG (between 16 and 128)
    # Default: 104 - this is nice and big
    attr_accessor :icon_size
  
    # Icon text size
    # Can pass integer (12) or string ("12" or "12 px")
    # Default: 12 (px)
    attr_reader :icon_text_size
  
    def icon_text_size=(size)
      @icon_text_size = size.to_i
    end
  
    # The url for the remote package, without the protocol + host
    # e.g. if absolute url is http://mydomain.com/downloads/MyApp-1.0.dmg
    # then pkg_relative_url is /downloads/MyApp-1.0.dmg
    def pkg_relative_url
      unless base_url
        raise "The base url should be set in order to create a sparkle feed. Set the SUFeedURL in your Info.plist."
      end
      _base_url = base_url.gsub(%r{/$}, '')
      "#{_base_url}/#{pkg_name}".gsub(%r{^.*#{host}}, '')
    end
    
    def info_plist
      @info_plist ||= OSX::NSDictionary.dictionaryWithContentsOfFile(info_plist_path) || {}
    end
  
    # Add an explicit file/bundle/folder into the DMG
    # Examples:
    #   file 'build/Release/SampleApp.app', :position => [50, 100]
    #   file :target_bundle, :position => [50, 100]
    #   file proc { 'README.txt' }, :position => [50, 100]
    #   file :position => [50, 100] { 'README.txt' }
    # Required option:
    #   +:position+ - two item array [x, y] window position
    # Options:
    #   +:name+    - override the name of the project when mounted in the DMG
    #   +:exclude+ - do not include files/folders
    def file(*args, &block)
      path_or_helper, options = args.first.is_a?(Hash) ? [block, args.first] : [args.first, args.last]
      throw "add_files #{path_or_helper}, :position => [x,y] option is missing" unless options[:position]
      self.files ||= {}
      files[path_or_helper] = options
    end
    alias_method :add_file, :file
    
    # Add the whole project as a mounted item; e.g. a TextMate bundle
    # Examples:
    #   root :position => [50, 100]
    #   add_root :position => [50, 100], :name => 'My Thing'
    # Required option:
    #   +:position+ - two item array [x, y] window position
    # Options:
    #   +:name+    - override the name of the project when mounted in the DMG
    #   +:exclude+ - do not include files/folders
    def root(options)
      throw "add_root :position => [x,y] option is missing" unless options[:position]
      options[:name] ||= File.basename(File.expand_path("."))
      self.files ||= {}
      files['.'] = options
    end
    alias_method :add_root, :root
    
    # Add the whole project as a mounted item; e.g. a TextMate bundle
    # Examples:
    #   add_link "http://github.com/drnic/choctop", :name => 'Github', :position => [50, 100]
    #   add_link "http://github.com/drnic/choctop", 'Github.webloc', :position => [50, 100]
    # Required option:
    #   +:position+ - two item array [x, y] window position
    #   +:name+    - override the name of the project when mounted in the DMG
    def link(url, *options)
      name = options.first if options.first.is_a?(String)
      options = options.last || {}
      options[:url] = url
      options[:name] = name if name
      throw "add_link :position => [x,y] option is missing" unless options[:position]
      throw "add_link :name => 'Name' option is missing" unless options[:name]
      options[:name].gsub!(/(\.webloc|\.url)$/, '')
      options[:name] += ".webloc"
      self.files ||= {}
      files[options[:name]] = options
    end
    alias_method :add_link, :link
    
    # Specify which background + volume images to use by default
    # Can also add default targets
    # Supports
    # * :normal (default)
    # * :textmate
    def defaults(project_type)
      case @project_type = project_type.to_sym
      when :normal
        @background_file ||= File.dirname(__FILE__) + "/../assets/default_background.jpg"
        @volume_icon     ||= File.dirname(__FILE__) + "/../assets/default_volume.icns"
        @app_icon_position          ||= [175, 65]
        @applications_icon_position ||= [347, 270]
        @icon_size      ||= 104
        @icon_text_size ||= 12
        
        add_file :target_bundle, :position => app_icon_position
      when :textmate
        @background_file ||= File.dirname(__FILE__) + "/../assets/textmate_background.jpg"
        @volume_icon     ||= File.dirname(__FILE__) + "/../assets/textmate_volume.icns"
        @icon_size       ||= 104
        @icon_text_size  ||= 12
      end
    end
    alias_method :project_type, :defaults

    def initialize
      $choctop = $sparkle = self # define a global variable for this object ($sparkle is legacy)
    
      yield self if block_given?
    
      # Defaults
      @name ||= info_plist['CFBundleExecutable'] || File.basename(File.expand_path("."))
      @name = File.basename(File.expand_path(".")) if @name == '${EXECUTABLE_NAME}'
      @version ||= info_plist['CFBundleVersion']
      @build_type = ENV['BUILD_TYPE'] || 'Release'
    
      if base_url
        @host ||= URI.parse(base_url).host
      end
    
      @release_notes ||= 'release_notes.html'
      @readme        ||= 'README.txt'
      @release_notes_template ||= "release_notes_template.html.erb"
      @rsync_args ||= '-aCv --progress'

      defaults :normal unless @project_type

      define_tasks
    end
  end
end
