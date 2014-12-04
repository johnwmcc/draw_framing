# draw_framing_ext.rb  
# Author: John McClenahan <john@mcclenahans.co.uk>  
# Adapted from CLineTool by Jim Foltz
 
# Copyright 2014 John McClenahan
# License: The MIT License (MIT)
#
# A SketchUp Ruby Extension that draws timber framing in standard (UK) softwood sizes, and custom sizes.  More info at
# https://github.com/johnmcc/draw_framing


require "sketchup.rb"
require "extensions.rb"

module JWM
  # module DrawFraming

    # Create the extension.
    loader = File.join(File.dirname(__FILE__), "jwm_draw_framing", "draw_framing.rb")
    extension = SketchupExtension.new("Draw Framing Tool", loader)
    extension.description = "Draw Framing"
    extension.version     = "0.6"
    extension.creator     = "John McClenahan"
    extension.copyright   = "2014, John W McClenahan"

    # Register the extension with so it will show up in the Preference panel.
    Sketchup.register_extension(extension, true)

  #end # module JWMDrawFraming
end # module JWM



