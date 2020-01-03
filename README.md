dalliclick
==========

Small script to create a partially occluded image series of an input image (named according to a game in a 1970th german game show)

The program creates a "background" image (see -b for your own one) and combines this with the given image in a way, that several output images are created, which show more and more parts of the original image, until the full image is visible.
The program is called dalliklick, because there was a german TV series in the seventies (Dalli dalli), that called this game Dalli Klick.
You will need an ImageMagick version greater than 6.4.3. Get it here, and define the paths to CONVERT_BIN and COMPOSITE_BIN.

Necessary software
------------------

* bash shell
* ImageMagick (Version > 6.4.3): convert and composite http://www.imagemagick.org/

Usage
-----

Use -h to get help:

    dalliklick.sh -h
    This script creates partially occluded image versions of the input image
    Usage: dalliclick.sh <Options> imagefile...
    Options:
    -h             Show this help
    -v             Increase verbosity (more details on actions)
    -n Segments    Number of segments, max. 255 (Default 10)
    -o Name        Output image base name (out -> out_NNN.png)
    -b File        Background (canvas) image. The output images will have exactly
                   the size of the background image.
                   If this is not specified, an artifical background image will be
                   generated.
    -B color       Color for filling up images in wrong ratio (only relevant with -b)
    -m maskimage   User specific mask image with label gray values 1,2,3,...
                   If this is not specified a random mask image will be generated.
    -t             Do not generate temporary directory (working dir is used)
    -O format      Format of output files (Default: png)

  
