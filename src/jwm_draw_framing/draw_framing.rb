 ## Draw Framing v0.6 rewrite from scratch
## D:\Documents\GitHub\draw_framing\src\draw_framing\draw_framing.rb
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
  puts "draw_framing.rb v0.6.2.1 loaded"
  
  # Set up class variables to hold details of standard sizes of timber
		@@profile_name = "PAR" # Key to currently selected profile type such as PAR, architrave etc 
    # Set initial default for size_index to select 2 x 1 inch or 50x25mm nominal size		
    @@size_index = 1 

  # Declare variables for later use
		@@PushPullToolID = 21041
		@@suspended = false
    # used to denote that there is no axis-lock set
    NO_LOCK = Geom::Vector3d.new 0,0,0 


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

    # Declare vector to become the direction of the long axis of timber to be placed
    # defaults to Z_AXIS on initialization
    @long_axis = Z_AXIS.clone #Geom::Vector3d.new 0,0,1 
    @frame_length = 1.0
  end # initialize

#------------------
  def activate
    puts "activate called"

    # Establish array to store axis toggle state
    # Axis_lock = one of the AXES if locked, or Vector3d(0,0,0) for not locked
    @@axis_lock = Geom::Vector3d.new
    # Default initially to (blue) z-axis for long dimension of timber
    #   to avoid problems if first pick is not on a face and no axis 
    #   has been specified by arrow key
    @@axis_lock = NO_LOCK

    # Default axis of rotation when picking on blank screen 
    #@vec5 = Geom::Vector3d.new 0,1,0    



		# Set default timber size to 2" x 1" or 50 x 25mm (@chosen_size index = 1) if no size is set
		if !@chosen_size 
			# Size index was initialized to 1, or gets set later to be remembered here
      @chosen_size = @@size_index 
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
				s_label = width.to_s + ' x ' + depth.to_s
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
    @ip3        = Sketchup::InputPoint.new
    @drawn      = false
    @last_drawn = nil
    @flip       = 0 # flip state - cycles through 0-3 to flipX, flipY, flipXY, or noflip

    Sketchup::set_status_text("Pick first corner for timber profile, and/or set a long axis direction using cursor key to toggle on/off: Right = red (X); Left = green (Y); Up or Down= blue (Z) direction", SB_PROMPT)
    # Get profile of default or last selected size
    @profile = profile "PAR", @chosen_size # Select profile according to profile name and size

    # Declare arrays to hold timber profile points
		@profile_points = []
    @profile_points0 = []
    @profile_points1 = []

    # Display chosen size at cursor
    @cursor_text = "\n\n" + @profile[1] 
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
    case @state # Check what state the tool is in
    when 0 # no mouse click yet made
# puts "Mouse move called @state = " + @state.to_s
        # We are getting the first end of the line.  Call the pick method
        # on the InputPoint to get a 3D position from the 2D screen position
        # that is passed as an argument to this method.
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
    when 1 # After first click

        
			# Waiting for the second pick point which defines the orientation of the timber cross-section
			# If you pass in another InputPoint on the pick method of InputPoint
			# it uses that second point to do additional inferencing such as
			# parallel to an axis.
      @ip2.pick view, x, y, @ip1
			view.tooltip = @ip2.tooltip if( @ip2.valid? )

			# Update the length displayed in the VCB
			if( @ip2.valid? )
				length = @ip1.position.distance(@ip2.position)
				Sketchup::set_status_text length.to_s, SB_VCB_VALUE
			end

			# Check to see if the mouse was moved far enough to confirm the orientation of the chosen cross-section
			# This is used so that you can create a cross-section by either dragging
			# or doing click-move-click
			if( (x-@xdown).abs > 10 || (y-@ydown).abs > 10 )
				@dragging = true
			end
			view.invalidate
# puts "State = " + @state.to_s      
      # Now orient the cross section according to the mouse position relative to pick point
      # Get current mouse position on screen
# puts "Screen coords = " + x.inspect.to_s + ", " +  y.inspect.to_s
      #----------------------------------------------------
      # Compare current mouse position with first pick point to determine which quadrant to draw cross section in (remember, screen coords have +y = downwards)
      diff_x = x - view.screen_coords(@first_pick)[0]
      diff_y = y - view.screen_coords(@first_pick )[1]

#  puts "First pick point screen coords = " + (view.screen_coords(@first_pick)).inspect.to_s
      
      # See whether mouse position relative to @first_pick is nearer vertical than horizontal
      # If so, orient profile accordingly
      if diff_x >= 0  && diff_y <= 0 # upper right quadrant
        @quadrant = 0
        if diff_y.abs > diff_x.abs # In this quadrant, this means use vertical profile
          @swap_XY = true
        else
          @swap_XY = false
        end
      end

      if diff_x < 0 && diff_y <= 0 # upper left quadrant
        @quadrant = 1
        if diff_y.abs > diff_x.abs
          @swap_XY = false # Profile rotated to this quadrant is vertical without swap
        else
          @swap_XY = true
        end
      end

      if diff_x < 0 && diff_y > 0# lower left quadrant
        @quadrant = 2
        if diff_y.abs > diff_x.abs
          @swap_XY = true # In this quadrant, this means use vertical profile
        else
          @swap_XY = false
        end
      end
      
      if diff_x >= 0 && diff_y > 0# lower right quadrant
        @quadrant = 3
        if diff_y.abs > diff_x.abs
          @swap_XY = false
        else
          @swap_XY = true
        end

# puts "diff_x, diff_y  = " + diff_x.to_f.to_s + ", " + diff_y.to_f.to_s
      end
# puts "Quadrant = " + @quadrant.to_s + " and @swap_XY = " + @swap_XY.to_s

# --------------------------------------------------------------------------
      when 2 #  after second click - waiting for PushPull operation
# puts "Mouse move called @state = " + @state.to_s
        # Getting the second end of the line
        # If you pass in another InputPoint on the pick method of InputPoint
        # it uses that second point to do additional inferencing such as
        # parallel to an axis.
        @ip3.pick view, x, y, @first_pick
        view.tooltip = @ip3.tooltip if( @ip3.valid? )

        # Update the length displayed in the VCB
        if( @ip3.valid? )
          # Calculate length along axis
          how_long = @first_pick.position.distance @ip3.position
          vec = @first_pick.position.vector_to @ip3.position
          angl = vec.angle_between  @long_axis
          @frame_length = Math.cos(angl) * how_long
# puts "Frame length = " + @frame_length.to_s
          Sketchup::set_status_text "Length" , SB_VCB_LABEL
          Sketchup::set_status_text @frame_length.to_s, SB_VCB_VALUE
        end
        # @face.pushpull length
        # Check to see if the mouse was moved far enough to create a line.
        # This is used so that you can create a line by either draggin
        # or doing click-move-click
        if( (x-@xdown).abs > 10 || (y-@ydown).abs > 10 )
          @dragging = true
        end
        view.invalidate        
    end
  end # onMouseMove
  
#------------------
  def onLButtonDown flags, x, y, view
#puts "onLbuttonDown called"
#puts "@state = " + @state.to_s
		# When the user clicks the first time (@state changes from 0 to 1), we switch to getting the
		# second point.	When they click a second time we show the planned cross-section
		case @state
    when 0 # on first click
			@ip1.pick view, x, y
				if( @ip1.valid? )
          #-------------------------
          ## Calculate translation needed from world or component origin to first corner of profile
          # call the transformation method to get the component/group instance Transformation vector
          # from origin to first pick point
          @first_pick = @ip1
          @tf = @first_pick.transformation
# puts "@tf = " + @tf.to_matrix
          # Update state to show first click has been processed
          @state = 1

          # Update status bar text
          txt = "Pick or drag orientation of cross section, and/or choose long axis using cursor (arrow) keys - Right = red, Left = green, Up or Down = blue"
          Sketchup::set_status_text(txt, SB_PROMPT)

          #------------------------------
          # Create new transformation objects (the identity transformation by default) for later use
          @tf_identity = Geom::Transformation.new # Identity transform to insert component at origin
          @tf3 = Geom::Transformation.new
          @tf4 = Geom::Transformation.new
          @tf5 = Geom::Transformation.new
          @tf6 = Geom::Transformation.new

          #--------------------------------
          # Get profile shape from @profile 
       
       
          # Original orientation is horizontal (vertical when rotated to second or fourth quadrant)
          @profile_points_a = @profile[2..-1] # Get profile points from original (horizontal) profile
 # puts "@profile_points_a = " + @profile_points_a.inspect.to_s
          # When profile is opposite orientation, then swap x, y coords
          # @profile_points_b = swap_xy @profile_dup.clone 
 # puts "@profile_points_b = " + @profile_points_b.inspect.to_s
          #------------------------------
          ## Detect if pick point is on a face, and if so, orient long axis normal to it
          #   unless axis is locked
          if @ip.face 
            f = @ip.face
# puts "@ip.face = " + @ip.face.inspect.to_s
# puts  "Face picked: normal is \n"
# puts f.normal.inspect
            if @@axis_lock == NO_LOCK # axis not locked
              @long_axis = f.normal
            else
              @long_axis = @@axis_lock
            end

            #------------------------------
            # Calculate vector which is the projection of the @long_axis onto the x-y (red-green) plane
            vec3 = Geom::Vector3d.new @long_axis.x, @long_axis.y, 0
            # Get angle between vec3 and X_AXIS, and calculate its sign
            if @long_axis.y < 0.0
              rotate3 = -(X_AXIS.angle_between vec3)
            else
              rotate3 = X_AXIS.angle_between vec3 
            end # if @long_axis.y
#  puts "rotate3 angle = " + rotate3.radians.to_s
            
            # Set up transform to rotate the cross-section by this amount around Z_AXIS at world or component origin 
            @tf3 = Geom::Transformation.rotation [0,0,0], Z_AXIS, rotate3

          #------------------------------
          else # no face at pick point
            # When no face picked, default long axis to Z_AXIS if no axis lock set 
            if @@axis_lock == NO_LOCK 
              @long_axis = Z_AXIS
            else
              @long_axis = @@axis_lock
            end #if @@axis_lock

          end # if @ip.face
          
          ## At this point, we should have the long axis set and the normal to it (vec5) set 
          #   in the plane normal to the long axis
          #------------------------------
          # Calculate the rotation axis for the second transformation as the normal 
          #   to the Z_AXIS/@long_axis plane, which is the cross-product of the 
          #   @long_axis and the Z_AXIS vectors, unless @long_axis is Z_AXIS or its reverse
          if @long_axis != Z_AXIS && @long_axis != Z_AXIS.clone.reverse!
            @vec5 = Z_AXIS.cross @long_axis
          else
            @vec5 = Y_AXIS
          end # if @long_axis
#puts "@long_axis = " + @long_axis.inspect.to_s
#puts "@vec5 = " + @vec5.inspect.to_s

          #------------------------------
          # Define third transform to finish rotating cross section into picked face plane, 
          #   or normal to chosen axis lock
          
          # Calculate angle between @long_axis and the Z_AXIS
#puts "@long_axis= " + @long_axis.inspect.to_s            
          rotate4 = @long_axis.angle_between Z_AXIS
#puts "rotate4 angle = " + rotate4.radians.to_s 
          # Define 90 degree rotation about pick point around long axis vector
          #  which will be needed if cross section needs to be rotated into desired orientation
          @tf4 = Geom::Transformation.rotation [0,0,0], @vec5, rotate4            
#puts "@first_pick.position = " + @first_pick.position.to_s
          @rotate90_la = Geom::Transformation.rotation [0,0,0], @long_axis, 90.degrees
#  puts @rotate90_la.to_matrix 

          # Calculate transform to mirror along Y-Z plane to swap orientation
          @tf_swap = Geom::Transformation.scaling [0,0,0],-1,1,1
          
          # Combine the transformations @tf3 and @tf4 if they exist, otherwise leave @tf5 
          # as identity transform
          # if @tf3 && @tf4
            # @tf5 = @tf4 * @tf3
          # end
				else # in case mouse is being dragged
					# txt << "on."
					# txt << "TAB = stipple."
					# Sketchup::set_status_text(txt, SB_PROMPT)
					@xdown = x
					@ydown = y
        end #if @ip1.valid?

    when 1

      # Create the cross-section on the second click
			if( @ip2.valid? )
				self.create_geometry(@first_pick.position, @ip2.position, view)
				# self.reset(view)
        @state = 2 
			end # if @ip2.valid
      txt = "Press TAB key to flip cross-section along X, Y, both, or neither direction"
      Sketchup::set_status_text(txt, SB_PROMPT)
    when 2 # Fix the length of the component on third click or onLButtonUp
      @state = 3
      # puts "onLButtonDown " + @state.to_s
      # puts "@frame_length = " + @frame_length.to_s
      self.create_geometry(@first_pick.position,@ip3.position, view)
    else
      puts "@state not a valid value"
		end #case @state
    # Clear any inference lock
    view.lock_inference
    
  end # onLButtonDown
  
#------------------
  def onLButtonUp flags, x, y, view
# puts "onLButtonUp called"
    # If we are doing a drag, then create the cross-section on the mouse up event
		if @state == 1
			if( @dragging && @ip2.valid? )
				self.create_geometry(@first_pick.position, @ip2.position,view)
				#self.reset(view)
			end
      txt = "Press TAB key to flip cross-section along X, Y, both, or neither direction"
      Sketchup::set_status_text(txt, SB_PROMPT)
		elsif @state == 2 ## waiting for third click to define length of timber to draw

		end
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
# puts "onKeyDown called"
  # Check for Arrow keys to toggle axis lock
    case key 
    when VK_RIGHT # Right arrow key pressed: toggle red axis lock on/off
      if @@axis_lock == X_AXIS then # Red axis lock was on: turn all axis locks off
        @@axis_lock = NO_LOCK
        @cursor_text = "\n\n" + @profile[1]
      else
        @@axis_lock = X_AXIS # turn red axis lock on
        # Reset long axis to axis lock and recalculate @vec5
        @long_axis = @@axis_lock
        @vec5 = Z_AXIS.cross @long_axis
        @cursor_text = "\n\n" + @profile[1] + "\nX locked"
      end
    when VK_LEFT # Left arrow key pressed: toggle green axis lock on/off
      if @@axis_lock == Y_AXIS then # Y-axis lock was on: turn all axis locks off
        @@axis_lock = NO_LOCK
        @cursor_text = "\n\n" + @profile[1]
      else
       @@axis_lock = Y_AXIS # turn green axis lock on
       # Reset long axis to axis lock and recalculate @vec5
       @long_axis = @@axis_lock
       @vec5 = Z_AXIS.cross @long_axis
       @cursor_text = "\n\n" + @profile[1] + "\nY locked"
      end
      #view.refresh
    when VK_DOWN # Up  arrow key pressed: toggle blue axis lock on/off
      if @@axis_lock == Z_AXIS then # Axis lock was on: turn all axis locks off
        @@axis_lock = NO_LOCK
        @cursor_text = "\n\n" + @profile[1]
      else
        @@axis_lock = Z_AXIS # turn blue axis lock on
        # Reset long axis to axis lock 
        @long_axis = @@axis_lock
        @vec5 = Y_AXIS
        @cursor_text = "\n\n" + @profile[1] + "\nZ locked"
      end
    when VK_UP  # Down arrow key pressed: toggle blue axis lock on/off
      if @@axis_lock == Z_AXIS then # Axis lock was on: turn all axis locks off
        @@axis_lock = NO_LOCK
      else
        @@axis_lock = Z_AXIS # turn blue axis lock on
        # Reset long axis to axis lock and recalculate @vec5
        @long_axis = @@axis_lock
        @vec5 = Y_AXIS
        @cursor_text = "\n\n" + @profile[1] + "\nZ locked"
      end
    when CONSTRAIN_MODIFIER_KEY
      if( repeat == 1 )
      @shift_down_time = Time.now
# puts "CONSTRAINED"
        # if we already have an inference lock, then unlock it
        if( view.inference_locked? )
          # calling lock_inference with no arguments actually unlocks
          view.lock_inference
        elsif( @state == 0 && @ip1.valid? )
          view.lock_inference @ip1
          view.line_width = 3
        elsif( @state <= 2 && @ip2.valid? )
          view.lock_inference @ip2, @ip1
          view.line_width = 3
        end
      end
    when 9 # Tab key: Cycle through flipX, flipY, flipXY, noflip
#puts "@state = " + @state.to_s
    if @state == 1   # Only applicable when cross-section has been drawn
        @flip = (@flip + 1)%4 

#puts "flip state = " + @flip.to_s
      # Reorient inserted profile
      # If needed, flip profile in x, y, or both directions
      bb_centre = @face.bounds.center
      flip_x = Geom::Transformation.scaling bb_centre, -1.0,1.0,1.0
      flip_y = Geom::Transformation.scaling bb_centre, 1.0,-1.0,1.0
      #if @comp_defn.instances[-1] # don't try unless there's something created 
          case @flip 
          when 0 # flip X
            @comp_defn.instances[-1].transform! flip_x
          when 1 # flip Y
            @comp_defn.instances[-1].transform! flip_y
          when 2 # flip X & Y
            @comp_defn.instances[-1].transform! flip_x
            @comp_defn.instances[-1].transform! flip_y
          when 3 # flip back to original
            @comp_defn.instances[-1].transform! flip_y
          end # case @flip
        end # if@comp_defn.instances[-1]
#      end # if @state
    end # case key

 #   puts"Selected axis = " + @@axis_lock.inspect.to_s
    # force change of cursor on screen
    self.onSetCursor() 
    false

  end
   
#------------------
  def onKeyUp key, repeat, flags, view
    #force redraw
    view.invalidate
    view.refresh    
  end
  
#------------------
  def onUserText(text, view)
    # We only accept input when the state is 2 (i.e. select the third point to fix length)
    #return if not @state == 1
    #return if not @ip2.valid?
    #p @ip2.valid?
# puts "onUserText called"
    # The user may type in something that we can't parse as a length
    # so we set up some exception handling to trap that
    begin
      value = text.to_l
    rescue
      # Error parsing the text
      UI.beep
      UI.messagebox "Cannot convert " + #{text} + " to a Length"
      value = nil
      Sketchup::set_status_text "", SB_VCB_VALUE
    end
    return if !value

    if @state == 2 and @ip3.valid?
      # Compute the direction and the second point
      pt1 = @ip1.position
      vec = @ip3.position - pt1
      if( vec.length == 0.0 )
          UI.beep
          return
      end
      vec.length = value
      pt2 = pt1 + vec

      # Create the frame element
      # Return length and set value
      @frame_length = value
      # Finish drawing the geometry
      flags = nil
      x = nil
      y = nil
      view = @model.active_view
      self.onLButtonDown(flags, x, y, view)
    end
    ## Note by JWM - not sure what this bit does. Leave for the moment but comment out
    # if @last_drawn and @state == 0
      # pt1 = @last_drawn[0].start
      # vec = @last_drawn[0].end - @last_drawn[0].start
      # vec.length = value
      # pt2 = pt1 + vec
      # view.model.active_entities.erase_entities @last_drawn
      ##@last_drawn = nil
      # self.create_geometry(pt1, pt2, view)
      # self.reset view
    # end
  end #onUserText

#------------------
  def draw view
# puts "draw called"
    # This code highlights potential inference points and draws dotted inference lines between 
    #   existing geometry and current mouse position
    if( @ip1.valid? )
      if( @ip1.display? )
        @ip1.draw(view)
        @drawn = true
      end

      if( @ip2.valid? )
# puts "@ip2 in 'draw' is valid"
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
        self.draw_geometry(@first_pick.position, @ip2.position, view)
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
    #  puts "onCancel called"
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
						@@custom_size = ['1/2 x 3/4',0.5.inch,0.75.inch]
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
						@@custom_size = ["13mm x 19mm ",13.mm,19.mm] 
					end 
          
          @n_size[12] = @@custom_size
				else # Something else 
					UI.messagebox "Model units are not defined"
			end # case @length_unit
      
      # Calculate profile points for selected PAR size
      width = @n_size[p_size][1]
      thickness = @n_size[p_size][2]
      # PAR is simply a rectangle with width and thickness, drawn in the x, y (red/green) plane
      # For testing, put in an angle
      profile = ["PAR", @n_size[p_size][0],[0,0,0],[0.5*width,0,0],[width,0.5*thickness,0],[width,thickness,0],[0,thickness,0],[0,0,0]]
      # Make an array of just the profile points
      @profile_points_a = profile[2..-1]
      return profile
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
    # clear the InputPoints
    @ip1.clear
    @ip2.clear
    @ip.clear

    if( view )
        view.tooltip = nil
        view.refresh if @drawn
    end

    @drawn = false
    @dragging = false
  end
  
#------------------
## Draw the geometry to show where the cross-section will be placed
	def draw_geometry(pt1, pt2, view)
#    puts "draw_geometry called"
    # Draw timber profile 
    # This method has to take account of 
    # - the shape of the timber cross-section defined in @profile array
    # - whether to flip the cross-section L-R and/or top to bottom 
    #     (to be set by the TAB key cycling through L-R = 1, T-B = 2, L-R and T-B = 3, or no flip = 0)
    # - the position of the @first_pick (insertion) point relative to
    #     world or component origin, which was defined by the transformation @tf
    # - the direction of the @long_axis vector for the length of the inserted timber, which 
    #     may be locked to a vector @@axis_lock set by a cursor arrow key 
    #     to one of of the X, Y or Z axes, or picked normal to a face; or if no face is picked,
    #     and no axis lock is set, to the Z axis by default
    # - the current position of the mouse pointer screen coordinates relative to @first_pick 
    #     screen position, defined by diff_x and diff_y, to calculate 
    #   . which screen @quadrant (upper right, upper left, lower left or lower right)
    #       the mouse is in (relative to @first_pick)and hence whether to draw cross-section rotated
    #       by 0, 90, 180 or 270 degrees around the @long_axis vector
    #   . whether diff_x or diff_y is larger, and hence whether to draw the profile with its 
    #       longer cross-section horizontal or vertical

    # If any relevant key is pressed to change the axis lock or flip direction, before 
    #   the mouse is released after dragging, or clicked a second time, 
    #   the profile needs to be redrawn with the new value(s)

    case @state
    when 1 # After first click, waiting for second click or onLButtonUp

# puts "Profile points0 = " + @profile_points0.inspect.to_s
    # Vector from component or world origin 
      origin = @tf.origin
# puts "origin = " + origin.inspect.to_s
      vec = origin.vector_to(pt1) # Vector from there to pick point
# puts "vec = " + vec.inspect.to_s
      # Calculate transformation from component or world origin to first pick point
      @tf2 = translate(@tf,vec) # Uses Martin Rinehart's translate function included below
# puts "@tf2 = " + @tf2.inspect.to_s    

        # If orientation (calculated from mouse position relative to first pick) is vertical 
        #   where it would otherwise be drawn horizontal, and vice versa,
        #   swap x and y coordinates of basic profile
      if @swap_XY
          @profile_points_a.each_index {|i| @profile_points0[i] = @profile_points_a[i].transform(@tf_swap)} # mirror X-coords
          # Reduce rotation by 90 degrees by reducing @quadrant
          @quad = (@quadrant + 3)%4 # Take modulus 4 to 'wrap around' @quadrant 0
      else 
          @profile_points0 = @profile_points_a.clone # original coordinates
          @quad = @quadrant
      end
 # puts @swap_XY
 # puts @profile_points0.inspect
      # Reorient inserted profile
      # If needed, flip profile in x, y, or both directions
      # profile_center = Geom::Point3d.linear_combination 0.5,@profile_points0.min, 0.5, @profile_points0.max
# puts "BB center = " + profile_center.inspect
   
      # flip_x = Geom::Transformation.scaling profile_center, -1.0,1.0,1.0
      # flip_y = Geom::Transformation.scaling profile_center, 1.0,-1.0,1.0
      # temp = []
      # temp = @profile_points.clone
#puts temp.inspect
      # case @flip 
      # when 0
      #  do nothing
      # when 1 # flip X
        # @profile_points0.each_index{|i| @profile_points0 = temp[i].transform flip_x}
#puts "@flip = " + @flip.to_s
      # when 2 # flip Y
        # @profile_points0.each_index{|i| @profile_points0 = temp[i].transform flip_y}
#puts "@flip = " + @flip.to_s
      # when 3 # flip X & Y
        # @profile_points0.each_index{|i| @profile_points0 = temp[i].transform flip_x}
        # @profile_points0.each_index{|i| @profile_points0 = temp[i].transform flip_y}

#puts "@flip = " + @flip.to_s
      # end # case @flip
 
    # Rotate about Z_AXIS at origin so as to be parallel in the x-y (rg) plane to the face normal.
    @profile_points0.each_index {|i| @profile_points1[i] = @profile_points0[i].transform(@tf3)} 
    
    # The profile needs to be revolved about the line 
    #  which is normal to the Z_AZIS AND to the face.normal if on a face, 
    #  unless the face.normal or @@axis_lock IS the Z_AXIS, in which case no revolution needed.
    # And to get the normal, we took the cross-product of 
    #  the Z_AZIS and the face.normal in onLButtonDown.

		@profile_points1.each_index {|i| @profile_points[i] = @profile_points1[i].transform(@tf4)} 

    #See if mouse position requires profile to be reoriented
    i = 1
    if @swap_XY
      # Rotate by 90 degrees about @long_axis @quad times
      
      while i <= (@quad )%4 do
        @profile_points.each_index {|i| @profile_points[i].transform! @rotate90_la }
        i += 1
      end  
    else 
      while i <= @quad do
        @profile_points.each_index {|i| @profile_points[i].transform! @rotate90_la }
        i += 1
      end  
    end # if @swap_XY

    # Relocate profile to first pick point (transform @tf2) 
    @profile_points.each_index {|i| @profile_points[i].transform!(@tf2)}   

 #   	puts "@profile_points[] = \n" + @profile_points.to_a.inspect

    
 
      # Display long axis as visual feedback
      #@long_axis.transform!(@tf2)
      view.line_width = 2; view.line_stipple = ""
      view.set_color_from_line(pt1 - @long_axis, pt1 + @long_axis)
      view.draw_line(@first_pick.position, @first_pick.position + @long_axis) # to show direction of long axis of wood  
      

      # end
      # Draw normal to Z_AXIS/face.normal in orange
# puts "@vec5.to_a = " + @vec5.inspect.to_s, @vec5.to_a.to_s
      pt3 = @vec5.to_a.transform @tf2
      view.drawing_color = "orange" 
      view.draw_line(pt1,pt3)
      
      view.drawing_color = "magenta" 
      view.draw_polyline(@profile_points)
# -------------------------------------------------------------------------------
    when 2 # Cross-section drawn, waiting for drag or click to pushpull to length
      # @frame_length was defined in onMouseMove @state == 2
      # Define translation to move profile outline along @long_axis by @frame_length
      # @tf6 = translate(@first_pick.position, @first_pick.position.offset(@long_axis, @frame_length))
      # @vec6 = @first_pick.position.vector_to @first_pick.position.offset(@long_axis, @frame_length)
     # Flip X, Y, both or neither to orient face
 
# puts "flip state = " + @flip.to_s
     
      view.drawing_color = "magenta" 
      view.draw_polyline(@profile_points)
      view.draw_line @first_pick.position, @first_pick.position.offset(@long_axis, @frame_length)
    end # case @state
end # draw_geometry
  
# ====================================================
## Create geometry for the cross-section in the model
  def create_geometry(p1, p2, view)
#    puts "create_geometry called"
 		if @state < 2 #then we haven't yet created any geometry, so create the cross-section face
			@model = Sketchup.active_model
			@model.start_operation("DrawFraming")
  		@state = 2 # Waiting for pick or VCB entry to define length of component
      
      @@df_tool_id = @model.tools.active_tool_id # Remember DrawFraming tool_id
      # Create an empty component definition
      @ents = @model.definitions
      @comp_defn = @ents.add("comp")

      # Create an empty group to draw into
			# @grp = @model.active_entities.add_group()
			# @ents = @grp.entities

      # Define cross-section and name it

			comp_defn_name = UI.inputbox ["Component name "],["Frame element"],"Name this component " 
			if comp_defn_name # isn't nil (naming inputbox not cancelled)
        @comp_defn.name = @n_size[@chosen_size][0] + " " + comp_defn_name[0].to_s
				@comp_defn.description = @n_size[@chosen_size][0] + " "  +comp_defn_name[0].to_s
        
        # Insert face into new component definition
        ents = @comp_defn.entities
# puts "@comp_defn class = " + @comp_defn.class.to_s   

        @face = ents.add_face(@profile_points0)
        @face.reverse!
        # Insert an instance of the component at the origin
        @model.active_entities.add_instance(@comp_defn, @tf_identity)
#puts "@face.vertices = " + @face.vertices.inspect.to_s

				@last_drawn = [@comp_defn]
        # Orient face normal to @long_axis and correctly oriented
				@comp_defn.instances[-1].transform!(@tf3)
        @comp_defn.instances[-1].transform!(@tf4)
				@comp_defn.instances[-1].transform!(@tf6)
        
        # Move inserted component face from origin to pick point
				@comp_defn.instances[-1].transform!(@tf2)			 
				@model.selection.clear
				@model.selection.add @face 
				@face.reverse!
      # Operation cancelled 
			else
				@model.abort_operation # alternative way to cancel
				view.refresh  
				self.reset(view)

			end # if comp_name
		end # if @state < 2    
# ------------------------
      if @state == 3 
      # Pushpull cross-section to length
#puts "create_geometry called state 3"
        if @face.normal == @long_axis
          @face.pushpull @frame_length 
        else # reverse direction to pushpull
          @face.pushpull -@frame_length
        end
#puts "@comp_defn.instances[-1] = " + @comp_defn.instances[0].to_s
        @comp_defn.name = @profile[0] + " " + @n_size[@chosen_size][0] + " x " + @frame_length.to_l.to_s
        self.reset(view)
        @model.commit_operation
      end # if @state == 3

  end # create_geometry
  
#------------------
  def suspend(view)
    puts "suspend called"
    # Sketchup.send_action( 'selectPushPullTool:' )
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
  menu.add_item(@profile[0]) {} # Displays type of timber (only PAR implemented so far)
	menu.add_item("Timber size (nominal)") {} 
	menu.add_separator
	@n_size[0..11].each_index {|i|
			item = menu.add_item(@n_size[i][0]) {@chosen_size = i; @cursor_text = "\n\n" + @n_size[i][0];
      self.activate}
      menu.set_validation_proc(item) {if i==@chosen_size then MF_CHECKED; else MF_UNCHECKED; end;}}
  menu.add_separator
  menu.add_item("Custom size (actual)") {} 
  menu.add_separator
	item = menu.add_item(@n_size[12][0]) {@chosen_size = 12; @cursor_text = "\n\n" + @n_size[12][0];
  self.activate}
  menu.set_validation_proc(item) {if 12==@chosen_size then MF_CHECKED; else MF_UNCHECKED; end;}
 end
 
#------------------
# Set up some standard transformations for later use
  def rotateX90(point)
    # Rotation transformation about point, 90 degrees around X_AXIS direction
    Geom::Transformation.rotation point, X_AXIS, 90.degrees
  end

  def rotateY90(point)
    # Rotation transformation about point, 90 degrees around Y_AXIS direction
    Geom::Transformation.rotation point, Y_AXIS, 90.degrees
  end
  
  def rotateZ90(point)
    # Rotation transformation about point, 90 degrees around Z_AXIS direction
    Geom::Transformation.rotation point, Z_AXIS, 90.degrees
  end

  def rotateXminus90(point)
    # Rotation transformation about point, 90 degrees around X_AXIS direction
    Geom::Transformation.rotation point, X_AXIS, -90.degrees
  end

  def rotateYminus90(point)
    # Rotation transformation about point, 90 degrees around Y_AXIS direction
    Geom::Transformation.rotation point, Y_AXIS, -90.degrees
  end
  
  def rotateZminus90(point)
    # Rotation transformation about point, 90 degrees around Z_AXIS direction
    Geom::Transformation.rotation point, Z_AXIS, -90.degrees
  end
  
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

  def swap_xy(arry)
   ## swap x and y coordinates in array 'arry'
# puts "Array starts as = " + arry.inspect.to_s + " of length = " + arry.length.to_s
    temp = arry.dup
    i=0
    arry.each_index { |i|
      temp0 = arry[i][0]
      temp1 = arry[i][1]
      temp[i][0] = temp1
      temp[i][1] = temp0}
# puts "Returning temp = " + temp.inspect.to_s
    return temp
  end 
end # class DrawFraming

end # module JWM
class Geom::Transformation
  def to_matrix
    a = self.to_a
    f = "%8.3f"
    l = [f, f, f, f].join("  ") + "\n"
    str =  sprintf l,  a[0], a[1], a[2], a[3]
    str += sprintf l,  a[4], a[5], a[6], a[7]
    str += sprintf l,  a[8], a[9], a[10], a[11]
    str += sprintf l,  a[12], a[13], a[14], a[15]
    str 
  end
end

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