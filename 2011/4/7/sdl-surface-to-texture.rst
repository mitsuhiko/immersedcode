public: yes
tags: [sdl, opengl, imaging, texturing]
day-order: 2
summary: |
  Now that you have an SDL image, how can you upload it to your graphics
  card and use it with OpenGL?

Surface to Texture
==================

If you are doing OpenGL development you want to upload your images to the
graphics card.  Assuming you already have it as an SDL surface or
something with a similar API all it needs in theory is to send that data
over to the device and be happy.  However you not only want to upload that
texture to the graphics card, you also most likely want a nice little
class that makes working with that texture actually fun.  In C++ that's
actually very easy to do.

So what do we probably want from a texture API?

-   have a class that represents a texture on the remote device.
-   if the graphics card does not support textures that are not a power of
    two we want to automatically slice down the texture a bit.
-   be able to refer to slices on existing textures (for animations, tiles
    etc.)
-   automatically delete the texture from the remote device if we
    deallocate our object.
-   create a texture from an SDL surface or an object with a similar API.

Now unfortunately OpenGL sortof recommends a flipped coordinate system
compared to how everything else handles coordinates.  For 2D games I
strongly recommend flipping the coordinate system and to have the origin
in the top left.  For 3D games the OpenGL default makes a lot of sense,
but you will probably notice that your textures flipped upside down.

There are different ways to deal with this problem:

1.  flip the texture before uploading
2.  flip the texture coordinates on drawing
3.  scale the texture matrix by :math:`y = -1`.

The latter is something you probably don't want to do.  I don't think
there is an equivalent for this in the programmable pipeline, but then
again, I don't know.  What I found easiest is flipping the texture on
uploading.

If you read the SDL documentation you will find out that it supports
textures.  Unfortunately or fortunately, depending on how you look at it,
this texture support is however not available in a way that it would work
with arbitrary OpenGL applications.  But for the purpose of using SDL with
OpenGL you can just ignore that a thing called `SDL_Texture` exists.

The API
-------

The following is roughly how I usually handle textures.  It works quite
well and allows all of the stuff mentioned above.  This is what goes into
your header file:

.. sourcecode:: c++

    class texture;

    texture *texture_from_surface(SDL_Surface *surface);

    class texture {
    public:
        virtual ~texture() {}

        virtual GLuint id() const = 0;
        virtual int width() const = 0;
        virtual int height() const = 0;
        virtual int stored_width() const = 0;
        virtual int stored_height() const = 0;
        virtual int offset_x() const = 0;
        virtual int offset_y() const = 0;
        virtual const texture *parent() const = 0;

        texture *slice(int x, int y, int width, int height);
    };

    class simple_texture : public texture {
    public:
        simple_texture(int width, int height);
        ~simple_texture();

        GLuint id() const { return m_id; }
        int width() const { return m_width; }
        int height() const { return m_height; }
        int stored_width() const { return m_stored_width; }
        int stored_height() const { return m_stored_height; }
        int offset_x() const { return 0; }
        int offset_y() const { return 0; }
        const texture *parent() const { return 0; }
        void init_from_surface(SDL_Surface *surface);

    private:
        GLuint m_id;
        int m_width;
        int m_height;
        int m_stored_width;
        int m_stored_height;
    };

    class texture_slice : public texture {
    public:
        texture_slice(texture *parent, int x, int y, int width, int height);
        GLuint id() const { return m_parent->id(); }
        int width() const { return m_width; }
        int height() const { return m_height; }
        int stored_width() const { return m_parent->stored_width(); }
        int stored_height() const { return m_parent->stored_height(); }
        int offset_x() const { return m_offset_x; }
        int offset_y() const { return m_offset_y; }
        const texture *parent() const { return m_parent; }

        texture *slice(int x, int y, int width, int height);

    private:
        texture *m_parent;
        int m_offset_x;
        int m_offset_y;
        int m_width;
        int m_height;
    };

Most of this API should be straightforward.  There is an abstract base
class called `texture` which provides the interface that is used for
simple textures which are stored directly on the graphics device and for
texture slices, which just provide an alternative view on a different
texture on the device.

The reason why we want two classes is that it's a very common problem to
refer to slices of a texture.  Why?  Because switching between different
textures is expensive and often quite hard to do, but providing different
texture coordinates is simple.  This way you can pass a slice of a texture
to an API that expects any kind of texture and it will work for as long as
you are utilizing this interface properly.

What's the difference between `width`/`height` and
`stored_width`/`stored_height`?  If we upload an image of say 40x40 pixels
and the graphics device does not support textures that are not a power of
two, we will have to run up to the next power of two.  In that case the
stored with and height would be 64 while width and height are 40.

The `id` of the texture would be the `GLuint` that refers to the number of
the texture on the actual graphics device.

Implementation
--------------

And here the implementation that goes into the .cpp file.  It should be
mostly straightforward OpenGL function calls and a little bit of graphics
device capability checking with the help of SDL to see if the device can
handle textures that don't have a power of two dimension.  If we have to
upscale to a power of two we use a small helper function that will do that
for us.

.. sourcecode:: c++

    #include <cassert>
    #include <texture.hpp>
    #include <image.hpp>

    template <class T>
    T next_power_of_two(T value)
    {
        if ((value & (value - 1)) == 0)
            return value;
        value -= 1;
        for (size_t i = 1; i < sizeof(T) * 8; i <<= 1)
            value = value | value >> i;
        return value + 1;
    }
    
    texture *texture_from_surface(SDL_Surface *surface)
    {
        simple_texture *rv = new simple_texture(surface->w, surface->h);
        rv->init_from_surface(surface);
        return rv;
    }
    
    texture *texture::slice(int x, int y, int width, int height)
    {
        return new texture_slice(this, x, y, width, height);
    }
    
    simple_texture::simple_texture(int width, int height)
    {
        m_id = 0;
        m_width = width;
        m_height = height;
    
        if (SDL_GL_ExtensionSupported("GL_ARB_texture_non_power_of_two")) {
            m_stored_width = m_width;
            m_stored_height = m_height;
        } else {
            m_stored_width = next_power_of_two(m_width);
            m_stored_height = next_power_of_two(m_height);
        }
    }
    
    simple_texture::~simple_texture()
    {
        if (m_id)
            glDeleteTextures(1, &m_id);
    }

    void simple_texture::init_from_surface(SDL_Surface *surface)
    {
        assert(surface->w == m_width && surface->h == m_height);

        glEnable(GL_TEXTURE_2D);
        glGenTextures(1, &m_id);
        glBindTexture(GL_TEXTURE_2D, m_id);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
        GLenum format;
        switch (surface->format->BytesPerPixel) {
        case 4:
            format = (surface->format->Rmask == 0x000000ff) ? GL_RGBA : GL_BGRA;
            break;
        case 3:
            format = (surface->format->Rmask == 0x000000ff) ? GL_RGB : GL_BGR;
            break;
        default:
            assert(false);
        }

        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, m_stored_width,
                     m_stored_height, 0, format, GL_UNSIGNED_BYTE,
                     surface->pixels);
    }
    
    texture_slice::texture_slice(texture *parent, int x, int y, int width, int height)
    {
        m_parent = parent;
        m_offset_x = x;
        m_offset_y = y;
        m_width = width;
        m_height = height;
    }

What you notice from this code is that it provides a way to initialize the
texture with surface data later on and not just in the constructor.  Why
is that?  Because sometimes you want to slice up textures already a long
time before the data was actually inside the texture.  This is especially
helpful if you want to implement texture atlasses and stuff like that.
That way you can create an instance of the texture first, and then feed it
with the texture data.  For the common use case where you create a
texture directly from the SDL surface, you can use the
`texture_from_surface` helper function which automates that.

Another word on the settings for the texture.  This code assumes that your
only texture target is `TEXTURE_2D`.  That's actually not a bad assumption
for the common case.  If you notice you need another target you might have
to change other parts of the pipeline anyways so I would not worry too
much about it for the time being.  Same goes for clamping and the filter
modes of the texture.  These are reasonable values for getting started and
once you see something fine tuning shouldn't be the problem.

In fact I made the huge mistake the first time and over architectured my
texture class to also handle 3D textures and 2D texture arrays.  The
latter is actually easy to support with this system without even having to
expand the interface all that much.  All you will need to do would be to
expand the `texture` interface to also have some sort of `layer` where the
layer is the index in the texture array.  Then have a subclass that sets
this layer and keep it zero for the default class.

As texture arrays need shaders anyways it's something you most likely will
not do early in the development anyways I suppose, so really, don't worry
too much about it now.

Example Usage
-------------

So how exactly would one use this texture interface?  That's actually
quite easy.  For loading textures you can use the `texture_from_surface`
function:

.. sourcecode:: c++

    SDL_Surface *img = load_image("ball.png");
    texture *ball = texture_from_surface(img);
    SDL_FreeSurface(img);

For drawing you would have to take the texture coordiantes into account.
If all you want is rendering in a 2D context, here is a simple quad
drawing function:

.. sourcecode:: c++

    void draw_quad(const texture *tex, float x, float y)
    {
        glBindTexture(GL_TEXTURE_2D, tex->id());
        float vertices[] = {
            x, y,
            x, y + tex->height(),
            x + tex->width(), y + tex->height(),
            x + tex->width(), y
        };
        float fac_x = (float)texture->width() / texture->stored_width();
        float fac_y = (float)texture->height() / texture->stored_height();
        float off_x = (float)texture->offset_x() / texture->stored_width();
        float off_y = (float)texture->offset_y() / texture->stored_height();
        float texcoords[] = {
            off_x, off_y,
            off_x, fac_y + off_y,
            fac_x + off_x, fac_y + off_y,
            fac_x + off_x, off_y
        };

        glVertexPointer(2, GL_FLOAT, 0, vertices);
        glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
        glDrawArrays(GL_QUADS, 0, 4);
    }

As you might have noticed from the above code it's using the deprecated
fixed function pipeline functionality, but that should be okay for the
moment.  As with most fixed function stuff you will have to enable it first
though:

.. sourcecode:: c++

    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);

And this is how you would render the whole texture or a slice from it as a
quad on the screen:

.. sourcecode:: c++

    draw_quad(ball, 100.0f, 100.0f);
    texture_slice ball_slice(ball, 20.0f, 20.0f, 80.0f, 80.0f);
    draw_quad(&ball_slice, 200.0f, 100.0f);

Another thing.  If you render textures with an alpha channel you will
notice that you cannot see through it.  That's easy to fix.  All you have
to do is to enable blending and set the blending function:

.. sourcecode:: c++

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

Destructors and Threads
-----------------------

As you can see from the example above I am calling into `glDeleteTextures`
in the destructor of my simple texture.  That's neat and pretty cool if
the thread that is creating the object is also the thread that is tearing
down the object.  Because you can actually control that quite easily in
C++ that's usually not a problem.  However don't come up with the glorious
idea of passing these objects to other threads and letting those other
threads delete the objects.  Also don't do this in any language besides
C++ or C.

If you really want to tear down objects in a managed language in the
destructor you might want to resurrect the object temporarily, put it onto
a queue and let the main event loop get rid of the resources at the end of
the iteration.  That's for example how the release pool works in Objective
C.
