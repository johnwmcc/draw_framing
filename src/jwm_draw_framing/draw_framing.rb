## Draw Framing v0.6 rewrite from scratch
## D:\Documents\GitHub\draw_framing\src\jwm_draw_framing\draw_framing.rb
## load "jwm_draw_framing/draw_framing.rb"
## Name: Draw Framing Tool
## Sketchup Extension plugin
## Tool to help draw Timber Frames using standard (UK) softwood timber sizes and custom sizes
## Author John McClenahan
## Date May 2012ff
## Adapted from CLineTool.rb by Jim Foltz
##   which in turn is adapted from
# LineTool Copyright 2005-2007, Google, Inc.

# The software (linetool.rb) was provided as an example of using the Ruby interface
# to SketchUp.

# License: The MIT License (MIT)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

#-----------------------------------------------------------------------------

require "sketchup.rb"

# Wrap everything in a module to create a unique namespace
module JWM

class DrawFraming
#------------------
  puts "****************************"
  puts "draw_framing.rb v0.6.0.2 loaded"
  
  # Set up class variables to hold details of standard sizes of timber
		@@profile_name = "PAR" # Key to currently selected profile type such as PAR, architrave etc 
    # Set initial default for size_index to select 2 x 1 inch or 50x25mm nominal size		
    @@size_index = 1 


  # Declare variables for later use
		@@PushPullToolID = 21041
		@@suspended = false
    
  # Establish array to store axis toggle state
  # Axis_lock = one of the AXES if locked, or Vector3d(0,0,0) for not locked
    @@axis_lock = Geom::Vector3d.new
    # Default initially to (red) x-axis for long dimension of timber
    #   to avoid problems if first pick is not on a face and no axis 
    #   has been specified by arrow key
    
    @@axis_lock = X_AXIS

  def initialize
    # Get model units (imperial or metric)
		model = Sketchup.active_model
		manager = model.options
		if provider = manager['UnitsOptions'] # Check for nil value
			@length_unit = provider['LengthUnit']
		else 
			UI.messagebox " Can't determine model units - please set them in Window/ModelInfo"
		end # if	

    # This is the standard Ruby initialize method that is called when you create
    # a new Tool object.
    @ip1 = nil
    @ip2 = nil
    @xdown = 0
    @ydown = 0
    cursor = File.join(File.dirname(__FILE__), "framing_cursor.png")
    cursor_id = nil
    if cursor
    # Create the cursor with the hot spot at top left (0,0) of image: 0 from left, 0 down from top
     @cursor_id = UI.create_cursor(cursor, 0, 0)
    end
    # Declare blank array for nominal sizes
    @n_size = []
    # Declare array to hold last defined custom size 
		@@custom_size = ["Custom default",0.0.to_l,0.0.to_l]
  end # initialize

#------------------
  def activate
    puts "activate called"

		# Set default timber size to 2" x 1" or 50 x 25mm (@chosen_size index = 1) if no size is set
		if !@chosen_size 
			@chosen_size = @@size_index # Size index was initialized to 1, or gets set later to be remembered here
		end
    # Update remembered timber size			
		@@size_index = @chosen_size 
    ## Build context menu array to display on R-click, to select timber size
		if @chosen_size >= 12 && @@custom_size[2] != 0# Then pop up a menu to set Custom Size(s)
			prompts = "Width", "Depth"
			values = [@@custom_size[1],@@custom_size[2]]
				results = inputbox prompts,	values, "Enter Custom Size (actual)"
			if results #not nil
				width, depth = results
				s_label = "Custom (actual) " + width.to_s + ' x ' + depth.to_s
				@@custom_size = [s_label,width.to_l ,depth.to_l ]
			end 
		end
    # puts "Chosen_size index = " + @chosen_size.to_s  
    # The Sketchup::InputPoint class is used to get 3D points from screen positions
    # It uses the SketchUp inferencing code.
    # In this tool, we will have one insertion point and a second to determine orientation.
    @ip         = Sketchup::InputPoint.new
    @ip1        = Sketchup::InputPoint.new
    @ip2        = Sketchup::InputPoint.new
    @drawn      = false
    @last_drawn = nil
    Sketchup::set_status_text("Pick first corner for timber profile", SB_PROMPT)
    # Get profile of default or last selected size
    
    @profile = profile "PAR", @chosen_size # Select profile according to profile name and size
# puts @profile[0,2].inspect
    # Select profile array elements from 2 to last (-1), omitting 
    #   profile name in profile[0] and size label in profile[1]
    @points = @profile[2..-1]
puts "Profile points = " + @points.inspect.to_s 
    self.reset(nil)
  end # activate

#------------------
  def deactivate view
    puts "deactivate called"
  end # deactivate

#------------------
  def onSetCursor
# puts "setCursor called"
    # Set the cursor to selected instance variable ID
    UI.set_cursor @cursor_id
  end # setCursor
  
#------------------
  def onMouseMove flags, x, y, view
    case@state
    when 0
##        puts "Mouse move called @state = " + @state.to_s
        # We are getting the first end of the line.  Call the pick method
        # on the InputPoint to get a 3D position from the 2D screen position
        # that is bassed as an argument to this method.
        @ip.pick view, x, y
        if( @ip != @ip1 )
            # if the point has changed from the last one we got, then
            # see if we need to display the point.  We need to display it
            # if it has a display representation or if the previous point
            # was displayed.  The invalidate method on the view is used
            # to tell the view that something has changed so that you need
            # to refresh the view.
            view.invalidate if( @ip.display? or @ip1.display? )
            @ip1.copy! @ip

            # set the tooltip that should be displayed to this point
            view.tooltip = @ip1.tooltip
        end
        when 1
# puts "Mouse move called @state = " + @state.to_s
      when 2
# puts "Mouse move called @state = " + @state.to_s
    end
  end # onMouseMove
  
#------------------
  def onLButtonDown flags, x, y, view
    puts "onLbuttonDown called"

		# When the user clicks the first time (@state == 1), we switch to getting the
		# second point.	When they click a second time we show the planned cross-section
		case @state
    when 0
			@ip1.pick view, x, y
				if( @ip1.valid? )
						# call the transformation method to get the component/group instance Transformation vector
            # from origin to first pick point
						@tf = @ip1.transformation
						@state = 1
						txt = "Select plane of cross section using cursor (arrow) keys - red = Right, green = Left, blue = up or down "
						Sketchup::set_status_text(txt, SB_PROMPT)
				else
					# txt << "on."
					# txt << "TAB = stipple."
					Sketchup::set_status_text(txt, SB_PROMPT)
					@xdown = x
					@ydown = y
        end #if
		when 1
		# create the cross-section on the second click
			if( @ip2.valid? )
				self.create_geometry(@ip1.position, @ip2.position, view)
				self.reset(view)
			end # if
    else
      puts "@state not between 0 and 1"
		end #case
    # Clear any inference lock
    view.lock_inference
  end # onLButtonDown
  
#------------------
  def onLButtonUp flags, x, y, view
    puts "onLButtonUp called"
  end # onLButtonUp

#------------------
  def onRButtonDown flags, x, y, view
    puts "onRButtonDown called"
    # Load plugin-specific R-click context menu
		getMenu()
	end

#------------------
  def onRButtonUp flags, x, y, view
    puts "onRButtonUp called"
    # does nothing in this Tool
	end
   
#------------------
	# onKeyDown is called when the user presses a key on the keyboard.
	# We are checking it here to see if the user pressed an arrow key to toggle axis lock on/off 
	# so that we can lock the plane of the chosen cross-section
  # VK_xxx keys are built-in Sketchup Ruby constants defining (some) of the keys on the keyboard
	
  def onKeyDown(key, repeat, flags, view)
##    puts "onKeyDown called"
  # Check for Arrow keys to toggle axis lock
    case  key 
    when VK_RIGHT # Right arrow key pressed: toggle red axis lock on/off
      if @@axis_lock == X_AXIS then # Red axis lock was on: turn all axis locks off
        @@axis_lock = Geom::Vector3d.new 0,0,0
      else
        @@axis_lock = X_AXIS # turn red axis lock on
      end
    when VK_LEFT # Left arrow key pressed: toggle green axis lock on/off
      if @@axis_lock == Y_AXIS then # Axis lock was on: turn all axis locks off
        @@axis_lock = Geom::Vector3d.new 0,0,0
      else
       @@axis_lock = Y_AXIS # turn green axis lock on
      end
    when VK_UP # Up  arrow key pressed: toggle blue axis lock on/off
      if @@axis_lock == Z_AXIS then # Axis lock was on: turn all axis locks off
        @@axis_lock = Geom::Vector3d.new 0,0,0
      else
        @@axis_lock = Z_AXIS # turn blue axis lock on
      end
    when VK_DOWN  # Down arrow key pressed: toggle blue axis lock on/off
      if @@axis_lock == Z_AXIS then # Axis lock was on: turn all axis locks off
        @@axis_lock = Geom::Vector3d.new 0,0,0
      else
        @@axis_lock = Z_AXIS # turn blue axis lock on
      end
    end
     puts"Selected axis = " + @@axis_lock.inspect.to_s


  end
   
#------------------
  def onKeyUp key, repeat, flags, view
    
  end
  
#------------------
  def onUserText text, view
    puts "onUserText called"
  end
  
#------------------
  def draw view
    puts "draw called"
    # This code highlights potential inference points and draws dotted inference lines between 
    #   existing geometry and current mouse position
    if( @ip1.valid? )
      if( @ip1.display? )
        @ip1.draw(view)
        @drawn = true
      end

      if( @ip2.valid? )
        @ip2.draw(view) if( @ip2.display? )

        # The set_color_from_line method determines what color
        # to use to draw a line based on its direction.	For example
        # red, green or blue.
        if view.inference_locked?
        line_width = 2
        else
        line_width = 1
        end
        view.line_width = line_width
        # option for type of dotted line to draw (not used here)
        # view.line_stipple = @opts['stipple']
        view.set_color_from_line(@ip1, @ip2)
        # Draw feedback geometry to show where object to be created will be placed
        self.draw_geometry(@ip1.position, @ip2.position, view)
        @drawn = true
      end
		end
    # Display cursor text to give feedback at cursor about what 
    #   size/type of object will be placed
    view.draw_text view.screen_coords(@ip1.position), @cursor_text  
  end

  
#------------------
	# onCancel  is called when the user hits the escape key
	def onCancel flag, view
      puts "onCancel called"
		self.reset(view)
	end

#------------------
  # Define profile of cross-section to be drawn
  # Profile is defined by two labels, followed by an array of points 
  #  which define a 2D polyline for the cross-section
  # Profile array elements:
  # 0 - (string) profile name (e.g., PAR, architrave, skirting, coving, moulding xxx)
  # 1 - (string) profile size (e.g., 2x1, 50x25)
  # 2 - (Array) 3d points defining cross section: minimum of three points. Must be coplanar with z=0 
  def profile   p_name, p_size
    # Calculate cross section array from dimensions for PAR
    case p_name
    when "PAR"
      case @length_unit
				when 0..1 # Units are imperial (inches or feet)
				## Define standard imperial timber sizes (nominal and actual)
					@n_size=[]
					@n_size[0]=['1 x 1',0.875.inch,0.875.inch]
					@n_size[1]=['2 x 1',1.75.inch,0.875.inch]
					@n_size[2]=['3 x 1',2.75.inch,0.875.inch]
					@n_size[3]=['4 x 1',3.75.inch,0.875.inch]
					@n_size[4]=['5 x 1',4.75.inch,0.875.inch]
          @n_size[5]=['6 x 1',5.75.inch,0.875.inch]
					@n_size[6]=['2 x 2',1.75.inch,1.75.inch]
					@n_size[7]=['3 x 2',2.75.inch,1.75.inch]
					@n_size[8]=['4 x 2',3.75.inch,1.75.inch]
					@n_size[9]=['6 x 2',5.75.inch,1.75.inch]
					@n_size[10]=['3 x 3',2.75.inch,2.75.inch]
					@n_size[11]=['4 x 4',3.75.inch,3.75.inch]		

					if @@custom_size[1] == 0.0 # if custom size hasn't been set, put in a default (actual) size 
						@@custom_size = ['Custom default 1/2 x 3/4',0.5.inch,0.75.inch]
					end
          
          @n_size[12] = @@custom_size

					when 2..4 # Units are metric (mm, cm, or metres)
				## Define standard metric timber sizes (nominal and actual)
					@n_size=[]
					@n_size[0]=['25 x 25 mm',22.0.mm, 22.0.mm]
					@n_size[1]=['50 x 25 mm',44.0.mm, 22.0.mm]
					@n_size[2]=['75 x 25 mm',69.0.mm, 22.0.mm]
					@n_size[3]=['100 x 25 mm',94.0.mm, 22.0.mm]
					@n_size[4]=['125 x 25 mm',119.0.mm, 22.0.mm]
					@n_size[5]=['150 x 25 mm',144.0.mm, 22.0.mm]
          @n_size[6]=['50 x 50 mm',44.0.mm, 44.0.mm]
					@n_size[7]=['75 x 50 mm',69.0.mm, 44.0.mm]
					@n_size[8]=['100 x 50 mm',94.0.mm, 44.0.mm]
					@n_size[9]=['150 x 50 mm',144.0.mm, 44.0.mm]
					@n_size[10]=['75 x 75 mm',69.0.mm, 69.0.mm]
					@n_size[11]=['100 x 100 mm',94.0.mm, 94.0.mm]

					if @@custom_size[1] == 0.0	# if custom size hasn't been set, put in a default size 
						@@custom_size = ["Custom default 13mm x 19mm ",13.mm,19.mm] 
					end 
          
          @n_size[12] = @@custom_size
				else # Something else 
					UI.messagebox "Model units are not defined"
			end # case @length_unit
      
      # Calculate profile points for selected PAR size
      width = @n_size[p_size][1]
      thickness = @n_size[p_size][2]
      # PAR is simply a rectangle with width and thickness, drawn in the x, y (red/green) plane
      profile = ["PAR", @n_size[p_size][0],[0,0,0],[width,0,0],[width,thickness,0],[0,thickness,0],[0,0,0]]
    else
      UI.messagebox "Sorry, that profile name isn't defined yet"
    end #case p_name
  end # profile
  
#------------------
	# The following methods are not directly called from SketchUp.	They are
	# internal methods that are used to support the other methods in this class.

	# Reset the tool back to its initial state
	def reset(view)
    puts "reset called" 
    @state = 0  
  end
  
#------------------
## Draw the geometry to show where the cross-section will be placed
	def draw_geometry(pt1, pt2, view)
    puts "draw_geometry called"
    
      
  end  
  
#------------------
## Create geometry for the cross-section in the model
  def create_geometry(p1, p2, view)
    puts "create_geometry called"
  end
  
#------------------
  def suspend(view)
    puts "suspend called"
  end
  
#------------------
  def resume(view)
    puts "resume called"
  end # resume

#------------------
	def load_opts
      puts "load_opts called"
  end

#------------------

 def getMenu(menu)
#   puts "getMenu called"
	menu.add_item("Timber size (nominal)") { puts("Select timber size from context menu") } 
	menu.add_separator
	 @n_size.each_index {|i|
			menu.add_item(@n_size[i][0]) {@chosen_size = i; @cursor_text = "\n\n" + @n_size[i][0]; self.activate}}
 end
 
#------------------
# Add a translation vector to a transformation
 	def translate( *args ) 
  # From Martin Rinehart 'Edges to Rubies' chapter 15
  # May be called with a transformation and a vector, 
  # or with a transformation and r, g, b values.

    trans = args[0]
    if args.length == 2
        vec = args[1]
        r = vec[0]; g = vec[1]; b = vec[2] 
    else
        r = args[1]; g = args[2]; b = args[3] 
    end
    arr = trans.to_a()
    arr[12] += r; arr[13] += g; arr[14] += b 
    return Geom::Transformation.new( arr )
    
	end # of translate()

end # class DrawFraming
end # module JWM

#------------------
# Load new drawing tool
unless file_loaded?(__FILE__)
	cmd = UI::Command.new("Timber Frame") {Sketchup.active_model.select_tool(JWM::DrawFraming.new)}
	my_dir	 = File.dirname(File.expand_path(__FILE__))
	cmd.small_icon = File.join(my_dir, "framing_icon_sm.png")
	cmd.large_icon = File.join(my_dir, "framing_icon_lg.png")
	cmd.tooltip	= "Timber Frame"
	cmd.menu_text	= "Timber Frame"

	menu = UI.menu("Draw")
	menu.add_item(cmd)
	
	## Add tool-specific context menu 
	tb = UI.toolbar("Timber Frame")
	tb.add_item(cmd)
	if tb.get_last_state == TB_VISIBLE
	UI.start_timer(0.1, false) { tb.restore }
	elsif tb.get_last_state == TB_NEVER_SHOWN
	tb.show
	end
end
file_loaded(__FILE__)