if !defined?(LBDSKY) || VersionChecker.older?(LBDSKY::VERSION, "1.2.0")
  #===============================================================================
  # Main list of options.
  #===============================================================================
  class UI::OptionsVisualsList < Window_DrawableCommand
    attr_writer   :baseColor, :shadowColor
    attr_accessor :optionColor, :optionShadowColor
    attr_accessor :selectedColor, :selectedShadowColor
    attr_accessor :unsetColor, :unsetShadowColor
    attr_reader   :value_changed

    def initialize(x, y, width, height, viewport)
      @input_icons_bitmap = AnimatedBitmap.new(UI::OptionsVisuals::UI_FOLDER + "input_icons")
      super(x, y, width, height, viewport)
      @index = -1
    end

    def dispose
      super
      @input_icons_bitmap.dispose
    end

    #-----------------------------------------------------------------------------

    def itemCount
      return @options&.length || 0
    end

    def options=(new_options)
      @options = new_options
      self.top_row = 0
      get_values
      @array_second_value_x = 0
      @options.each do |option|
        next if option[:type] != :array || option[:parameters].length != 2
        text_width = self.contents.text_size(option[:parameters][0]).width
        @array_second_value_x = text_width if @array_second_value_x < text_width
      end
      @array_second_value_x += 32
      refresh
    end

    def get_values
      @values = @options.map { |option| option[:get_proc]&.call }
    end

    def lowest_value(option)
      case option[:type]
      when :number_type
        case option[:parameters]
        when Range
          return option[:parameters].begin
        when Array
          return option[:parameters][0] if option[:parameters][0]   # Parameter is [lowest, highest, interval]
        end
        raise _INTL("Opción {1} tiene parámetros inválidos.", option[:name])
      when :number_slider
        if option[:parameters].is_a?(Array) && option[:parameters][1]
          return option[:parameters][0]   # Parameter is [lowest, highest, interval]
        end
        raise _INTL("Opción {1} tiene parámetros inválidos.", option[:name])
      end
      raise _INTL("Opción {1} tiene un valor más bajo indefinido.", option[:name])
    end

    def highest_value(option)
      case option[:type]
      when :number_type
        case option[:parameters]
        when Range
          return option[:parameters].end
        when Array
          return option[:parameters][1] if option[:parameters][1]   # Parameter is [lowest, highest, interval]
        end
        raise _INTL("Opción {1} tiene parámetros inválidos.", option[:name])
      when :number_slider
        if option[:parameters].is_a?(Array) && option[:parameters][1]
          return option[:parameters][1]   # Parameter is [lowest, highest, interval]
        end
        raise _INTL("Opción {1} tiene parámetros inválidos.", option[:name])
      end
      raise _INTL("Opción {1} tiene un valor más alto indefinido.", option[:name])
    end

    def previous_value(this_index)
      return @values[this_index] if @values[this_index] == 0
      option = @options[this_index]
      case option[:type]
      when :array, :array_one
        return @values[this_index] - 1
      when :number_type
        case option[:parameters]
        when Range
          ret = @values[this_index] - 1
          ret = highest_value(option) - lowest_value(option) if ret < 0   # Wrap around
          return ret
        when Array
          highest = highest_value(option)
          lowest = lowest_value(option)
          interval = option[:parameters][2]
          if @values[this_index] > 0
            ret = @values[this_index] - interval
            ret = 0 if ret < 0
          else
            ret = highest - lowest   # Wrap around
          end
          return ret
        end
      when :number_slider
        highest = highest_value(option)
        lowest = lowest_value(option)
        interval = option[:parameters][2]
        if @values[this_index] > 0
          ret = @values[this_index] - interval
          ret = 0 if ret < 0
          return ret
        end
      end
      return @values[this_index]
    end

    def next_value(this_index)
      option = @options[this_index]
      case option[:type]
      when :array, :array_one
        return @values[this_index] + 1 if @values[this_index] < option[:parameters].length - 1
      when :number_type
        case option[:parameters]
        when Range
          ret = @values[this_index] + 1
          ret = 0 if ret > highest_value(option) - lowest_value(option)   # Wrap around
          return ret
        when Array
          highest = highest_value(option)
          lowest = lowest_value(option)
          interval = option[:parameters][2]
          if @values[this_index] < highest - lowest
            ret = @values[this_index] + interval
            ret = highest - lowest if ret > highest - lowest
          else
            ret = 0   # Wrap around
          end
          return ret
        end
      when :number_slider
        highest = highest_value(option)
        lowest = lowest_value(option)
        interval = option[:parameters][2]
        if @values[this_index] < highest - lowest
          ret = @values[this_index] + interval
          ret = highest - lowest if ret > highest - lowest
          return ret
        end
      end
      return @values[this_index]
    end

    def value(this_index = nil)
      return @values[this_index || self.index]
    end

    def selected_option
      return @options[self.index]
    end

    #-----------------------------------------------------------------------------

    def drawItem(this_index, _count, rect)
      rect = drawCursor(this_index, rect)
      option_start_x = (rect.x + rect.width) / 2
      draw_option_name(this_index, rect, option_start_x)
      draw_option_values(this_index, rect, option_start_x) if this_index < @options.length
    end

    def draw_option_name(this_index, rect, option_start_x)
      if this_index >= @options.length
        pbDrawShadowText(self.contents, rect.x, rect.y, option_start_x, rect.height,
                        _INTL("Atrás"), self.baseColor, self.shadowColor)
        return
      end
      option = @options[this_index]
      option_name = option[:name]
      option_name_x = rect.x
      option_colors = [self.optionColor, self.optionShadowColor]
      case option[:type]
      when :control
        # Draw icon
        input_index = UI::BaseVisuals::INPUT_ICONS_ORDER.index(option[:parameters]) || 0
        src_rect = Rect.new(input_index * @input_icons_bitmap.height, 0,
                            @input_icons_bitmap.height, @input_icons_bitmap.height)
        self.contents.blt(rect.x, rect.y + 2, @input_icons_bitmap.bitmap, src_rect)
        # Adjust text position
        option_name_x += @input_icons_bitmap.height + 6
      when :use
        option_colors = [self.baseColor, self.shadowColor]
      end
      pbDrawShadowText(self.contents, option_name_x, rect.y, option_start_x, rect.height,
                      option_name, *option_colors)
    end

    def draw_option_values(this_index, rect, option_start_x)
      option_width = rect.x + rect.width - option_start_x
      option = @options[this_index]
      case option[:type]
      when :array
        total_width = 0
        option[:parameters].each { |value| total_width += self.contents.text_size(value).width }
        spacing = (rect.width - option_start_x - total_width) / (option[:parameters].length - 1)
        spacing = 0 if spacing < 0
        x_pos = option_start_x
        option[:parameters].each_with_index do |value, i|
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                          value,
                          (i == @values[this_index]) ? self.selectedColor : self.baseColor,
                          (i == @values[this_index]) ? self.selectedShadowColor : self.shadowColor)
          # draw_selection_brackets(x_pos, rect.y, value, rect, option_width) if i == @values[this_index]
          if option[:parameters].length == 2
            x_pos += @array_second_value_x
          else
            x_pos += self.contents.text_size(value).width + spacing
          end
        end
      when :number_type
        lowest = lowest_value(option)
        highest = highest_value(option)
        value = _INTL("Tipo {1}/{2}", lowest + @values[this_index], highest - lowest + 1)
        pbDrawShadowText(self.contents, option_start_x, rect.y, option_width, rect.height,
                        value, self.baseColor, self.shadowColor)
      when :number_slider
        lowest = lowest_value(option)
        highest = highest_value(option)
        spacing = 6   # Gap between slider and number
        # Draw slider bar
        slider_length = option_width - rect.x - self.contents.text_size(highest.to_s).width - spacing
        x_pos = option_start_x
        self.contents.fill_rect(x_pos, rect.y + (rect.height / 2) - 2, slider_length, 4, self.baseColor)
        # Draw slider notch
        self.contents.fill_rect(
          x_pos + ((slider_length - 8) * (@values[this_index] - lowest) / (highest - lowest)),
          rect.y + (rect.height / 2) - 8,
          8, 16, self.selectedColor
        )
        # Draw text
        value = (lowest + @values[this_index]).to_s
        pbDrawShadowText(self.contents, x_pos - rect.x, rect.y, option_width, rect.height,
                        value, self.selectedColor, self.selectedShadowColor, 2)
      when :control
        x_pos = option_start_x
        spacing = option_width / 2
        @values[this_index].each_with_index do |value, i|
          if value
            text = Input.input_name(value, (i == 0) ? :keyboard : :gamepad)
            text_colors = [self.baseColor, self.shadowColor]
          else
            text = "---"
            text_colors = [self.unsetColor, self.unsetShadowColor]
          end
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                          text, *text_colors)
          x_pos += spacing
        end
      when :use
        # Draw nothing
      else
        value = option[:parameters][@values[this_index]]
        pbDrawShadowText(self.contents, option_start_x, rect.y, option_width, rect.height,
                        value, self.baseColor, self.shadowColor)
      end
    end

    def draw_selection_brackets(text_x, text_y, text, rect, option_width)
      pbDrawShadowText(self.contents, text_x - option_width, text_y, option_width, rect.height,
                      "[", self.selectedColor, self.selectedShadowColor, 2)
      pbDrawShadowText(self.contents, text_x + self.contents.text_size(text).width, text_y, option_width, rect.height,
                      "]", self.selectedColor, self.selectedShadowColor, 0)
    end

    #-----------------------------------------------------------------------------

    def update
      return if @index < 0
      old_index = self.index
      @value_changed = false
      super
      need_refresh = (self.index != old_index)
      if self.index < @options.length &&
        [:array, :array_one, :number_type, :number_slider].include?(@options[self.index][:type])
        old_value = @values[self.index]
        if Input.repeat?(Input::LEFT)
          @values[self.index] = previous_value(self.index)
        elsif Input.repeat?(Input::RIGHT)
          @values[self.index] = next_value(self.index)
        end
        if self.value != old_value
          pbPlayCursorSE if selected_option[:type] != :number_slider
          need_refresh = true
          @value_changed = true
        end
      end
      refresh if need_refresh
    end
  end

  #===============================================================================
  #
  #===============================================================================
  class UI::OptionsVisuals < UI::BaseVisuals
    attr_reader :page
    attr_reader :in_load_screen

    GRAPHICS_FOLDER   = "Options/"   # Subfolder in Graphics/UI
    TEXT_COLOR_THEMES = {   # Themes not in DEFAULT_TEXT_COLOR_THEMES
      :page_name        => [Color.new(248, 248, 248), Color.new(168, 184, 184)],
      :option_name      => [Color.new(192, 120, 0), Color.new(248, 176, 80)],
      :unselected_value => [Color.new(80, 80, 88), Color.new(160, 160, 168)],
      :selected_value   => [Color.new(248, 48, 24), Color.new(248, 136, 128)],
      :unset_control    => [Color.new(160, 160, 168), Color.new(224, 224, 232)]
    }
    OPTIONS_VISIBLE  = 6
    PAGE_TAB_SPACING = 4

    #-----------------------------------------------------------------------------

    def initialize(options, in_load_screen = false, menu = :options_menu)
      @options        = options
      @in_load_screen = in_load_screen
      @menu           = menu
      @page           = all_pages.first
      super()
    end

    def initialize_bitmaps
      super
      @bitmaps[:page_icons] = AnimatedBitmap.new(graphics_folder + "page_icons")
    end

    def initialize_message_box
      super
      @sprites[:speech_box].letterbyletter = false
      @sprites[:speech_box].visible        = true
    end

    def initialize_sprites
      initialize_page_tabs
      initialize_page_cursor
      initialize_options_list
    end

    def initialize_page_tabs
      add_overlay(:page_icons,
                  all_pages.length * ((@bitmaps[:page_icons].width / 2) + PAGE_TAB_SPACING),
                  @bitmaps[:page_icons].height)
      # @sprites[:page_icons].x = Graphics.width - @sprites[:page_icons].width
      @sprites[:page_icons].x = 57
      @sprites[:page_icons].y = 4
    end

    def initialize_page_cursor
      add_icon_sprite(:page_cursor, @sprites[:page_icons].x - 2, @sprites[:page_icons].y - 2,
                      graphics_folder + "page_cursor")
      @sprites[:page_cursor].z = 1100
    end

    def initialize_options_list
      @sprites[:options_list] = UI::OptionsVisualsList.new(0, 64, Graphics.width, (OPTIONS_VISIBLE * 32) + 32, @viewport)
      @sprites[:options_list].optionColor         = get_text_color_theme(:option_name)[0]
      @sprites[:options_list].optionShadowColor   = get_text_color_theme(:option_name)[1]
      @sprites[:options_list].baseColor           = get_text_color_theme(:unselected_value)[0]
      @sprites[:options_list].shadowColor         = get_text_color_theme(:unselected_value)[1]
      @sprites[:options_list].selectedColor       = get_text_color_theme(:selected_value)[0]
      @sprites[:options_list].selectedShadowColor = get_text_color_theme(:selected_value)[1]
      @sprites[:options_list].unsetColor          = get_text_color_theme(:unset_control)[0]
      @sprites[:options_list].unsetShadowColor    = get_text_color_theme(:unset_control)[1]
      @sprites[:options_list].options             = options_for_page(@page)
    end

    #-----------------------------------------------------------------------------

    def all_pages
      ret = []
      PageHandlers.each_available(@menu) do |page, hash, name|
        ret.push([page, hash[:order] || 0])
      end
      ret.sort_by! { |val| val[1] }
      ret.map! { |val| val[0] }
      return ret
    end

    def set_page(value)
      return if @page == value
      @page = value
      @sprites[:options_list].options = options_for_page(@page)
      refresh
    end

    def go_to_next_page
      pages = all_pages
      page_number = pages.index(@page)
      new_page = pages[(page_number + 1) % pages.length]
      return if new_page == @page
      pbPlayCursorSE
      set_page(new_page)
    end

    def go_to_previous_page
      pages = all_pages
      page_number = pages.index(@page)
      new_page = pages[(page_number - 1) % pages.length]
      return if new_page == @page
      pbPlayCursorSE
      set_page(new_page)
    end

    def index
      return @sprites[:options_list].index
    end

    def set_index(value)
      old_index = index
      @sprites[:options_list].index = value
      refresh_on_index_changed(old_index)
    end

    def options_for_page(this_page)
      return @options.filter { |option| option[:page] == this_page }
    end

    def selected_option
      return @sprites[:options_list].selected_option
    end

    #-----------------------------------------------------------------------------

    def refresh
      super
      refresh_page_tabs
      refresh_page_cursor
      refresh_options_list
      refresh_selected_option
    end

    def refresh_on_index_changed(old_index)
      refresh_selected_option
      if (old_index < 0) != (index < 0)
        refresh_page_cursor
        refresh_options_list
      end
    end

    def refresh_page_tabs
      @sprites[:page_icons].bitmap.clear
      all_pages.each_with_index do |this_page, i|
        tab_x = i * ((@bitmaps[:page_icons].width / 2) + PAGE_TAB_SPACING)
        draw_image(@bitmaps[:page_icons], tab_x, 0,
                  (this_page == @page) ? @bitmaps[:page_icons].width / 2 : 0, 0,
                  @bitmaps[:page_icons].width / 2, @bitmaps[:page_icons].height, overlay: :page_icons)
        page_handler = PageHandlers.call(@menu, this_page)
        page_name = page_handler[:name].call
        draw_text(page_name, tab_x + (@bitmaps[:page_icons].width / 4), 14,
                  align: :center, theme: :page_name, overlay: :page_icons)
      end
    end

    def refresh_page_cursor
      @sprites[:page_cursor].visible = (index < 0)
      @sprites[:page_cursor].x = @sprites[:page_icons].x - 2
      @sprites[:page_cursor].x += all_pages.index(@page) * ((@bitmaps[:page_icons].width / 2) + PAGE_TAB_SPACING)
    end

    def refresh_options_list
      @sprites[:options_list].refresh
    end

    def refresh_selected_option
      # Call selected option's "on_select" proc (if defined)
      @sprites[:speech_box].letterbyletter = false
      # Set descriptive text
      description = ""
      option = selected_option
      if index < 0   # Selecting a tab
        page_handler = PageHandlers.call(@menu, @page)
        if page_handler && page_handler[:description].is_a?(Proc)
          description = page_handler[:description].call
        elsif page_handler && !page_handler[:description].nil?
          description = _INTL(page_handler[:description])
        end
      elsif option
        option[:on_select]&.call(self)   # Can change speech box's letterbyletter
        if option[:description].is_a?(Proc)
          description = option[:description].call
        elsif !option[:description].nil?
          description = _INTL(option[:description])
        end
      else   # Back
        description = _INTL("Atrás.")
      end
      @sprites[:speech_box].text = description
    end

    #-----------------------------------------------------------------------------

    def update_input_tabs
      if Input.repeat?(Input::DOWN)
        pbPlayCursorSE
        set_index(0)
      elsif Input.repeat?(Input::LEFT)
        go_to_previous_page
      elsif Input.repeat?(Input::RIGHT)
        go_to_next_page
      end
      # Check for interaction
      if Input.trigger?(Input::USE)
        pbPlayCursorSE
        set_index(0)
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        return :quit
      end
      return nil
    end

    def update_input
      # Update value change
      if @sprites[:options_list].value_changed
        selected_option[:set_proc].call(@sprites[:options_list].value, self)
      end
      # Do page selection
      return update_input_tabs if @sprites[:options_list].index < 0
      # Check for interaction
      if Input.trigger?(Input::USE)
        if selected_option && selected_option[:use_proc]
          pbPlayDecisionSE
          return :use_option
        end
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        set_index(-1)
      end
      return nil
    end

  end

  #===============================================================================
  #
  #===============================================================================
  class UI::Options < UI::BaseScreen
    ACTIONS = HandlerHash.new

    def initialize(in_load_screen = false, menu = :options_menu)
      @in_load_screen = in_load_screen
      @menu = menu
      @options = get_all_options(menu)
      super()
    end

    def initialize_visuals
      @visuals = UI::OptionsVisuals.new(@options, @in_load_screen, @menu)
    end

    def get_all_options(menu = :options_menu)
      ret = []
      seen_options = {}
      
      # First pass: collect all options and track which format they use
      MenuHandlers.each_available(menu) do |option, hash, name|
        has_explicit_page = !hash["page"].nil?
        
        # If this option was already seen with an explicit page, skip old format versions
        next if seen_options[option] && !has_explicit_page
        
        if hash["description"].is_a?(Proc)
          description = hash["description"].call
        elsif !hash["description"].nil?
          description = _INTL(hash["description"])
        end
        
        # Auto-assign page for options without one (backward compatibility)
        page = hash["page"] || auto_detect_page(hash["type"], hash["name"] || name)
        # Convert old option types to new format
        type = convert_option_type(hash["type"])
        
        option_data = {
          :option      => option,
          :page        => page,
          :name        => name,
          :description => description,
          :type        => type,
          :parameters  => hash["parameters"],
          :on_select   => hash["on_select"],
          :get_proc    => hash["get_proc"],
          :set_proc    => hash["set_proc"],
          :use_proc    => hash["use_proc"]
        }
        option_data[:parameters].map! { |val| _INTL(val) } if option_data[:type] == :array
        
        # Remove old version if it exists and this is a new format version
        if has_explicit_page && seen_options[option]
          ret.delete_if { |opt| opt[:option] == option }
        end
        
        ret.push(option_data)
        seen_options[option] = has_explicit_page
      end
      
      return ret
    end

    # Auto-detect appropriate page based on option type and name
    def auto_detect_page(type, name)
      name_lower = name.to_s.downcase
      # Check by name keywords
      return :audio if name_lower.include?("volumen") || name_lower.include?("volume") || 
                      name_lower.include?("bgm") || name_lower.include?("sound") || 
                      name_lower.include?("música") || name_lower.include?("music")
      return :graphics if name_lower.include?("frame") || name_lower.include?("marco") ||
                          name_lower.include?("screen") || name_lower.include?("pantalla") ||
                          name_lower.include?("text") || name_lower.include?("texto") ||
                          name_lower.include?("animation") || name_lower.include?("animación") ||
                          name_lower.include?("vsync") || name_lower.include?("autotile")
      # Default to gameplay for everything else
      return :gameplay
    end

    # Convert old option type classes to new format symbols
    def convert_option_type(type)
      return type if type.is_a?(Symbol)
      case type.to_s
      when "SliderOption"
        return :number_slider
      when "EnumOption"
        return :array
      when "NumberOption"
        return :number_type
      when "ButtonOption"
        return :use
      else
        return :array  # default fallback
      end
    end

    ACTIONS.add(:use_option, {
      :effect => proc { |screen|
        option = screen.visuals.selected_option
        option[:use_proc].call(screen)
      }
    })
  end
end