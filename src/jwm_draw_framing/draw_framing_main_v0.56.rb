## C:/r/draw_framing/draw_framing_main.rb
## Name: Draw Framing Tool
## Sketchup Extension plugin
## Tool to help draw Timber Frames using standard (UK) softwood timber sizes
## Author John McClenahan
## Date May 2012ff
## Adapted from CLineTool.rb by Jim Foltz
##   which in turn is adapted from
# LineTool Copyright 2005-2007, Google, Inc.

# The software (linetool.rb) was provided as an example of using the Ruby interface
# to SketchUp.

# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


## v0.56 2014-11-25 10:15 AM
## Orient long axis vector parallel to face.normal 
##   if first pick is on an orthogonal face

## v0.55 - started on 2014-11-24
## Implemented keyboard choice of axis (using standard SU keys) to toggle axis constraint on/off:
##   red = Right Arrow, blue = Up or Down Arrow, green = Left Arrow
## and constrained mouse moves to orientation around selected axis
## Attempting to:
## Implement keyboard choice of orientation of cross section of timber, 
##   using Tab key to cycle through options - postponed this one

## v0.54 2014-17-04
## Moved sub-menu from Plugins to Draw, and renamed it Timber Frame
## Added standard size 5" x 1" or 125mm x 25mm and moved Custom size index from 11 to 12 accordingly
## Changed custom default size to 1/2" x 3/4" or 12.5mm x 19mm
## Changed custom size to mean actual not nominal size, since all usual standard sizes are now covered

## v0.53 2012-12-13
## Clean up redundant comments, and more redundant code from original clinetool
## Slightly amend face creation code to draw face at origin, then move it to pick point, so the 
## resulting component will have its axes at a corner of the first face drawn.
## Start trying to embody the pushpull length creation into the tool, not leave it as a separate operation 

## v0.52 2012-12-10
## Changed menu to read @n_size array directly instead of setting @c_menu
## Finally fixed errors resulting from cancelling Custom size data entry 
## - put in a test to check that 'results' are not nil before reading width and depth variables

## v0.51 2012-12-08
## Added choice of imperial or metric units, depending on model units
## Still has some errors using Custom sizes but mostly works ok

## v0.5 2012-12-08
## Changed custom size input box to expect a Length value, not a Float, 
##  and set standard imperial sizes to lengths as well
## Fixed the effect of Cancelling entry into Custom Size inputbox - now cleans up properly
## Chosen custom size now shows 'Custom ' before size 

## v0.493 2012-12-06
## Changed draw_geometry colours for long axis of component to show red, green or blue
## depending on orientation of principal axis

## v0.492 2012-12-06
## Removed some leftovers from cline_tool original code no longer relevant

## v0.491 2012-12-05
## Starting to remove leftovers from cline_tool original code no longer relevant

## v0.49 2012-12-05
## Tidying up bugs in remembering custom sizes, and in initiating standard nominal sizes
## v0.481 2012-12-05
## Fixed several bugs in setting Custom R-click menu, drawing Custom size timber; moved some startup settings to Initialize section instead of Activate section
 

#-----------------------------------------------------------------------------

require 'sketchup.rb'
	
module JWM
	class DrawFraming
	## Initialise variables to hold current size in use
	## Values set on first loading
	puts "******************************"
	puts "Class DrawFraming v0.56 loaded"
  # Declare array to hold current nominal sizes as lengths
		@@size_index = 1
		@@nom_size = [0.0.to_l,0.0.to_l] 
  # Declare array to hold last defined custom size
		@@custom_size = ["Custom default",0.0.to_l,0.0.to_l]
  # Declare variables for later use
		@@PushPullToolID = 21041
		@@suspended = false
    
  # Establish array to store axis toggle state
  # Axis_lock 0, 1, 2 for red, green, blue; false = unlocked; true = lock
    @@axis_lock = Array.new(3)
    # Default to (red) axis for long dimension of timber
    @@axis_lock = X_AXIS
    # puts@@axis_lock.inspect.to_s
#------------------------------
## 	Initialize is run each time the tool is selected
	def initialize

	# Get model units (imperial or metric)
		model = Sketchup.active_model
		manager = model.options
		if provider = manager['UnitsOptions'] # Check for nil value
			@@length_unit = provider['LengthUnit']
		else 
			UI.messagebox " Can't determine model units - please set them in Window/ModelInfo"
		end # if	

		## Set standard timber sizes in imperial or metric units
			case @@length_unit
				when 0..1 # Units are imperial (inches or feet)
				## Define standard imperial nominal timber sizes
					@n_size=[]
					@n_size[0]=['1" x 1"',1.0.inch,1.0.inch]
					@n_size[1]=['2" x 1"',2.0.inch,1.0.inch]
					@n_size[2]=['3" x 1"',3.0.inch,1.0.inch]
					@n_size[3]=['4" x 1"',4.0.inch,1.0.inch]
					@n_size[4]=['5" x 1"',5.0.inch,1.0.inch]
          @n_size[5]=['6" x 1"',6.0.inch,1.0.inch]
					@n_size[6]=['2" x 2"',2.0.inch,2.0.inch]
					@n_size[7]=['3" x 2"',3.0.inch,2.0.inch]
					@n_size[8]=['4" x 2"',4.0.inch,2.0.inch]
					@n_size[9]=['6" x 2"',6.0.inch,2.0.inch]
					@n_size[10]=['3" x 3"',3.0.inch,3.0.inch]
					@n_size[11]=['4" x 4"',4.0.inch,4.0.inch]		

					if @@custom_size[1] == 0.0 # if custom size hasn't been set, put in a default size 
						@@custom_size = ['Custom default 1/2" x 3/4"',0.5.inch,0.75.inch]
					end

					when 2..4 # Units are metric (mm, cm, or metres)
				## Define standard metric nominal timber sizes
					@n_size=[]
					@n_size[0]=['25 x 25 mm',25.0.mm, 25.0.mm]
					@n_size[1]=['50 x 25 mm',50.0.mm, 25.0.mm]
					@n_size[2]=['75 x 25 mm',75.0.mm, 25.0.mm]
					@n_size[3]=['100 x 25 mm',100.0.mm, 25.0.mm]
					@n_size[4]=['125 x 25 mm',150.0.mm, 25.0.mm]
					@n_size[5]=['150 x 25 mm',150.0.mm, 25.0.mm]
          @n_size[6]=['50 x 50 mm',50.0.mm, 50.0.mm]
					@n_size[7]=['75 x 50 mm',75.0.mm, 50.0.mm]
					@n_size[8]=['100 x 50 mm',100.0.mm, 50.0.mm]
					@n_size[9]=['150 x 50 mm',150.0.mm, 50.0.mm]
					@n_size[10]=['75 x 75 mm',75.0.mm, 75.0.mm]
					@n_size[11]=['100 x 100 mm',100.0.mm, 100.0.mm]

					if @@custom_size[1] == 0.0	# if custom size hasn't been set, put in a default size 
						@@custom_size = ["Custom default 13mm x 19mm ",13.mm,19.mm] 
					end 
				else # Something else 
					UI.messagebox "Model units are not defined"
			end # case
		# Set custom size in either imperial or metric units
		@n_size[12] = @@custom_size	

		# This is the standard Ruby initialize method that is called when you create
		# a new Tool object.
		@ip1 = nil
		@ip2 = nil
		@xdown = 0
		@ydown = 0

		c = File.join(File.dirname(__FILE__), "framing_cursor.png")
		ltcursor = UI::create_cursor(c, 3, 1)
		c = File.join(File.dirname(__FILE__), "framing_cursor.png")
		ltcursor_p = UI::create_cursor(c, 3, 1)
		c = File.join(File.dirname(__FILE__), "framing_cursor.png")
		ltcursor_i = UI::create_cursor(c, 3, 1)
		@cursors = [ltcursor, ltcursor_p, ltcursor_i]
		@opts = {}
		load_opts()
    
	end # initialize method
#-------------------------------
	def onSetCursor
		UI.set_cursor(@cursors[@opts['mode']]) 
		#Sketchup.active_model.active_view.refresh
	end
#--------------------------------
	## The activate method is called by SketchUp when the tool is first selected, or when R-click menu is called
	## it is a good place to put most of your initialization
	def activate
		# Resume if previously suspended
		if @@suspended
			self.resume(nil )
		end
		# set custom size to default or that used last
		
		@n_size[12] = @@custom_size

		# Set default timber size to 2" x 1" or 50 x 25mm (@chosen_size index = 1) if no size is set
			if !@chosen_size 
				@chosen_size = @@size_index # Size index was initialized to 1, or gets set later to be remembered here
			end

	## Set chosen size to display below cursor
		s_label = @n_size[@chosen_size]
		@cursor_text = "\n\n" + @n_size[@chosen_size][0]
		# Update remembered timber size			
			@@size_index = @chosen_size 
			
		## Build context menu array to display on R-click, to select timber size
		if @chosen_size >= 12 # Then pop up a menu to set Custom Size(s)
			prompts = "Width", "Depth"
			values = [@@custom_size[1],@@custom_size[2 ]]
				results = inputbox prompts,	values, "Enter Custom Size (actual)"
			if results #not nil
				width, depth = results
				s_label = "Custom " + width.to_s + ' x ' + depth.to_s
				@n_size[12] = [s_label,width.to_l ,depth.to_l ]
				# @c_menu[11] = [@n_size[11][0],11]			
			end 
		end

		## Remember size(s) last chosen
		@@nom_size[0] = @n_size[@chosen_size][1].to_l  
	  @@nom_size[1] = @n_size[@chosen_size][2].to_l
		@@custom_size = @n_size[12]
	
	## Set actual size in imperial or metric units according to model unit settings
		if @@length_unit <=1 # imperial sizes in use
        ## Convert from nominal to actual size - take 1/4" off nominal if 1" or over, 1/8" off otherwise  
        @@act_size = [0.0.to_l,0.0.to_l]
      if @chosen_size < 12 # for standard sizes only 
        @@act_size.each_index {|i| # Check width and depth dimensions to see how much to reduce nominal size
            if @@nom_size[i]  > 1.0.inch 
              @@act_size[i] = @@nom_size[i] - 0.25.inch
            else 
              # puts "Nominal size for dim = " + i.to_s + " = " + @@nom_size[i].to_s 
              @@act_size[i] = @@nom_size[i] - 0.125.inch
            end
        }
      else
        # use actual (not nominal) dimensions for custom size
        @@act_size[0]=@@custom_size[1]
        @@act_size[1] = @@custom_size[2]
      end

			w = @@act_size[0] 
			d = @@act_size[1]

		else # Metric units in use
			## Convert from nominal to actual size - take 6mm off nominal if 25mm or over, 3mm off otherwise  
			@@act_size = [0.0.to_l,0.0.to_l] #Initialise variable as lengths
			if @chosen_size < 12 # for standard sizes only
        @@act_size.each_index {|i| # Check width and depth dimensions to see how much to reduce nominal size
          if @@nom_size[i] > 25.mm 
            # puts "Nominal size for dim = " + i.to_s + " = " + @@nom_size[i].to_s 
            @@act_size[i] = @@nom_size[i] - 6.mm
          else 
            if @chosen_size < 12
              # puts "Nominal size for dim = " + i.to_s + " = " + @@nom_size[i].to_s 
              @@act_size[i] = @@nom_size[i] - 3.mm
            end
          end
        }
      else
      # use actual custom size (not nominal)
        @@act_size[0]=@@custom_size[1]
        @@act_size[1] = @@custom_size[2]
      end


			w = @@act_size[0] 
			d = @@act_size[1]
			#puts "Nominal size = " + @@nom_size.inspect + "\n"
			#puts "Actual size = " + @@act_size.inspect + "\n"				
		end

		# The Sketchup::InputPoint class is used to get 3D points from screen
		# positions.	It uses the SketchUp inferencing code.
		# In this tool, we will have two points for the endpoints of the line.
		@ip	 = Sketchup::InputPoint.new
		@ip1	= Sketchup::InputPoint.new
		@ip2	= Sketchup::InputPoint.new
		@drawn	= false
		@last_drawn = nil
		@stipple	= ["_",	".",	"-", "-.-"]

		Sketchup::set_status_text("Length", SB_VCB_LABEL)

		# Unhide Construction Geometry (hangover from original Construction Line Tool)
		if Sketchup.active_model.rendering_options["HideConstructionGeometry"] == true 
			Sketchup.active_model.rendering_options["HideConstructionGeometry"] = false 
		end

		self.reset(nil)

	end # method activate
#------------------------------------------
	def resume(view)
		# puts "Resume called:  Suspended = " + @@suspended.to_s 
		@@suspended = false
	txt = "Pick first corner of timber"
		Sketchup.set_status_text(txt, SB_PROMPT)
	end

#------------------------------------------
	# deactivate is called when the tool is deactivated because
	# a different tool was selected
	def deactivate(view)
		view.invalidate if @drawn
		# @@size_index = @chosen_size
		save_opts()
	end
#-----------------------------------------------------------
	# The onMouseMove method is called whenever the user moves the mouse.
	# because it is called so often, it is important to try to make it efficient.
	# In a lot of tools, your main interaction will occur in this method.
	def onMouseMove(flags, x, y, view)
		if( @state == 0 )
		# We are getting the first end of the line.	Call the pick method
		# on the InputPoint to get a 3D position from the 2D screen position
		# that is passed as an argument to this method.

		@ip.pick view, x, y
			if( @ip != @ip1 )
				# if the point has changed from the last one we got, then
				# see if we need to display the point.	We need to display it
				# if it has a display representation or if the previous point
				# was displayed.	The invalidate method on the view is used
				# to tell the view that something has changed so that you need
				# to refresh the view.
				view.invalidate if( @ip.display? or @ip1.display? )
				@ip1.copy! @ip

				# set the tooltip that should be displayed to this point
				view.tooltip = @ip1.tooltip
		## Display cursor text to show size being drawn now
		view.draw_text view.screen_coords(@ip1), @cursor_text # Give feedback at cursor
			end
		elsif @state == 1
			
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
		elsif @state == 2 # Waiting for third pick to define length of component

		# puts "In onMouseMove method @state == 2" 

			@ip.pick view, x, y
			if( @ip != @ip1 )
				# if the point has changed from the first one we got, then
				# see if we need to display the point.	We need to display it
				# if it has a display representation or if the previous point
				# was displayed.	The invalidate method on the view is used
				# to tell the view that something has changed so that you need
				# to refresh the view.
				view.invalidate if( @ip.display? or @ip1.display? )
				@ip1.copy! @ip

				# set the tooltip that should be displayed to this point
				view.tooltip = @ip1.tooltip
			end
		end
	end #def onMouseMove
#-------------------------------
	# The onLButtonDOwn method is called when the user presses the left mouse button.
	def onLButtonDown(flags, x, y, view)
		# When the user clicks the first time, we switch to getting the
		# second point.	When they click a second time we show the planned cross-section
		if( @state == 0 )
			@ip1.pick view, x, y
				if( @ip1.valid? )
            ## Detect if pick point is on a face, and if so, orient long axis normal to it
          if @ip.face
            f = @ip.face
            #UI.messagebox 
            # puts"Face picked: normal is " + f.normal.inspect.to_s
            if f.normal == X_AXIS || f.normal == X_AXIS.reverse
            @@axis_lock= X_AXIS
              # puts@@axis_lock.inspect.to_s
            end

            if f.normal == Y_AXIS || f.normal == Y_AXIS.reverse
            @@axis_lock= Y_AXIS
              # puts@@axis_lock.inspect.to_s
            end

            if f.normal == Z_AXIS || f.normal == Z_AXIS.reverse
            @@axis_lock= Z_AXIS
              # puts@@axis_lock.inspect.to_s
            end
          end
						# call the transformation method to get the component/group instance Transformation vector
						@tf = @ip1.transformation
						@state = 1
						txt = "Select plane of cross section using cursor (arrow) keys - red = Right, green = Left, blue = up or down "
						Sketchup::set_status_text(txt, SB_PROMPT)

						# if @opts['mode']==1#@draw_cpoints
								# txt << "off."
						# else
								# txt << "on."
						# end
				else
					# txt << "on."
					# txt << "TAB = stipple."
					Sketchup::set_status_text(txt, SB_PROMPT)
					@xdown = x
					@ydown = y
				end
		else @state = 1
		# create the cross-section on the second click
			if( @ip2.valid? )
				self.create_geometry(@ip1.position, @ip2.position, view)
				self.reset(view)
			end
		end

		# Clear any inference lock
		view.lock_inference
	end #onLButtonDown

	# The onLButtonUp method is called when the user releases the left mouse button.
	def onLButtonUp(flags, x, y, view)
		# If we are doing a drag, then create the cross-section on the mouse up event
		if @state == 1
			if( @dragging && @ip2.valid? )
				self.create_geometry(@ip1.position, @ip2.position,view)
				self.reset(view)
			end
# puts "onLButtonUp:  @state = 2 set \nactive_tool_id ="
# puts @@df_tool_id.to_s
		elsif @state == 2 ## waiting for third click to define length of timber to draw

		end
	end
		
	def onRButtonDown
		getMenu()
	end
	
	# onKeyDown is called when the user presses a key on the keyboard.
	# We are checking it here to see if the user pressed an arrow key to toggle axis lock on/off 
	# so that we can do inference locking
	def onKeyDown(key, repeat, flags, view)
		

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
     # puts"Selected axis = " + @@axis_lock.inspect.to_s
  
  
  # Check for Tab key to cycle through orientation of cross section
		if key == 9 # 9 = Tab 
			# if n < 5
        # n = n + 1
      # else 
        # n=0
      # end
			# view.invalidate
		end
    
    
		if( key == CONSTRAIN_MODIFIER_KEY && repeat == 1 )
			@shift_down_time = Time.now

			# if we already have an inference lock, then unlock it
			if( view.inference_locked? )
				# calling lock_inference with no arguments actually unlocks
				view.lock_inference
			elsif( @state == 0 && @ip1.valid? )
				view.lock_inference @ip1
				view.line_width = 3
			elsif( @state == 1 && @ip2.valid? )
				view.lock_inference @ip2, @ip1
				view.line_width = 3
			end
		end
		if( key == COPY_MODIFIER_KEY )
		
		###Leftovers from cline_tool
		#@draw_cpoints = !@draw_cpoints
		#inc_mode()
		if @state == 0
			txt = "Select start point"
		else
			txt = "Move cursor to set orientation; use arrow keys to toggle axis lock"
		end
		# if @opts['mode'] == 1# @draw_cpoints
			 # txt << "off."
		# else
			 # txt << "on."
		# end
		#Sketchup::set_status_text(txt, SB_PROMPT)
		end
		view.refresh
		self.onSetCursor() # forces change of cursor on screen
		# onSetCursor
		# need to do something after onSetCursor
		false # TT - The culprit is onSetCursor when it's called last in onKey or onLButton events. 
	end

	# def inc_mode ## Left over from cline_tool
		 # @opts['mode'] += 1
		 # if @opts['mode'] > 2
			# @opts['mode'] = 0
		 # end
	#end
#---------------------------
	# onKeyUp is called when the user releases the key
	# We use this to unlock the inference
	# If the user holds down the shift key for more than 1/2 second, then we
	# unlock the inference on the release.	Otherwise, the user presses shift
	# once to lock and a second time to unlock.
	def onKeyUp(key, repeat, flags, view)
		if( key == CONSTRAIN_MODIFIER_KEY && view.inference_locked? && (Time.now - @shift_down_time) > 0.5 )
		view.lock_inference
		end
		#onSetCursor # trigger change of cursor on screen
	end
#----------------------------
	# onUserText is called when the user enters something into the VCB
	# In this implementation, we create a line of the entered length if
	# the user types a length while selecting the second point
	def onUserText(text, view)
		# We only accept input when the state is 1 (i.e. getting the second point)
		# This could be enhanced to also modify the last line created if a length
		# is entered after creating a line.
		#return if not @state == 1
		#return if not @ip2.valid?
		#p @ip2.valid?

		# The user may type in something that we can't parse as a length
		# so we set up some exception handling to trap that
		begin
		value = text.to_l
		rescue
		# Error parsing the text
		UI.beep
		UI.messagebox "Cannot convert #{text} to a Length"
		value = nil
		Sketchup::set_status_text "", SB_VCB_VALUE
		end
		return if !value

		if @state == 1 and @ip2.valid?
		# Compute the direction and the second point
		pt1 = @ip1.position
		vec = @ip2.position - pt1
		if( vec.length == 0.0 )
			UI.beep
			return
		end
		vec.length = value
		pt2 = pt1 + vec

		# Create a line
		self.create_geometry(pt1, pt2, view)
		self.reset(view)
		end
		if @last_drawn and @state == 0
		pt1 = @last_drawn[0].start
		vec = @last_drawn[0].end - @last_drawn[0].start
		vec.length = value
		pt2 = pt1 + vec
		view.model.active_entities.erase_entities @last_drawn
		#@last_drawn = nil
		self.create_geometry(pt1, pt2, view)
		self.reset view
		end
	end #onUserText
#------------------
	# The draw method is called whenever the view is refreshed.	It lets the
	# tool draw any temporary geometry that it needs to.
	def draw(view)
	#puts "draw(view) called"
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
			##view.line_stipple = @opts['stipple']
			view.set_color_from_line(@ip1, @ip2)
			self.draw_geometry(@ip1.position, @ip2.position, view)
			@drawn = true
		end
		end
	end #draw(view)
#-----------------------
	# onCancel  is called when the user hits the escape key
	def onCancel(flag, view)
		self.reset(view)
	end
#-----------------------

	# The following methods are not directly called from SketchUp.	They are
	# internal methods that are used to support the other methods in this class.

	# Reset the tool back to its initial state
	def reset(view)
		# This variable keeps track of which point we are currently getting
		@state = 0
		
		# Display a prompt on the status bar
		txt = "Select first corner of timber to draw "
		# if @opts['mode'] == 1#@draw_cpoints
		# txt << "off."
		# else
		# txt << "on."
		# end
		##txt << "TAB = stipple."
		Sketchup::set_status_text(txt, SB_PROMPT)

		# clear the InputPoints
		@ip1.clear
		@ip2.clear
		@ip.clear

		if( view )
			view.tooltip = nil
			view.invalidate if @drawn
		end

		@drawn = false
		@dragging = false
	end
#---------------------------------------------
	# Create new geometry when the user has selected two points.
	def create_geometry(p1, p2, view)
		if @state < 2 #then we haven't yet created any geometry, so create the cross-section face
			@model = Sketchup.active_model
			# Watch for tool change - when PushPull tool called suspend DrawFraming, and resume when 
			# PushPull tool finished
			@model.tools.add_observer(MyToolsObserver.new)
			@model.start_operation("DrawFraming")
			@@df_tool_id = @model.tools.active_tool_id # Remember DrawFraming tool_id
			# Create an empty group to draw into
			@grp = @model.active_entities.add_group()
			@ents = @grp.entities
			# Draw cross-section at origin (so the component axes will be at the corner of the face),
			# name it, and make it into a component
      
			@face = @ents.add_face(@pts0)

			comp_name = UI.inputbox ["Component name"],["Frame element"],"Name this component instance" 
			if comp_name # isn't nil (naming inputbox not cancelled)
				@grp.description= comp_name[0].to_s 
				@comp = @grp.to_component
				@comp.definition().name = @n_size[@chosen_size][0] + " "  + comp_name[0].to_s
				# Move face from origin to pick point
				@comp.transform!(@tf2 )

				@last_drawn = [@comp]
			 
				@model.selection.clear
				@model.selection.add @face
				@face.reverse!
				@state = 2 # Waiting for pick or VCB entry to define length of component
				@model.commit_operation
			else
				# Clean up drawn face and edges, and reset view
				 @ents.clear!
				#@model.abort_operation # alternative way to cancel
				view.refresh  
				self.reset(view)
				@state = 0
			end # if comp_name
				# Pushpull cross-section to length
				self.suspend(view) # Suspend this tool, and select PushPullTool instead in suspend method 
		end # if
	end
#------------------
def suspend(view)
# Don't suspend this tool if Zoom is used
  # if MyToolsObserver::tool_name.to_s != "CameraZoomTool"
    @@suspended = true
    Sketchup.send_action( 'selectPushPullTool:' )
  # end
end
#------------------
 
## Draw the geometry 
## This section of code feeds back to the user the size and orientation of the face that will be created to 
## start drawing a piece of timber. 
## The first pick point defines the location of a corner of the timber.
## Press a cursor (arrow) key to lock the long axis direction 
## Moving the cursor around the first pick point changes the orientation 
## of the cross-section face.
## Clicking the second pick point fixes the axis and orientation of the face to be drawn, 
## draws a face at the origin, then transforms it to move it to the first pick point, 
## ready for a pushpull operation to create the desired length

	def draw_geometry(pt1, pt2, view)
  # Set local variables to actual width and depth of wood cross-section
	w = @@act_size[0] # Width of wood
	d = @@act_size[1] # Depth of wood

	# Orient the rectangle for wood cross section according to (initially only orthogonal) plane of
  #   pt1 - pt2, which are first pick point, and current mouse (inferred) position, respectively
  
	# Set axis labels (red, green, blue) to match index of 3D points
	r = 0; g = 1; b = 2

	# Plane is defined by the direction of its normal
	# Calculate orientation of vec
	rdir = 1.0 # direction positive
	gdir = 1.0
	bdir = 1.0
	
	vec = pt2 - pt1 
	rdir = -1.0 if vec[r]<0 # direction negative
	gdir = -1.0 if vec[g]<0
	bdir = -1.0 if vec[b]<0
	# Set up different orientations of cross-section
	gb = Geom::Point3d.new; rb = Geom::Point3d.new ; rg = Geom::Point3d.new
  gb2 = Geom::Point3d.new; rb2 = Geom::Point3d.new ; rg2 = Geom::Point3d.new
  # gb plane
	gb  = [[0,0,0],[0, w*gdir, 0], [0, w*gdir, d*bdir], [0, 0, d*bdir],[0,0,0]]
  # Reverse width and depth
  gb2 =  [[0,0,0],[0, d*gdir, 0], [0, d*gdir, w*bdir], [0, 0, w*bdir],[0,0,0]]
  # rb plane
	rb  = [[0,0,0],[w*rdir, 0, 0], [w*rdir, 0, d*bdir], [0, 0, d*bdir],[0,0,0]]
  # Reverse width and depth
  rb2 = [[0,0,0],[d*rdir, 0, 0], [d*rdir, 0, w*bdir], [0, 0, w*bdir],[0,0,0]]
  # rg plane
	rg  = [[0,0,0],[w*rdir, 0, 0], [w*rdir, d*gdir, 0], [0, d*gdir, 0],[0,0,0]]
  # Reverse width and depth
  rg2 = [[0,0,0],[d*rdir, 0, 0], [d*rdir, w*gdir, 0], [0, w*gdir, 0],[0,0,0]]
	# Put cross_section into an array of different orientations
	cross_sect = [gb, gb2, rb,rb2, rg]

 	@lAxis = Geom::Vector3d.new #Direction of long axis of wood (normal to plane of cross-section)
	if @@axis_lock == X_AXIS 
		@plane = 'gb'
		text = "\ngb plane"
		n = 0 #normal is in r direction
	if vec[b].abs > vec[g].abs # then swap width and depth dimensions
    n = 1
	# cross_sect[1] = [[0,0,0],[0, d*gdir, 0], [0, d*gdir, w*bdir], [0, 0, w*bdir],[0,0,0]]
	end
	elsif  @@axis_lock == Y_AXIS
		@plane = 'rb'
	  text = "\nrb plane"
	  n = 2 #normal is in g direction
	if vec[b].abs > vec[r].abs # then rotate wood cross section
    n = 3
	# cross_sect[3] = [[0,0,0],[d*rdir, 0, 0], [d*rdir, 0, w*bdir], [0, 0, w*bdir],[0,0,0]]
	end
	elsif @@axis_lock == Z_AXIS
		@plane = 'rg'
	  text = "\nrg plane"
	n = 4 #normal is in b direction
	#puts "b-value = " + vec[b].to_s + " g-value = " + vec[g].to_s
	if vec[g].abs > vec[r].abs # then rotate wood cross section
  n = 5
	# cross_sect[5] = [[0,0,0],[d*rdir, 0, 0], [d*rdir, w*gdir, 0], [0, w*gdir, 0],[0,0,0] ]
	end
	else
		@plane = 'no'
	  text = "\nnon-orthogonal plane"
	end
	###puts "Text set to " + text
	view.draw_text view.  screen_coords(pt2), @cursor_text # Give feedback at cursor
	if @plane != "no" #for orthogonal cases only 
		view.line_width = 2; view.line_stipple = ""
		@lAxis[(n/2).to_int] = d*2.0 # Set long axis direction normal to @plane
		@lAxis.transform!(@tf)
		view.set_color_from_line(pt1 - @lAxis, pt1 + @lAxis)
		view.draw_line(pt1 - @lAxis, pt1 + @lAxis) # to show direction of long axis of wood
		@pts = []; @pts0 = []
		#@pts = [cross_sect[n][0], cross_sect[n][1], cross_sect[n][2], cross_sect[n][3], cross_sect[n][4]]
		cross_sect[n].each_index {|i| @pts0[i] = cross_sect[n][i]}

		# Relocate drawn cross section to pick point location
		# Transform @tf moves to origin of component (if any) that initial click was on
		# Have to move and rotate drawn component from World origin first to component origin, 
		#   then add translation to pick point
		
		# Vector from component or world origin 
		ip = @tf.origin # Component or World origin
		vec = ip.vector_to(pt1) # Vector from there to pick point
		@tf2 = translate(@tf,vec) # Uses Martin Rinehart's translate function included below
		@pts0.each_index {|i| @pts[i] = @pts0[i].transform(@tf2)}
		#puts "@pts0[] = \n" + @pts0.to_a.inspect
		view.drawing_color = "magenta" 
		view.draw_polyline(@pts)
		#@pts.each {|pt| pt.transform!(@tf) } # Transform points into axes of component clicked (?)
		#puts "@pts.transformed![] = \n" + @pts.to_a.inspect
	end #if 

	end #def draw_geometry
#--------------------------
	def load_opts
			#puts "load_opts called 757"
			key = "JWM::DrawFraming"
			opts = Sketchup.read_default(key, 'options')
			@opts ||= {}
			@opts['mode'] = 1
			@opts['stipple'] = '_'
			if opts.is_a? Array
					opts.each {|o|
							k, v = o
							@opts[k] = v
					}
			end
	end	
#--------------------------	
	def save_opts
			key = "JWM::DrawFraming"
			o = @opts.inspect.to_s.gsub(/"/, "'")
			Sketchup.write_default(key, 'options', @opts.to_a)
	end
#--------------------------	
 def getMenu(menu)
	menu.add_item("Timber size (nominal)") { UI.messagebox("Select timber size from context menu") } 
	menu.add_separator
	#puts @n_size.inspect
	#puts @c_menu.inspect
	@n_size.each_index {|i|
			menu.add_item(@n_size[i][0]) {@chosen_size = i; @cursor_text = "\n\n" + @n_size[i][0]; self.activate}}
 end
#--------------------------
 
	def translate( *args ) # add a translation vector to a transformation
=begin
From Martin Rinehart 'Edges to Rubies' chapter 15
May be called with a transformation and a vector, 
or with a transformation and r, g, b values.
=end
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

##---------------------------------------------------------------
# This is an example of an observer that watches tool interactions.
class MyToolsObserver < Sketchup::ToolsObserver
	def onActiveToolChanged(tools, tool_name, tool_id)
		#UI.messagebox(
		#puts "onActiveToolChanged: " +tools.inspect.to_s + " " + tool_id.to_s + " " + tool_name.to_s
	end
	def onToolStateChanged(tools, tool_name, tool_id, tool_state)
		#UI.messagebox(
		# puts "onToolStateChanged: " + tools.inspect.to_s + " " + tool_name.to_s + ": " + tool_state.to_s
	end
end #class MyToolsObserver
#--------------------------------------------------------------
end # module JWM

#-----------------------------------------------------------------------------


unless file_loaded?(__FILE__)
	cmd = UI::Command.new("Timber Frame") {Sketchup.active_model.select_tool(JWM::DrawFraming.new)}
	my_dir	 = File.dirname(File.expand_path(__FILE__))
	cmd.small_icon = File.join(my_dir, "framing_icon_sm.png")
	cmd.large_icon = File.join(my_dir, "framing_icon_lg.png")
	cmd.tooltip	= "Draw Timber Frame"
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
