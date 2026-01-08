if !defined?(LBDSKY) || !VersionChecker.older?(LBDSKY::VERSION, "1.2.0")
#===============================================================================
# This module stores page definitions for various UI screens that have tabbed
# interfaces. Each page is a hash containing its name, display order, and
# description. Pages are organized by menu.
# UI screens that use this module:
#-------------------------------------------------------------------------------
# Options screen pages (Gameplay, Audio, Graphics, Controls, etc.)
#===============================================================================
module PageHandlers
  @@handlers = {}

  module_function

  def add(menu, page, hash)
    @@handlers[menu] = HandlerHash.new if !@@handlers.has_key?(menu)
    @@handlers[menu].add(page, hash)
  end

  def remove(menu, page)
    @@handlers[menu]&.remove(page)
  end

  def clear(menu)
    @@handlers[menu]&.clear
  end

  def get(menu, page)
    return @@handlers[menu]&.[](page)
  end

  def each(menu)
    return if !@@handlers.has_key?(menu)
    @@handlers[menu].each { |page, hash| yield page, hash }
  end

  def each_available(menu, *args)
    return if !@@handlers.has_key?(menu)
    pages = @@handlers[menu]
    keys = pages.keys
    sorted_keys = keys.sort_by { |page| pages[page][:order] || keys.index(page) }
    sorted_keys.each do |page|
      hash = pages[page]
      next if hash[:condition] && !hash[:condition].call(*args)
      if hash[:name].is_a?(Proc)
        name = hash[:name].call(*args)
      else
        name = _INTL(hash[:name])
      end
      yield page, hash, name
    end
  end

  def call(menu, page)
    return @@handlers[menu]&.[](page)
  end
end

end