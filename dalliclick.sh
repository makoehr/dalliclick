#!/bin/bash

#####################################################################
# Program : dalliklick.sh
#
# Version : 0.1
# Date    : 12/2008
# Author  : Martin Weis
#
# Inputs  : One image that should be "dalli-klicked"
#
# Notes   : The program creates a "background" image (see -b for your own one) 
#           and combines this with the given image in a way, that several output
#           images are created, which show more and more parts of the original image,
#           until the full image is visible.
#           The program is called dalliklick, because there was a german TV series in 
#           the seventies (Dalli dalli), that called this game Dalli Klick.
#           You will need an ImageMagick version greater than 6.4.3. Get it here, and define
#           the paths to CONVERT_BIN and COMPOSITE_BIN:
#           http://www.imagemagick.org/
#           Result images are written to the working directory, if -t is given
#
#####################################################################

# system parameters
# if you have a newer version of convert, define the executable here
#CONVERT_BIN="${HOME}/local/imagemagick-6.4.7-8/bin/convert"
CONVERT_BIN=`which convert`
#COMPOSITE_BIN="${HOME}/local/imagemagick-6.4.7-8/bin/composite"
COMPOSITE_BIN=`which composite`

# Global variables
SCRIPTNAME=$(basename $0)

EXIT_SUCCESS=0
EXIT_FAILURE=1
EXIT_ERROR=2
EXIT_PARAM_ERROR=5
EXIT_BUG=10

# define defaults for option values
# default width and height of the resulting image
#####################
# true = 0, false = 1
#####################
VERBOSE=1
WIDTH=1024
HEIGHT=766
# generate a mask image: 
GENERATE_MASK=0
NUMSEGMENTS=10
RESULTIMAGEBASE_GIVEN=1
OUTPUTFILEFORMAT=png
# do all output operations in a temporary dir? where should this be located?
GENTMPDIR=0
# OUTPUTDIR=`pwd`
# mask image with several gray valued (1,2,3,...) areas
MASKIMAGENAME="tmp_voronoi_template.png"
# black and white image (transparency info)
GRAYMASKDEFAULTFILENAME="tmp_maskimage.png"
# generate a background image?
GENERATE_BACKGROUND=0
BACKGROUNDIMAGENAME="tmp_background.png"

# functions
function usage {
	echo "This script creates partially occluded image versions of the input image"
        echo "Usage: $SCRIPTNAME <options> imagefiles" >&2
	echo "-h (this) help"
	echo "-v print verbose information"
	echo "-n number of segments, max. 255"
	echo "-o output image base name (out -> out_NNN.png)"
	echo "-b background (canvas) image"
	echo "-m maskimage (with label gray values 1,2,3,...)"
	echo "-t do not generate temporary directory (working dir is used)"
	echo "-O format of output files (png)"
        [[ $# -eq 1 ]] && exit $1 || exit $EXIT_FAILURE
}

generate_voronoi_template(){
# check for inputs: width, height, number of segments
	if [ -z $1 ]
	then	
		WID=$WIDTH
	else
		WID="$1"
	fi

	if [ -z $2 ]
	then
		HEI=$HEIGHT
	else
		HEI="$2"
	fi
	if [ -z $3 ]
	then
		NSEG=10
	else
		NSEG="$3"
	fi
	if [ $NSEG -gt 255 ]
	then
		echo "warning: generate_voronoi_template() number of segments greater 255 ($NSEG), setting to 255"
	NSEG=255
	fi
	if [ $VERBOSE -eq 0 ]; then echo "generate_voronoi_template() WID: $WID, HEI: $HEI, NSEG: $NSEG"; fi
	# see http://www.imagemagick.org/Usage/canvas/#voronoi
	CMD="$CONVERT_BIN -size ${WID}x${HEI} "
	CMD="$CMD -colors 256 -colorspace GRAY "
	CMD="$CMD xc:black -sparse-color Voronoi '"
	for i in `seq -w 1 1 $NSEG`
	do 
		# generate random postions within image coordinate range 
		# imagemagick can do this ;-)
		#RANDX=$RANDOM
		#let "RANDX %= $WID"
		#RANDY=$RANDOM
		#let "RANDY %= $HEI"
		#CMD="$CMD $RANDX,$RANDY rgb($i,$i,$i)"
		CMD="$CMD %[fx:rand()*w],%[fx:rand()*h] rgb($i,$i,$i)"
	done
		CMD="$CMD ' $TMPMASKIMAGENAME"
	if [ $VERBOSE -eq 0 ] ; then  echo $CMD; fi
	eval $CMD
	if [ $? -ne 0 ] ; then  echo "could not create maskimage '$TMPMASKIMAGENAME'"; fi
	
}

function dallicleanup(){
    #if [ $VERBOSE -eq 0 ] ; then  echo "cleaning up bg"; fi
    # cleanup *generated* files
    if [ $GENERATE_BACKGROUND -eq 0 ] ; then
      # # remove 'starting' canvas
      if [ -f "$BACKGROUNDIMAGE" ] ; then
	rm "$BACKGROUNDIMAGE"
      fi
    fi
    #if [ $VERBOSE -eq 0 ] ; then  echo "cleaning up mask"; fi
    if [ $GENERATE_MASK -eq 0 ] ; then
      # # remove mask image
      if [ -f "$TMPMASKIMAGENAME" ] ; then
	rm "$TMPMASKIMAGENAME"
      fi
    fi
    if [ -f "$GRAYMASKFILE" ] ; then
      rm "$GRAYMASKFILE"
    fi
    # cleanup the temporary directory, if that was created
    #if [ $VERBOSE -eq 0 ] ; then  echo "cleaning up tmpdir"; fi
    if [ $GENTMPDIR -eq 0 ] ; then
	    if [ -d "$TMPDIR" ] ; then
	      rm -rf "$TMPDIR"
	    fi
    fi
}

function failbail(){
  echo "sorry, failed: $1"
  echo "stopping"
  dallicleanup
  exit $EXIT_FAILURE
}

# check imagemagick version, might only work for one-digit numbers
CONVERT_ACCEPTABLE_VER="6.4.3"
CONVERT_VERSION=`$CONVERT_BIN -version | head -n 1 | cut -d ' ' -f 3`
if  [[ "$CONVERT_VERSION" < "$CONVERT_ACCEPTABLE_VER" ]]; then
    failbail "convert version $CONVERT_VERSION is too old, at least $CONVERT_ACCEPTABLE_VER of ImageMagick is required"
fi
COMPOSITE_ACCEPTABLE_VER="6.4.3"
COMPOSITE_VERSION=`$COMPOSITE_BIN -version | head -n 1 | cut -d ' ' -f 3`
if  [[ "$COMPOSITE_VERSION" < "$COMPOSITE_ACCEPTABLE_VER" ]]; then
    failbail "composite version $COMPOSITE_VERSION is too old, at least $COMPOSITE_ACCEPTABLE_VER of ImageMagick is required"
fi

# parse options
# Option -h (help) should always be there
# if you have an option argument to be parsed use ':' after option
while getopts ':n:i:b:m:o:O:vht' OPTION ; do
        case $OPTION in
        v)        VERBOSE=0
                ;;
        h)        usage $EXIT_SUCCESS
                ;;
        n)        NUMSEGMENTS="$OPTARG"
                ;;
	m)	MASKIMAGE="$OPTARG"
		GENERATE_MASK=1
		;;
	o)	RESULTIMAGEBASE="$OPTARG"
		RESULTIMAGEBASE_GIVEN=0
		echo "given basename: "$RESULTIMAGEBASE;
		;;
	O)      OUTPUTFILEFORMAT="$OPTARG"
	        ;;
	b)	BACKGROUNDIMAGENAME="$OPTARG"
		GENERATE_BACKGROUND=1
		;;
        t)      GENTMPDIR=1
                ;;
        \?)        echo "Unknown option \"-$OPTARG\"." >&2
                usage $EXIT_ERROR
                ;;
        :)        echo "Option \"-$OPTARG\" given without argument." >&2
                usage $EXIT_ERROR
                ;;
        *)        echo "Parsing of options failed, sorry (this is a bug...)" >&2
                usage $EXIT_BUG
                ;;
        esac
done

if [ $GENTMPDIR -eq 0 ] ; then 
	TMPDIR=`mktemp -d dalliklick.XXXXX`
else
	TMPDIR="."
fi

# skip used options
shift $(( OPTIND - 1 ))
# test for number of arguments
if (( $# < 1 )) ; then
        echo "Missing input image." >&2
        usage $EXIT_ERROR
fi

INIMGCNT=""

for INPUTIMAGE in "$@"
do
	if [ $VERBOSE -eq 0 ] ; then  echo "processing $INPUTIMAGE"; fi

	WIDTH=`identify -format "%w" "$INPUTIMAGE"`
	HEIGHT=`identify -format "%h" "$INPUTIMAGE"`
	if [ -z "$WIDTH"  -o -z "$HEIGHT" ] ; then failbail "cannot identify size of image $INPUTIMAGE" ; fi
	if [ $VERBOSE -eq 0 ] ; then  echo "[debug] imagesize: $IMGSIZE $WIDTH $HEIGHT"; fi
	
	# generate a mask image
	if [ $GENERATE_MASK -eq 0 ] ; then
		TMPMASKIMAGENAME="$TMPDIR/$MASKIMAGENAME"
		generate_voronoi_template "$WIDTH" "$HEIGHT" "$NUMSEGMENTS" 
	else
		TMPMASKIMAGENAME="$MASKIMAGENAME"
	fi
	
	# debug: convert labelled mask image to 256 colors
	# convert -colors 256 -colorspace GRAY $MASKIMAGENAME ?
	
	if [ $GENERATE_BACKGROUND -eq 0 ] ; then
		# do this in the temporary directory
		BACKGROUNDIMAGE="$TMPDIR/$BACKGROUNDIMAGENAME"
		# generate 'starting' canvas
		CMD="$CONVERT_BIN -size ${WIDTH}x$HEIGHT plasma:fractal $BACKGROUNDIMAGE"
		if [ $VERBOSE -eq 0 ] ; then  echo $CMD; fi
		eval $CMD
	else
		BACKGROUNDIMAGE="$BACKGROUNDIMAGENAME"
	fi
	
	# output name
	if [ $RESULTIMAGEBASE_GIVEN -ne 0 ] 
	then 
		RESULTIMAGEBASE=`basename "$INPUTIMAGE"`
	fi
	
	for THRESHOLD in `seq -w 0 1 "$NUMSEGMENTS"`
	do
		RESULTIMAGE="${RESULTIMAGEBASE}_$THRESHOLD.$OUTPUTFILEFORMAT"
		# debug: THRESHOLD=2
		# generate black/white image from mask
		# this is something to be worked out: 
		# color values are two bytes, gray value 1/255 is (257,  257,  257) #010101010101, gray value 2/255 (  514,  514,  514) #020202020202
		# $((256*$THRESHOLD+$THRESHOLD)) # overflow at 8, using eval
		GRAYTHRESH=`expr 256 \* $THRESHOLD + $THRESHOLD`
		GRAYMASKFILE="$TMPDIR/${GRAYMASKDEFAULTFILENAME}"
		CMD="$CONVERT_BIN \"$TMPMASKIMAGENAME\" -colors 256 -threshold $GRAYTHRESH \"$GRAYMASKFILE\""
		# CMD="convert $MASKIMAGENAME -threshold $THRESHOLD $GRAYMASKFILE"
		if [ $VERBOSE -eq 0 ]; then  echo $CMD ; fi
		eval $CMD
		
		# mask the image
		CMD="$COMPOSITE_BIN \"$BACKGROUNDIMAGE\" \"$INPUTIMAGE\" \"$GRAYMASKFILE\" \"$RESULTIMAGE\""
		if [ $VERBOSE -eq 0 ]; then  echo "$CMD" ; fi
		eval $CMD
		if [ $VERBOSE -eq 0 ]; then  echo "result image written to "$RESULTIMAGE ; fi
	done
done


# cleanup
# cleanup and exit messages
dallicleanup
