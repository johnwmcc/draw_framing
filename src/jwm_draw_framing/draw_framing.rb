## Draw Framing v0.6 rewrite from scratch
## D:\Documents\GitHub\draw_framing\src\draw_framing\draw_framing.rb
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
  puts "draw_framing.rb v0.6x loaded"
  
  # Declare array to hold current nominal sizes as lengths
		@@size_index = 1
		@@nom_size = [0.0.to_l,0.0.to_l] 
  # Declare array to hold last defined custom size
		@@custom_size = ["Custom default",0.0.to_l,0.0.to_l]
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


    # This is the standard Ruby initialize method that is called when you create
    # a new object.
    @ip1 = nil
    @ip2 = nil
    @xdown = 0
    @ydown = 0
    cursor = File.join(File.dirname(__FILE__), "framing_cursor.png")
    cursor_id = nil
    if cursor
    # Create the cursor with the hot spot at top left (0,0) of image
     @cursor_id = UI.create_cursor(cursor, 0, 0)
    end
  end # initialize

#------------------
  def activate
    puts "activate called"
    # The Sketchup::InputPoint class is used to get 3D points from screen
    # positions.  It uses the SketchUp inferencing code.
    # In this tool, we will have one insertion point and a second to determin orientation.
    @ip         = Sketchup::InputPoint.new
    @ip1        = Sketchup::InputPoint.new
    @ip2        = Sketchup::InputPoint.new
    @drawn      = false
    @last_drawn = nil
    Sketchup::set_status_text("Length", SB_VCB_LABEL)
    self.reset(nil)
    @cursor_text = "\n\nTest"
  end # activate

#------------------
  def deactivate view
    puts "deactivate called"
  end # deactivate

#------------------
  def onSetCursor
#    puts "setCursor called"
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
      puts "Mouse move called @state = " + @state.to_s
      when 2
      puts "Mouse move called @state = " + @state.to_s
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
#		getMenu()
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
    # Display cursor text to give feedback at cursor (about profile/size being placed)
    view.draw_text view.screen_coords(@ip1.position), @cursor_text  
  end

  
#------------------
	# onCancel  is called when the user hits the escape key
	def onCancel flag, view
      puts "onCancel called"
		self.reset(view)
	end
  
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
   puts "getMenu called"
	menu.add_item("Timber size (nominal)") { puts("Select timber size from context menu") } 
	menu.add_separator
	#puts @n_size.inspect
	#puts @c_menu.inspect
	# @n_size.each_index {|i|
			# menu.add_item(@n_size[i][0]) {@chosen_size = i; @cursor_text = "\n\n" + @n_size[i][0]; self.activate}}
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