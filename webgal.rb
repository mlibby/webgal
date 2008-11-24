#!/usr/bin/ruby 
#
# Copyright (c) 2004, 2005, 2008 Michael C. Libby 
#
# www.mikelibby.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# see LICENSE for details
#

DEBUG = false

$LOAD_PATH << "./lib" 
USR_SHARE = "#{Dir.pwd}/share"
IS_WINDOWS = ( (ENV['OS'] || '').downcase == 'windows_nt' )
THUMB_DIR = ENV['HOME'] + "/.webgal/thumbs"

require 'gtk2'

require 'digest/sha1'
require 'fileutils'
require 'yaml'

require 'mcl-gtkwidgets'

require 'rubygems'
require 'RMagick'

Gtk.init

def update_window
  unless IS_WINDOWS
    while (Gtk.events_pending?)
      Gtk.main_iteration
    end
  end
end

class JHead
  def initialize(filename)
    @filename = filename
    @raw_head = `jhead "#{filename}"`
    @fields = {}
    @raw_head.split(/\n/).each do |line|
      if md = /^(.+?) +: (.+?)$/.match(line) then
        key = md[1]
        val = md[2]
        @fields[key] = val
      end
    end
  end

  attr_accessor :filename, :raw_head, :fields
end

class Image
  @@gtk_padding = 1

  def initialize(args)
    if args.class == Hash then
      @filename = args['filename']
    else
      @filename = args
    end

    raise "Image file not found." unless FileTest.exists?(@filename) 
    @title = File.basename( @filename )
    update_image
    @gtk_preview = nil
  end

  def caption
    @caption
  end

  def date
    return @date == '' ? '' : "(#{@date})"
  end

  def fields
    return {
      'filename' => @filename,
      'date'     => @date,
      'caption'  => @caption,
      'title'    => @title,
    }
  end

  def filename
    @filename
  end

  def gtk_make_thumbnail
    begin
      thumb = "#{THUMB_DIR}/#{@hex_id}.jpg"
      unless File.exists?(thumb) then
        system("convert", @filename, "-thumbnail", "100x100", thumb)
      end
      @i = Gtk::Image.new(thumb)

    rescue
      puts "Problem thumbnailing '#{@filename}': #$!"
      @i.pixbuf = nil

    end
    return @i
  end
  
  def gtk_image_fields
    label = Gtk::VBox.new

    field_name_width = 60

    @img_filename = Gtk::Label.new
    @img_filename.set_xalign(0)
    @img_filename.set_xpad(field_name_width)
    @img_filename.set_markup( "<b>#{@filename}</b>" ) 
    label.pack_start( @img_filename, false, false, @@gtk_padding )

    @img_date = Gtk::Label.new
    @img_date.set_xalign(0)
    @img_date.set_xpad(field_name_width)
    @img_date.set_markup( "#{@date}" )
    label.pack_start( @img_date, false, false, @@gtk_padding )

    
    @img_caption = MclGtkEntryLabel.new("Caption: ", @caption, field_name_width, nil ) 
    @img_caption.entry.signal_connect("focus-out-event") do |*obj|
      set_caption( @img_caption.entry.text )
      false
    end
    label.pack_start( @img_caption, false, false, @@gtk_padding )
    
    return label
  end
  
  def gtk_preview(action_buttons = nil)
    if @gtk_preview.nil? then
      gtk_make_thumbnail

      @gtk_preview = Gtk::HBox.new
      
      @image_button = Gtk::Button.new
      @image_button.add( @i )
      @image_button.signal_connect( "clicked" ) do |obj|
        gtk_show_full_image
      end
      
      @gtk_preview.pack_start( @image_button, false, false )
      @gtk_preview.pack_start( action_buttons, false, false ) unless action_buttons.nil?
      @gtk_preview.pack_start( gtk_image_fields, true, true )
    end

    @gtk_preview
  end

  def gtk_show_full_image
    zwin = Gtk::Window.new
    zwin.maximize
    zwin.set_title("#{@filename}")

    zroot = Gtk::VBox.new(false, 0)
    zwin.add(zroot)
    
    i = Gtk::Image.new("#{@filename}")
    x = i.pixbuf.width
    y = i.pixbuf.height

    xa = Gtk::Adjustment.new( 0, 1, x, 1, 1, x )
    ya = Gtk::Adjustment.new( 0, 1, y, 1, 1, y )

    vp = Gtk::Viewport.new(xa, ya)
    vp.add( i )
    scroller = Gtk::ScrolledWindow.new
    scroller.add( vp )
    zroot.pack_start( scroller, true, true, 0 )
    zwin.show_all
  end

  def html_basename
    b = File.basename(@filename)
    b.gsub!(/\.\w+$/, '')
    return  b
  end
  
  def html_filename
    File.basename(@filename)
  end
  
  def html_nav( type, links )
    return "" unless links.has_key?(type)

    if "up" == type then
      return "<a href='#{links[type]['url']}'>#{links[type]['text']}</a>"
    end

    if "prev" == type || "next" == type then
      return "<a href='#{links[type]['url']}'>#{links[type]['text']}</a><br />" +
        "<a href='#{links[type]['url']}'><img src='#{links[type]['image']}'></a>"
    end
  
    return ""  
  end

  def name
    @filename
  end

  def rotate
    system("exiftran", "-ip", "-9", @filename)
    update_preview
  end

  def title
    @title
  end

  def update_image
    @hex_id = Digest::SHA1.hexdigest( File.read(@filename) )
    @jhead = JHead.new(@filename)
    @date = @jhead.fields['Date/Time'] || ''
    @caption = @jhead.fields['Comment'] || ''
  end

  def update_preview
    update_image
    unless @gtk_preview.nil? then
      @image_button.remove(@i)
      gtk_make_thumbnail
      @image_button.add(@i)
      @image_button.show_all
    end  
  end

  def set_caption(caption)
    return if caption == @caption
    result = `jhead -cl \"#{caption}\" #{@filename}`
    @caption = caption
  end

  def to_html(conf, links)
    File.open("#{conf['gallery_dir']}/#{html_basename}.html", "w") do |fh|
      t = File.read(conf['image_template_file'])
      t.gsub!(/%STYLESHEET%/, "<link rel='stylesheet' href='webgal.css'>")
      t.gsub!(/%TITLE%/, title)
      t.gsub!(/%GALLERY_NAME%/, conf['gallery_title'])
      t.gsub!(/%IMAGE_DATE%/, date)
      t.gsub!(/%IMAGE_TITLE%/, title)
      t.gsub!(/%IMAGE_FILE%/, [conf["image_med_dir"], html_filename].join("/"))
      t.gsub!(/%BIG_FILE%/, [conf["image_big_dir"], html_filename].join("/"))
      t.gsub!(/%CAPTION%/, @caption)
      t.gsub!(/%PREV_LINK%/, html_nav('prev', links) )
      t.gsub!(/%INDEX_LINK%/, html_nav('up', links) )
      t.gsub!(/%NEXT_LINK%/, html_nav('next', links) )
      fh.puts t
    end
  end

end

class ImageList
  def initialize
    @gtk_preview = nil
    @image_list = []
  end

  def add_image(filename)
    begin
      @image_list << Image.new(filename)
    rescue => error
      warn "Error adding image '#{filename}': #{error.message}"
      warn error.backtrace.join("\n")
    end
  end

  def add_image_from_hash(ihash)
    begin
      @image_list << Image.new(ihash)
    rescue => error
      warn "Error adding image from hash '#{ihash.inspect}': #{error.message}"
      warn error.backtrace.join("\n")
    end
  end

  def delete_image(i)
    @image_list[i] = nil
    @image_seps[i].destroy
  end

  def images
    @image_list
  end

  def length
    @image_list.length
  end

  def gtk_action_buttons( idx )
    rotate_button = Gtk::Button.new( "Rotate" )
    rotate_button.signal_connect( "clicked" ) do |obj|
      @image_list[idx].rotate
    end
    
    delete_button = Gtk::Button.new( "Remove" )
    delete_button.signal_connect( "clicked" ) do |obj|
      delete_image( idx )
      @image_prevs[idx].destroy
    end
    
    actions = Gtk::VBox.new
    actions.pack_start( rotate_button, false, false )
    actions.pack_start( delete_button, false, false )
    return actions
  end
  
  def gtk_preview_list
    if @gtk_preview.nil? then
      pw = MclGtkProgressWindow.new("Making Gallery Previews", @image_list.length, false)
      pw.show_all
      
      image_view = Gtk::VBox.new
      
      @image_list.compact! #remove any nil images from the list before previewing

      @image_prevs = []
      @image_seps = []

      @image_list.each_index do |i|
        image = @image_list[i]
        pw.major = "Previewing #{image.name}"
        update_window

        @image_prevs[i] = image.gtk_preview( gtk_action_buttons(i) )
        image_view.pack_start( @image_prevs[i], false, false )

        @image_seps[i] = Gtk::HSeparator.new
        image_view.pack_start( @image_seps[i], true, true )
      end
      
      xadj = Gtk::Adjustment.new( 0, 0, 0, 0, 0, 0 )
      yadj = Gtk::Adjustment.new( 1, 1, @image_list.length, 1, 1, 1 )
      
      image_view_port = Gtk::Viewport.new( xadj, yadj )
      image_view_port.add( image_view )
      @gtk_preview = Gtk::ScrolledWindow.new
      @gtk_preview.add( image_view_port )
      
      pw.destroy
    end

    return @gtk_preview
  end

  def to_array
    @image_list.map{|i| i.fields}
  end

  def to_html(directory, template, conf)
    #conf is hash containing title, table_width
    File.open("#{directory}/index.html", "w") do |fh|
      t = template.dup

      t.gsub!(/%STYLESHEET%/, "<link rel='stylesheet' href='webgal.css'>")
      t.gsub!(/%TITLE%/, conf['gallery_title'])
      t.gsub!(/%GALLERY_NAME%/, conf['gallery_title'])
      t.gsub!(/%INDEX_LINK%/, "Back to this album's index")
      
      ptable = "<table class='previewTable'>\n"
      column = 0
      @image_list.each do |i|
        ptable += "<tr class='previewRow'>\n" if column == 0
        ptable += "<td class='previewCell'>\n"
        ptable += "<a href='#{i.html_basename}.html'>"
        ptable += "<img class='previewThumb' src='tn_#{i.html_basename}.#{conf['thumb_format']}'>"
        if conf['show_title_on_index_tf'] then
          ptable += "<p class='previewTitle'><a href='#{i.html_basename}.html'>"
          ptable += "#{i.title}</a></p>"
        end
        if conf['show_caption_on_index_tf'] then
          ptable += "<p class='previewCaption'>#{i.caption}</p>"
        end
        ptable += "</a>\n"
        ptable += "</td>"
      
        column += 1
        if column > (conf['index_width_i'] - 1) then 
          column = 0 
          ptable += "</tr>\n"
        end
      end
      ptable += "</table>"

      t.gsub!(/%THUMBNAIL_TABLE%/, ptable)
      fh.puts t
    end
  end
end

class WebGal
  @@open_webgals = 0

  def initialize()
    FileUtils.mkdir("#{ENV['HOME']}/.webgal") unless File.exists?("#{ENV['HOME']}/.webgal")
    FileUtils.mkdir("#{ENV['HOME']}/.webgal/thumbs") unless File.exists?("#{ENV['HOME']}/.webgal/thumbs")

    @@open_webgals += 1
    configure

    build_app
    build_menubar
    build_main_frame
    build_status_bar
    finalize_app
  end

  def add_image_dir
    fd = Gtk::FileSelection.new("Choose Image Gallery Directory")
    fd.signal_connect("destroy"){ fd.destroy }
    fd.ok_button.signal_connect("clicked"){|f|
      fname = fd.filename
      fd.destroy
      add_images_from(fname)
    }
    fd.cancel_button.signal_connect("clicked"){ fd.destroy }
    fd.show
  end

  def add_images_from(filename)
    image_dir = File.dirname( filename )
    status_message("Added images from directory: #{image_dir}")
    Dir.new(image_dir).find_all{|x| is_valid_image_suffix(x) }.sort.each do |img_file|
      @image_list.add_image("#{image_dir}/#{img_file}")
    end
    update_preview
  end

  def build_app
    @app = Gtk::Window.new(Gtk::Window::TOPLEVEL)
    @app.maximize
    @app.set_title("MCL's Web Image Gallery Tool")
    @app.signal_connect("delete_event"){ Gtk.main_quit }

    @root = Gtk::VBox.new(false, 0)
    @app.add(@root)
  end

  def build_main_frame
    @main_frame = Gtk::VBox.new
    temp_label = Gtk::Label.new
    temp_label.set_markup( File.read("ABOUT.xml") )
    temp_label.justify = Gtk::JUSTIFY_CENTER
    @main_frame.pack_start( temp_label, true, true, 0)
    @root.pack_start( @main_frame, true, true, 0)
  end

  def build_menubar
    menus = [
      [ '_File',
        [
          [ '_New Gallery', proc{|x| x.new_webgal } ],
          [ '_Open Image Gallery', proc{|x| x.open_gallery_dialog} ],
          [ '_Save Gallery', proc{|x| x.save_gallery} ],
          [ 'Save Gallery _As...', proc{|x| x.save_gallery_as} ],
          [ '-' ], 
          [ 'Add Images in _Directory', proc{|x| x.add_image_dir} ],
          [ '-' ],
          [ '_Close Gallery', proc{|x| x.close } ],
          [ '_Quit', proc{|x| x.quit } ],
        ],
      ],
      [ '_Gallery',
        [
          [ '_Make Gallery', proc{|x| x.make_gallery } ],
          [ '_Gallery Preferences', proc{|x| x.gallery_preferences_dialog } ],
          [ 'Make _HTML for Gallery', proc{|x| x.make_gallery_html } ]
        ],
      ],
      [ '_Help',
        [
          [ 'About', proc{|x| x.show_help('About') } ],
          [ 'License', proc{|x| x.show_help('License') } ],
        ],
      ],
    ]
    
    @menubar = MclGtkMenuBar.new
    @root.pack_start(@menubar, false, false, 0)
    
    menus.each do |menu|
      menu_name = menu[0]
      menu[1].each do |menu_item|
        unless menu_item[0] == '-' then
          @menubar.add_command(menu_name,
            menu_item[0],
            menu_item[1],
            self)
        else
          @menubar.add_separator(menu_name)
        end
      end
    end
  end
  
  def build_status_bar
    @status_bar = Gtk::Statusbar.new
    @root.pack_start( @status_bar, false, false, 0)
  end

  def close
    @app.destroy
    @@open_webgals -= 1
    quit if @@open_webgals < 1
  end

  def configure
    @gallery_file          = nil
    @image_list            = ImageList.new
    @showing_preview       = false

    @prefs = {
      'gallery_dir'               =>  "#{ENV['HOME']}/webgal",
      'gallery_title'             =>  "Web Gallery",
      'index_width_i'             =>  4,
      'show_caption_on_index_tf'  =>  true,
      'show_title_on_index_tf'    =>  true,
      'stylesheet_file'           =>  "#{USR_SHARE}/webgal.css",
      'index_template_file'       =>  "#{USR_SHARE}/html_index.wgt",
      'image_template_file'       =>  "#{USR_SHARE}/html_image.wgt",
      'thumb_resize_setting_f'    =>  0.95,
      'thumb_format'              =>  'jpg',
      'thumb_x_i'                 =>  100,
      'thumb_y_i'                 =>  100,
      'thumb_dir'                 =>  "thumb",
      'valid_suffix'              =>  "jpg jpeg png gif",
      'image_big_x_i'             =>  1280,
      'image_big_y_i'             =>  1024,
      'image_big_dir'             =>  "big",
      'image_med_x_i'             =>  512,
      'image_med_y_i'             =>  384,
      'image_med_dir'             =>  "med",
    }
    make_suffix_regexps

    @labels = {
      'gallery_dir'               =>  "Gallery Directory: ", 
      'gallery_title'             =>  "Gallery Title: ",
      'index_width_i'             =>  "Index table width: ",
      'show_caption_on_index_tf'  =>  "Show Captions on Index?",
      'show_title_on_index_tf'    =>  "Show Titles on Index?",
      'stylesheet_file'           =>  "Stylesheet: ",
      'index_template_file'       =>  "Index Template: ",
      'image_template_file'       =>  "Image Template: ",
      'thumb_resize_setting_f'    =>  "Thumbnail Resize Sharpness (0.00 - 1.00): ",
      'thumb_format'              =>  "Thumbnail Image Format: ",
      'thumb_x_i'                 =>  "Thumbnail Width: ",
      'thumb_y_i'                 =>  "Thumbnail Height: ",
      'thumb_dir'                 =>  "Thumbnail Directory Name: ",
      'valid_suffix'              =>  "Valid Image Suffixes: ",
      'image_big_x_i'             =>  "Large Image Maximum Width: ",
      'image_big_y_i'             =>  "Large Image Maximum Height: ",
      'image_big_dir'             =>  "Large Image Directory Name: ",
      'image_med_x_i'             =>  "Medium Image Maximum Width: ",
      'image_med_y_i'             =>  "Medium Image Maximum Height: ",
      'image_med_dir'             =>  "Medium Image Directory Name: ",
    }

    load_rc_file
  end

  def copy_image(source, dest)
    FileUtils.cp( source, dest )
  end

  def copy_resize_image(image, size)
    dest = [@prefs['gallery_dir'], @prefs["image_#{size}_dir"], image.html_filename].join("/")
    imlist = Magick::ImageList.new(image.filename)
    image = imlist[0]

    ix = image.base_columns
    iy = image.base_rows
    
    wx = @prefs["image_#{size}_x_i"].to_f
    wy = @prefs["image_#{size}_y_i"].to_f

    if (ix > wx) or (iy > wy) then
      x_ratio = wx / ix
      y_ratio = wy / iy
      use_ratio = x_ratio < y_ratio ? x_ratio : y_ratio
      
      new_x = ix * use_ratio
      new_y = iy * use_ratio

      t = image.resize( new_x.to_i,
        new_y.to_i,
        Magick::LanczosFilter,
        0.95 )
      t.write(dest){ self.quality = 88 }

    else
      copy_image(image.filename, dest)
    end
  end

  def finalize_app
    @app.show_all
    status_message("Web Gallery Tool Started.")
  end
  
  def gallery_preferences_dialog
    pref_dialog = Gtk::Dialog.new("Set Gallery Preferences", nil, nil, 
      [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT],
      [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT]
    )
    
    pref_box = Gtk::VBox.new
    
    item_display = Hash.new
    @prefs.keys.sort.each do |p|
      item_display[p] = MclGtkEntryLabel.new( @labels[p], @prefs[p] )
      pref_box.pack_start( item_display[p], true, true, 5 )
    end

    pref_dialog.vbox.pack_start(pref_box, false, false, 0)
    pref_dialog.show_all

    result = pref_dialog.run
    case result
    when Gtk::Dialog::RESPONSE_ACCEPT
      
      @prefs.keys.sort.each do |p|
        if /_tf$/.match(p) then
          @prefs[p] = ( item_display[p].text == 'true' ) ? true : false
          next
        end

        if /_f$/.match(p) then
          @prefs[p] = item_display[p].text.to_f
          next
        end

        if /_i$/.match(p) then
          @prefs[p] = item_display[p].text.to_i
          next
        end

        @prefs[p] = item_display[p].text
      end
      make_suffix_regexps
    else
      # do_nothing_since_dialog_was_cancelled()
    end
    pref_dialog.destroy
  end

  def is_valid_image_suffix( fname )
    is_valid = false
    @valid_suffix_re.each do |vs_re|
      is_valid = true if vs_re.match(fname)
    end
    return is_valid
  end

  def load_rc_file
    ["/etc/webgalrc",
      "#{ENV['HOME']}/.webgalrc",
    ].each do |rcf|
      if File.exists?(rcf) then
        File.open(rcf){ |fh|
          while not fh.eof?
            line = fh.readline.chomp
            next unless /=/.match(line)
            key, val = line.split(/=/)
            if /_tf$/.match(key) then
              @prefs[key] = ( val == 'true' ) ? true : false
              next
            end
            if /_f$/.match(key) then
              @prefs[key] = val.to_f
              next
            end
            if /_i$/.match(key) then
              @prefs[key] = val.to_i
              next
            end
            @prefs[key] = val
          end
        }
      end
    end
  end
  
  def make_gallery_html
    # TODO: convert puts to Progress Window
    
    puts "preparing gallery directories"
    begin
      Dir.mkdir( @prefs['gallery_dir'] )
    rescue => error
      warn "Problem creating gallery directory '#{@prefs['gallery_dir']}': #{error.message}"
      warn error.backtrace.join("\n")
    end

    begin
      Dir.mkdir( "#{@prefs['gallery_dir']}/#{@prefs['image_big_dir']}" )
    rescue => error
      warn "Problem creating big image directory '#{@prefs['image_big_dir']}': #{error.message}"
      warn error.backtrace.join("\n")
    end

    begin
      Dir.mkdir( "#{@prefs['gallery_dir']}/#{@prefs['image_med_dir']}" )
    rescue => error
      warn "Problem creating medium image directory '#{@prefs['image_med_dir']}': #{error.message}"
      warn error.backtrace.join("\n")
    end

    puts "creating index page"
    begin
      @image_list.to_html( @prefs['gallery_dir'], File.read(@prefs['index_template_file']), @prefs )
    rescue => error
      warn "Problem making index page: #{error.message}"
      warn error.backtrace.join("\n")
      return
    end

    puts "preparing CSS file"
    begin
      styles = File.read( @prefs['stylesheet_file'] )
      styles.gsub!( %r{/\*%PREVIEW_CELL_WIDTH%\*/}, "width : #{100 / @prefs['index_width_i']}%;" )
      File.open( "#{@prefs['gallery_dir']}/webgal.css", "w" ){ |fh| fh.puts styles }
    rescue => error
      warn "Problem making index page: #{error.message}"
      warn error.backtrace.join("\n")
      return    
    end
    
    puts "working on individual image pages"
    @image_list.images.each_index do |idx|
      puts "working on image #{idx + 1} of #{@image_list.images.length}"

      image = @image_list.images[idx]

      links = {'up' => {
          'url' => 'index.html',
          'text' => "Back to this album's index",
        }
      }

      if idx > 0 then
        prev_image = @image_list.images[idx - 1] 
        links['prev'] = {
          'url' => "#{prev_image.html_basename}.html",
          'text' => "Previous",
          'image' => thumbnail_filename(prev_image),
        }
      end

      if (idx + 1) < @image_list.images.length then
        next_image = @image_list.images[idx + 1] 
        links['next'] = {
          'url' => "#{next_image.html_basename}.html",
          'text' => "Next",
          'image' => thumbnail_filename(next_image),
        }
      end

      begin
        puts "making HTML page for #{image.filename}"
        image.to_html(@prefs, links)

      rescue => error
        warn "Problem making image page: #{error.message}"
        warn error.backtrace.join("\n")
        return
      end
    end
  end
  
  def make_gallery
    make_gallery_html
    begin
      puts "resizing image #{image.filename}"
      copy_resize_image( image, "med") 
      copy_resize_image( image, "big")
      make_thumbnail(image)

    rescue => error
      warn "Problem creating image copies: #{error.message}"
      warn error.backtrace.join("\n")
    end
    puts "done making web gallery"
  end

  def make_thumbnail(image)
    system("convert", 
      image.filename, 
      "-thumbnail", 
      "#{@prefs['thumb_x_i']}x#{@prefs['thumb_y_i']}", 
      "#{@prefs['gallery_dir']}/#{thumbnail_filename(image)}")
  end
  
  def thumbnail_filename(image)
    "tn_#{image.html_basename}.#{@prefs['thumb_format']}"
  end

  def make_suffix_regexps
    @valid_suffix_re = @prefs['valid_suffix'].split(/\s/).map {|s|
      Regexp.new( /\.#{s}$/i )
    }
  end

  def new_webgal
    WebGal.new
  end

  def open_gallery
    begin
      gallery_yaml = YAML.load( File.read(@gallery_file) )

      #load preferences
      gallery_yaml['prefs'].each do | key,val |
        next unless @prefs.has_key?(key)
        @prefs[key] = val
      end
      make_suffix_regexps

      #load images
      @image_list = ImageList.new
      gallery_yaml['image_list'].each do |image|
        @image_list.add_image_from_hash( image )
      end

      puts "Image list is: #{@image_list.inspect}" if DEBUG
      update_preview
      
    rescue => error
      #TODO: build alert box!
      warn "Problem loading gallery file '#{@gallery_file}': #{error.message}"
      warn error.backtrace.join("\n")
    end
  end

  def open_gallery_dialog
    fd = Gtk::FileSelection.new("Select Image Gallery File to Open...")
    fd.signal_connect("destroy"){ fd.destroy }
    fd.ok_button.signal_connect("clicked"){|f|
      @gallery_file = fd.filename
      open_gallery
      fd.destroy
    }
    fd.cancel_button.signal_connect("clicked"){ fd.destroy }
    fd.show
  end

  def quit
    Gtk.main_quit
  end

  def save_gallery
    if @gallery_file.nil? then
      if @image_list.length > 0 then
        save_gallery_as
      end
      return
    end
      
    begin
      gallery = {
        'prefs' => @prefs,
        'image_list' => @image_list.to_array,
      }

      File.open(@gallery_file, "w") do |fh|
        fh.puts "#{gallery.to_yaml}"
      end

    rescue => error
      warn "Problem writing gallery file '#{@gallery_file}': #{error.message}"
      warn error.backtrace.join("\n")
    end
  end

  def save_gallery_as
    fd = Gtk::FileSelection.new("Save Image Gallery File As...")
    fd.signal_connect("destroy"){ fd.destroy }
    fd.ok_button.signal_connect("clicked"){|f|
      @gallery_file = fd.filename
      save_gallery
      fd.destroy
    }
    fd.cancel_button.signal_connect("clicked"){ fd.destroy }
    fd.show
  end

  def show_help( help_topic )
    help_dialog = Gtk::Dialog.new
    help_dialog.title = help_topic
    ok_button = help_dialog.add_button("OK", 1)
    ok_button.signal_connect("clicked"){help_dialog.destroy}

    help_text = File.read("#{help_topic.upcase}")

    help_vbox = help_dialog.vbox
    help_view = Gtk::TextView.new
    help_text_buffer = Gtk::TextBuffer.new
    help_text_buffer.text = help_text
    help_view.set_buffer( help_text_buffer )

    help_scroller = Gtk::ScrolledWindow.new
    help_scroller.add( help_view )
   
    help_vbox.pack_start( help_scroller, true, true, 0 )
    
    help_dialog.resize(550,450)

    help_dialog.show_all
  end

  def status_message(msg)
    puts "Status message: #{msg}"
    @status_bar.push( 1, msg )
  end

  def status_message_pop
    @status_bar.pop( 1 )
  end

  def update_preview
    if @showing_preview then
      return
    else
      @showing_preview = true
      @main_frame.children.each{ |c| c.destroy }
      @main_frame.pack_start( @image_list.gtk_preview_list, true, true, 0 )
      @main_frame.show_all
    end      
  end
end

WebGal.new
Gtk.main
