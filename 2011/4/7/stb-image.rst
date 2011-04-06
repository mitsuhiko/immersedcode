public: yes
tags: [sdl, imaging]
day-order: 1
summary: |
  The easiest way to load images with C++ and SDL that does not involve
  the SDL_image library which needs a bunch of dependencies.

Loading Images the Simple Way
=============================

Most games need to be able to load images.  There are a handful of
exceptions where games seem to be able to bypass textures with a different
art style, but chances are, you will need to load images as textures.

Usually before you upload a texture into video memory you will have to
load it from the filesystem into the main memory first.  In the memory the
pixels are sitting next to each other and you can access them easily.
However on the file system it looks different.  Because it would an
incredible waste of space if you store images uncompressed on the file
system you usually load them from PNG or JPEG files which have a much
lower file size than their uncompressed counterparts.

Motivation
----------

Unfortunately loading these files can be a complex process.  The
`SDL_image <http://www.libsdl.org/projects/SDL_image/>`_ library exists
and can load images from BMP, PNG, JPEG, GIF, TGA and a bunch of other
file formats into an `SDL_Surface`.  The downside of that library is that
it depends on a bunch of other libraries.  For PNG support you need libpng
and zlib, for JPEG you need jpeglib.  If that's not a problem for you, you
can compile these libraries and you are good to go.

Alternatively you might be interested in `stb_image.c
<http://www.nothings.org/stb_image.c>`_.  It's legendary in that it
implements a PNG, JPEG and TGA loader in a single C file without
dependencies.  It also supports a bunch of other formats, but with PNG and
JPEG in the mix, there is hardly anything else you will need.  What's the
downside?  You still need a little bit of code to make it load into
something useful and nice and you better not point it at untrusted images.
What's an untrusted image?  Something you did not create yourself like
images downloaded directly from the internet on the user's computer.  You
never know …

Wrapping stb_image
------------------

`stb_image` itself provides two functions you will most likely care about.
The first one is `stbi_load_from_file` which does exactly what the name
says and `stbi_image_free` which deallocates the memory that `stbi`
allocated.  The first function will return a newly allocated unsigned
character array of bytes in the image and it will pass out the resolution
of the images and the number of channels into three variables via
parameters.

In order to do something useful with this we have to store it in some kind
of object.  If you're using SDL, you might want to store it in an
`SDL_Surface`.  This is what the following function does.  It also tries
to accomodate for different byte orders, but truth be told, I only tried
it for little endian.  The following function will return a new
`SDL_Surface *` or 0 if an error ocurred:

.. sourcecode:: c++

    #include <stdio.h>

    /* this is the only file using stb_image, so it's fine */
    #include <stb_image.c>


    SDL_Surface *load_image(const std::string &filename)
    {
        int x, y, comp;
        unsigned char *data;
        uint32_t rmask, gmask, bmask, amask;
        SDL_Surface *rv;

        FILE *file = fopen(filename.c_str(), "rb");
        if (!file)
            return 0;
    
        data = stbi_load_from_file(file, &x, &y, &comp, 0);
        fclose(file);
    
    #if SDL_BYTEORDER == SDL_BIG_ENDIAN
        rmask = 0xff000000;
        gmask = 0x00ff0000;
        bmask = 0x0000ff00;
        amask = 0x000000ff;
    #else
        rmask = 0x000000ff;
        gmask = 0x0000ff00;
        bmask = 0x00ff0000;
        amask = 0xff000000;
    #endif
    
        if (comp == 4) {
            rv = SDL_CreateRGBSurface(0, x, y, 32, rmask, gmask, bmask, amask);
        } else if (comp == 3) {
            rv = SDL_CreateRGBSurface(0, x, y, 24, rmask, gmask, bmask, 0);
        } else {
            stbi_image_free(data);
            return 0;
        }
    
        memcpy(rv->pixels, data, comp * x * y);
        stbi_image_free(data);
    
        return rv;
    }

As you can see this code only handles 24bit and 32bit color images (RGB
and RGBA).  That should be fine for the majority of use cases but
sometimes it would be cool to load 8bit single channel images as well.
Unfortunately the SDL surface is a very user unfriendly data structure.  I
recommend having a separate function for that purpose that loads an image
into a regular `uint8_t` array or something.

You can now use this surface for SDL blitting, but what you really want to
do is to upload it to the graphics card.  How this works you can read `in
my separate post about textures <../sdl-surface-to-texture/>`_.

SDL Surface's API
-----------------

As you can see I was using the SDL surface above and I will continue to do
this in most of the articles in this blog that are talking about SDL in
some way.  However I strongly urge you to consider using your own tiny
image class that has a simpler API.  If you are using C++ you can easily
use a template that wraps an array and provides nicer ways to access
individual pixels if you plan on doing that.

If there are issues with endianess in these examples don't be surprised.
