#!/usr/bin/ruby -w
#
# Copyright (c) 2004, 2008 Michael C. Libby 
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

############################################################
#
# And So Forth Widgets are a collection of add-on widgets to the ruby-gtk2
# widget set, designed to make certain tasks a bit simpler by isolating them
# into new widget classes.
#
############################################################

require 'gtk2'

############################################################
# MCL EntryLabel
#
# Provides a label/entry combination widget, so that making 'forms' with
# label:______ type fields is a bit simpler

class MclGtkEntryLabel < Gtk::HBox

  def initialize(label, default_text = '', label_width = nil, text_width = nil)
    super()
    @label = Gtk::Label.new(label)
    unless label_width.nil? then
      @label.width_request = label_width
      @label.set_xalign(1)
    end

    @entry = Gtk::Entry.new()
    @entry.text = default_text.to_s
    @entry.width_chars = text_width unless text_width.nil?

    #if width[0].nil? then
    #  self.pack_start( @label, true, true )
    #else
      self.pack_start( @label, false, false )
    #end

    if text_width.nil? then
      self.pack_start( @entry, true, true )
    else
      self.pack_start( @entry, false, false )
    end
  end

  def entry
    return @entry
  end

  def text
    return @entry.text
  end
end

############################################################
# MCL Progress Window
#

class MclGtkProgressWindow < Gtk::Window

  # pw = MclGtkProgressWindow.new("Title", Range, [FALSE|true])
  # 
  # Provides a progress bar pop-up window that allows the application to send major
  # and minor text events, as well as incrementing a progress bar.
  # 
  # 'Title' is the window title.
  #
  # Range is number of increments to use.
  #
  # If the third argument is true, there will be two labels a major and a minor label.
  # Updating the minor label will increment the progress bar.
  #
  # If the third argument is false (default), there will only be a single label and updating the 
  # main label will increment the progress bar.

  def initialize( title, range, has_minor = false )
    super()
    self.title = title
    @range = range
    @step_size = 1.0 / @range
    @current_step = 0.0
    @has_minor = has_minor

    @vbox = Gtk::VBox.new
    @major = Gtk::Label.new( '' )
    @minor = Gtk::Label.new( '' )
    @bar = Gtk::ProgressBar.new

    @vbox.pack_start( @major, true, true, 2 )
    @vbox.pack_start( @minor, true, true, 2 ) if @has_minor
    @vbox.pack_start( @bar, false, false, 2 )

    self.add(@vbox)

    self.set_default_size(256,16)
    self.set_window_position(Gtk::Window::POS_CENTER)

    return self
  end
  
  def major=(msg)
    @major.text = msg
    update_progress unless @has_minor
  end

  def minor=(msg)
    raise "Minor label not enabled" unless @has_minor
    @minor.text = msg
    update_progress
  end

  def update_progress
    @current_step += @step_size
    @bar.fraction = @current_step unless @current_step > 1.0
  end
end

############################################################
# MCL Menubar
#
# Provides an enhanced menubar widget that adds some methods to make adding
# menus and menu commands to the menubar easier
# 
#  def build_menubar
#    menus = [
#      [ '_File',
#       [
#          [ '_New' , proc{|x| x.new  } ],
#          [ '-' ]  , #separator
#          [ '_Quit', proc{|x| x.quit } ],
#        ],
#      ],
#      [ '_Help',
#       [
#          [ '_About', proc{|x| x.about } ],
#          [ '_License', proc{|x| x.license } ],
#        ],
#      ],
#    ]
#    
#    @menubar = MclGtkMenuBar.new
#    @root.pack_start(@menubar, false, false, 0)
#    
#    menus.each do |menu|
#      menu_name = menu[0]
#      menu[1].each do |menu_item|
#        unless menu_item[0] == '-' then
#          @menubar.add_command(menu_name,
#                               menu_item[0],
#                               menu_item[1],
#                               self)
#        else
#          @menubar.add_separator(menu_name)
#        end
#      end
#    end
#  end
#
class MclGtkMenuBar < Gtk::MenuBar
  def initialize
    __windows__ = false
    super
    @menu_button = {}
    @menu = {}
    return self
  end

  def add_menu(menu_title)
    @menu_button[menu_title] = Gtk::MenuItem.new(menu_title)
    self.append(@menu_button[menu_title])

    @menu[menu_title] = Gtk::Menu.new
    @menu_button[menu_title].set_submenu(@menu[menu_title])
  end

  def add_command(menu_title, cmd_label, activate, root)
    #check if menu exists, if not create it
    unless @menu.has_key?(menu_title)
      add_menu(menu_title)
    end

    #append command to menu
    menu_item = Gtk::MenuItem.new(cmd_label)
    menu_item.signal_connect("activate"){ activate.call(root) }
    @menu[menu_title].append(menu_item)
  end

  def add_separator(menu_title)
    unless @menu.has_key?(menu_title)
      add_menu(menu_title)
    end
    
    menu_sep = Gtk::SeparatorMenuItem.new
    @menu[menu_title].append(menu_sep)
  end
end

############################################################
# Test Classes
#

class TestMclGtkProgressWindow
  def initialize
    @major_counter = 1
    @minor_counter = 1
  
    @to_e = {1 => 'one',
             2 => 'two',
             3 => 'three',
             4 => 'four',
             5 => 'five',
             6 => 'six',
             7 => 'seven',
             8 => 'eight',
             9 => 'nine',
    }
    
    Gtk.init
    @pw = MclGtkProgressWindow.new( 'Test One', 81, true )
    @pw.signal_connect("delete_event"){ Gtk.main_quit }
    @pw.show_all
    
    @timer = Gtk::timeout_add(75) do
      major_minor_loop
      true
    end
  end

  def major_minor_loop
    @pw.major = @to_e[@major_counter]
    @pw.minor = @to_e[@minor_counter]

    @minor_counter += 1
    if @minor_counter > 9 then
      @major_counter += 1
      if @major_counter > 9 then 
        Gtk.main_quit
      else
        @minor_counter = 1
      end
    end
  end

end

if $0 == __FILE__ then
  TestMclGtkProgressWindow.new
  Gtk.main
end
