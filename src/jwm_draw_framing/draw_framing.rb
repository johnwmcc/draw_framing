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

## To FIX before going further:
## error when first pick is not on a face - one of the vectors and/or transforms is not initialised properly. FIXED
## face angle is wrong if you pick on a back face - reverts to Z_AXIS. WRONG: it was seeing a transparent horizontal face in front
## draw_geometry should 'pin' the drawn geometry at the first pick point, then use mouse move 
##  to then orient cross section before create_geometry is called on second pick or (after dragging) 
## onLButtonUp
## On the second click or onMouseUp create_geometry is called, but doesn't do anything yet 
##  and doesn't redraw the view.

require "sketchup.rb"

# Wrap everything in a module to create a unique namespace
module JWM

class DrawFraming
#------------------
  puts "****************************"
  puts "draw_framing.rb v0.6.0.7 loaded"
  
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
    # Default initially to (blue) z-axis for long dimension of timber
    #   to avoid problems if first pick is not on a face and no axis 
    #   has been specified by arrow key
    
    @@axis_lock = Z_AXIS

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
    @vec5 = Geom::Vector3d.new 0,1,0 
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
    # @long_axis = Geom::Vector3d.new 0,0,0
    

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
    @drawn      = false
    @last_drawn = nil
    Sketchup::set_status_text("Pick first corner for timber profile", SB_PROMPT)
    # Get profile of default or last selected size
    
    @profile = profile "PAR", @chosen_size # Select profile according to profile name and size
# puts @profile[0,2].inspect
    @cursor_text = "\n\n" + @profile[1] # Display chosen size at cursor
    # Select profile array elements from 2 to last (-1), omitting 
    #   profile name in profile[0] and size label in profile[1]
    @points = @profile[2..-1]
# puts "Profile points = " + @points.inspect.to_s 
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
# puts "Mouse move called @state = " + @state.to_s
        # We are get ting the first end of the line.  Call the pick method
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
        when 1
			# Getting the second pick point which defines the orientation of the timber cross-section
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

      when 2
 # puts "Mouse move called @state = " + @state.to_s
    end
  end # onMouseMove
  
#------------------
  def onLButtonDown flags, x, y, view
    puts "onLbuttonDown called"

		# When the user clicks the first time (@state changes from 0 to 1), we switch to getting the
		# second point.	When they click a second time we show the planned cross-section
		case @state
    when 0
			@ip1.pick view, x, y
				if( @ip1.valid? )
          # call the transformation method to get the component/group instance Transformation vector
          # from origin to first pick point
          @first_pick = @ip1
          @tf = @first_pick.transformation
 # puts "@tf = " + @tf.inspect.to_s
          @state = 1
          txt = "Select plane of cross section using cursor (arrow) keys - red = Right, green = Left, blue = up or down "
          Sketchup::set_status_text(txt, SB_PROMPT)
          # Create new transformation objects (the identity transformation by default) for later use
          # or recalculated below if a point on a face was picked 
          @tf3 = Geom::Transformation.new
          @tf4 = Geom::Transformation.new
          @tf5 = Geom::Transformation.new
          ## Detect if pick point is on a face, and if so, orient long axis normal to it
          if @ip.face 
            f = @ip.face
# puts "@ip.face = " + @ip.face.inspect.to_s
# puts  "Face picked: normal is \n"
# puts f.normal.inspect
           @@axis_lock= f.normal

            # Calculate vector which is the projection of the face normal onto the rg plane
            vec3 = Geom::Vector3d.new [f.normal.x, f.normal.y, 0]
            if f.normal.y < 0.0
              rotate3 = -(X_AXIS.angle_between vec3)
            else
              rotate3 = X_AXIS.angle_between vec3 
            end #f.normal.y
  puts "rotate3 angle = " + rotate3.radians.to_s
            
            # Set up transform to rotate the cross-section by this amount around Z_AXIS at world or component origin 
            @tf3 = Geom::Transformation.rotation [0,0,0], Z_AXIS, rotate3
            
            # Calculate angle between face normal and the Z_AXIS
  puts "f.normal = " + f.normal.inspect.to_s            
            rotate4 = f.normal.angle_between Z_AXIS
  puts "rotate4 angle = " + rotate4.radians.to_s 
            
            # Calculate the vector corresponding to the rotation axis for the second transformation,
            # at rotate5 from the X_AXIS, which is at right angles to vec3 and in the rg plane
            # rotate5 = (rotate3 + 90.degrees)
            # @vec5 = Geom::Vector3d.new Math.cos(rotate5), Math.sin(rotate5),0.0
            
            # Calculate the rotation axis for the second transformation as the normal 
            #   to the Z_AXIS/face normal plane, which is the cross-product of the 
            #   face normal and the Z_AXIS vectors
            if f.normal != Z_AXIS && f.normal != Z_AXIS.clone.reverse!
              @vec5 = Z_AXIS.cross f.normal
            else
              @vec5 = Y_AXIS
            end # if f.normal
   puts "@vec5 = " + @vec5.inspect.to_s
            @tf4 = Geom::Transformation.rotation [0,0,0], @vec5, rotate4
          else # no face at pick point
            # Default axis lock to Z_AXIS if no lock set
            if @@axis_lock == [0,0,0]
              @@axis_lock= Z_AXIS
              # When no face picked define @vec5 to avoid startup error
              @vec5 = Y_AXIS

            end




          end # if @ip.face
          # Combine the transformations @tf3 and @tf4 if they exist, otherwise leave @tf5 
          # as identity transform
          if @tf3 && @tf4
            @tf5 = @tf4 * @tf3
          end
				else
					# txt << "on."
					# txt << "TAB = stipple."
					Sketchup::set_status_text(txt, SB_PROMPT)
					@xdown = x
					@ydown = y
        end #if @ip1.valid?
		when 1
		# create the cross-section on the second click
			if( @ip2.valid? )
				self.create_geometry(@ip1.position, @ip2.position, view)
				self.reset(view)
			end # if
    when 2
      puts "@state = 2"
    else
      puts "@state not a valid value"
		end #case
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
				self.reset(view)
			end
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
##    puts "onKeyDown called"
  # Check for Arrow keys to toggle axis lock
    case  key 
    when VK_RIGHT # Right arrow key pressed: toggle red axis lock on/off
      if @@axis_lock == X_AXIS then # Red axis lock was on: turn all axis locks off
        @@axis_lock = Geom::Vector3d.new 0,0,0
        @cursor_text = "\n\n" + @profile[1]
      else
        @@axis_lock = X_AXIS # turn red axis lock on
        @cursor_text = "\n\n" + @profile[1] + "\nX locked"
      end
    when VK_LEFT # Left arrow key pressed: toggle green axis lock on/off
      if @@axis_lock == Y_AXIS then # Y-axis lock was on: turn all axis locks off
        @@axis_lock = Geom::Vector3d.new 0,0,0
        @cursor_text = "\n\n" + @profile[1]
      else
      
       @@axis_lock = Y_AXIS # turn green axis lock on
       @cursor_text = "\n\n" + @profile[1] + "\nY locked"
      end
    when VK_UP # Up  arrow key pressed: toggle blue axis lock on/off
      if @@axis_lock == Z_AXIS then # Axis lock was on: turn all axis locks off
        @@axis_lock = Geom::Vector3d.new 0,0,0
        @cursor_text = "\n\n" + @profile[1]
      else
        @@axis_lock = Z_AXIS # turn blue axis lock on
        @cursor_text = "\n\n" + @profile[1] + "\nZ locked"
      end
    when VK_DOWN  # Down arrow key pressed: toggle blue axis lock on/off
      if @@axis_lock == Z_AXIS then # Axis lock was on: turn all axis locks off
        @@axis_lock = Geom::Vector3d.new 0,0,0
      else
        @@axis_lock = Z_AXIS # turn blue axis lock on
        @cursor_text = "\n\n" + @profile[1] + "\nZ locked"
      end
    end
#     puts"Selected axis = " + @@axis_lock.inspect.to_s


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
#    puts "draw_geometry called"
    # Draw timber profile (by default around the Z_AXIS in the rg plane)
    # Relocate drawn cross section to pick point location

   
    # Declare arrays to hold timber profile points
		@profile_points = []
    @profile_points1 = []
    @profile_points0 = @profile[2..-1]
# puts "Profile points = " + @profile_points.inspect.to_s
    # Vector from component or world origin 
    origin = @tf.origin
# puts "origin = " + origin.inspect.to_s
    vec = origin.vector_to(pt1) # Vector from there to pick point
# puts "vec = " + vec.inspect.to_s
    # Calculate transformation from component or world origin to first pick point
    @tf2 = translate(@tf,vec) # Uses Martin Rinehart's translate function included below
# puts "@tf2 = " + @tf2.inspect.to_s    
    # Rotate about Z_AXIS at origin so as to be parallel in the x-y (rg) plane to the face normal.
    @profile_points0.each_index {|i| @profile_points1[i] = @profile_points0[i].transform(@tf3)} 
 
 # The profile needs to be revolved about the line 
    #  which is normal to the Z_AZIS AND to the face.normal if on a face, 
    #  unless the face.normal or @@axis_lock IS the Z_AXIS, in which case no revolution needed.
    # And to get the normal, we took the cross-product of 
    #  the Z_AZIS and the face.normal in onLButtonDown.

		@profile_points1.each_index {|i| @profile_points[i] = @profile_points1[i].transform(@tf4)} 

    # Relocate profile to first pick point (transform @tf2) 
    @profile_points.each_index {|i| @profile_points[i] = @profile_points[i].transform(@tf2)}     



 
#	puts "@profile_points[] = \n" + @profile_points.to_a.inspect

    
    # Set direction of long axis of wood (normal to plane of cross-section)

      @long_axis =  @@axis_lock
      # newlen = @long_axis.length = 4.0
# puts "Long axis = " + @long_axis.inspect.to_s  + " length = " + @long_axis.length  
      # Display long axis as visual feedback
      #@long_axis.transform!(@tf2)
      view.line_width = 2; view.line_stipple = ""
      view.set_color_from_line(pt1 - @long_axis, pt1 + @long_axis)
      view.draw_line(pt1 - @long_axis, pt1 + @long_axis) # to show direction of long axis of wood  
      

      # end
      # Draw normal to Z_AXIS/face.normal in orange
# puts "@vec5.to_a = " + @vec5.inspect.to_s, @vec5.to_a.to_s
      pt3 = @vec5.to_a.transform @tf2
      view.drawing_color = "orange" 
      view.draw_line(pt1,pt3)
      
      view.drawing_color = "magenta" 
      view.draw_polyline(@profile_points)
end    

  
#------------------
## Create geometry for the cross-section in the model
  def create_geometry(p1, p2, view)
    puts "create_geometry called"
    @state = 2
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