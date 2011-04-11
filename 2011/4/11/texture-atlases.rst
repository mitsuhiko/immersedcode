public: yes
tags: [opengl, imaging, texturing]
summary: |
  Texture switching is expensive and often not possible.  As the cheap way
  out, store more than one texture in the same image.  Here is how.

Simple Texture Atlasses
=======================

Say you want to develop a tile based game.  The simple approach to that
would be creating a bunch of PNG images and then going through each tile,
switching to the texture in question, drawing the tile and going to the
next.  That's not only slow, that also means you cannot use VBOs and other
nice things.

If you have all images of the same size, you could use
`GL_TEXTURE_2D_ARRAY`.  It uses a third texture coordinate to specify the
index in the texture array.  That is pretty nice and works perfectly fine
for things like tiles, but it does not work at all if you are dealing with
objects of different sizes.  A good example of that would be fonts.
Unless you have a monospaced font, the glyphs will be of entirely
different sizes.  Also the texture array needs shaders so you might not
want to dive into that immediately.

So the easiest solution are texture atlasses.  The idea is that you have
a large texture with a bunch of small textures on there.  Now there are
two ways to create such a texture.  The one where you do that by hand in
the image editor of choice, or you try to automatically fit textures on
there.

Building an Atlas
-----------------

Alright, now how do we distribute images on such an atlas?  The easiest
way to do that is by dividing a texture into smaller and smaller pieces.
You could think of this as if it was a graph.

.. image:: /static/blog-media/atlas-overview.png
   :align: right
   :alt: Picture explanation of the atlas texture distribution

What we want to do is to recursively divide the larger texture into empty
and filled buckets.  The idea is that we look at the texture and split the
bucket so that the new texture fits in.  If the texture we add is wider
than higher we add a new split that is as far from the top as our texture
is high, and split inside there a second time for the width of our
texture.

In case we would be able to fit it directly we would not have to add a new
split and could fit it right in there.  Now the trick is that we implement
this algorithm recursively.  All the empty areas are remembered and we
will start trying to fit textures into currently unoccupied places.

The second texture we add here might be standing upright, so the logic is
inversed.  We split along the right side of the image and a second time
for the height.

You can think of this is a tree of nodes where each node has a left and a
right side.  Additionally the node knows where it's located, how big it
is and if it's in use.  Furthermore we also will store a pointer to a
texture slice on there.  For the texture object I am using, have a look at
the `Surface to Texture article <../../7/sdl-surface-to-texture/>`_.

This is by far not the best algorithm but it's easy to implement and
yields acceptable results.

Dealing with Rounding Errors
----------------------------

Texture coordinates in OpenGL are floating point values in the range 0.0
to 1.0.  The problem with floating point values is that they are floating.
Or like `Christina Coffin said <http://twitter.com/#!/ChristinaCoffin/status/53744889330020352>`_:

    'float precision' … yeah it floats a bit to the left or the right of
    where the accurate result would be.

As a result of that you will notice that the edge of your texture will be
not completely correct.  If you put texture next to texture, you can see
the edges overlap.  I am using automated atlas building for fonts mostly,
so my implementation “solves” that problem by keeping one transparent
pixel padding between the textures.

Alternatively if you have actual game tiles you might want to mirror the
opposing edge of the texture to the other side so that you can tile them
properly.

The Atlas API
-------------

The API for the atlas is straightforward.  You have a class that provides
an `add` method that accepts an SDL surface and blits it onto an internal
surface.  When you added all, you can `freeze` the atlas and use the
attached texture.

The atlas itself has a texture that is created with a given dimension.
Additionally for as long as the atlas is not frozen we have an internal
SDL surface where we blit together the images.  When we freeze the texture
we upload it to the device and get rid of the SDL surface underneath.

As mentioned above the idea is that we have an internal tree of nodes.  As
such as we introduce an internal `atlas_node` class and attach a root node
to the atlas.  The node has a left and right child, a flag that tells us
if it's in use and the dimensions of it.  Additionally we store a
reference to a texture there.

Additionally we let the atlas know the padding it should introduce between
images that are blitted to the surface.

.. sourcecode:: c++

    class atlas;
    struct atlas_node;

    struct atlas_node {
        atlas_node *left;
        atlas_node *right;
        texture *tex;
        int x;
        int y;
        int width;
        int height;
        bool in_use;

        atlas_node(int, int y, int width, int height);
        atlas_node *insert_child(SDL_Surface *surface, int padding);
    };

    class atlas {
    public:
        atlas(int width, int height, int padding = 0);
        ~atlas();

        texture *add(SDL_Surface *surface);
        void freeze();
        bool frozen() const { return m_image == 0; }
        const ::texture *texture() const { return m_texture; }
        int width() const { return m_width; }
        int height() const { return m_height; }

    private:
        simple_texture *m_texture;
        SDL_Surface *m_surface;
        int m_width;
        int m_height;
        int m_padding;
        atlas_node *m_root;
    };

The Implementation
------------------

Now, what does the implementation look like?  The nodes are simple.  What
we need is a method that can insert new children which is called
recursively.  A ltitle bit of math is involved there to calculate the
proper positions and dimensions for the slices.

We also take the padding into account, but the majority of the logic in
there is straightforward.  Generally, we prefer the left or top node and
this is what's returned.  If we cannot insert a new node for our requested
surface, 0 is returned.

.. sourcecode:: c++

    atlas_node::atlas_node(int x, int y, int width, int height)
    {
        this->left = 0;
        this->right = 0;
        this->tex = 0;
        this->x = x;
        this->y = y;
        this->width = width;
        this->height = height;
        this->in_use = false;
    }

    atlas_node *atlas_node::insert_child(SDL_Surface *surface, int padding)
    {
        if (left) {
            atlas_node *rv;
            assert(right);
            rv = left->insert_child(surface, padding);
            if (!rv)
                rv = right->insert_child(surface, padding);
            return rv;
        }

        int img_width = surface->w + padding * 2;
        int img_height = surface->h + padding * 2;

        if (in_use || img_width > width || img_height > height)
            return 0;

        if (img_width == width && img_height == height) {
            in_use = true;
            return this;
        }

        if (width - img_width > height - img_height) {
            /* extend to the right */
            left = new atlas_node(x, y, img_width, height);
            right = new atlas_node(x + img_width, y,
                                   width - img_width, height);
            left->left = new atlas_node(x, y, img_width, img_height);
            left->right = new atlas_node(x, y + img_height, img_width,
                                         height - img_height);
        } else {
            /* extend to bottom */
            left = new atlas_node(x, y, width, img_height);
            right = new atlas_node(x, y + img_height,
                                   width, height - img_height);
            left->left = new atlas_node(x, y, img_width, img_height);
            left->right = new atlas_node(x + img_width, y,
                                         width - img_width, img_height);
        }

        left->left->in_use = true;
        return left->left;
    }

The atlas itself is not much more complex.  We create an SDL surface for
the atlas (which unfortunately requires butching with masks as the API is
really crapp) and then we add some code to recursively free up the memory
for the constructor and a method that adds a new node to the root node and
blits the requested image on our code surface.

The `freeze` method then takes this surface, intializes the texture with
it and you're good to go.

.. sourcecode:: c++

    atlas::atlas(int width, int height, int padding)
    {
        m_width = width;
        m_height = height;
        m_texture = new texture(width, height);
        m_image = 0;
        m_padding = padding;

        uint32_t rmask, gmask, bmask, amask;
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
        m_surface = SDL_CreateRGBSurface(0, width, height, 32,
                                         rmask, gmask, bmask, amask);
        m_root = new atlas_node(0, 0, m_width, m_height);
    }

    static void recursive_delete(atlas_node *node)
    {
        if (node->left)
            recursive_delete(node->left);
        if (node->right)
            recursive_delete(node->right);
        delete node->tex;
        delete node;
    }

    atlas::~atlas()
    {
        delete m_surface;
        delete m_texture;
        recursive_delete(m_root);
    }

    ::texture *atlas::add(SDL Surface *surface)
    {
        assert(!frozen());

        atlas_node *rv = m_root->insert_child(surface, m_padding);
        if (!rv)
            return 0;

        SDL_Rect rect = { rv->x + m_padding, rv->y + m_padding, surface->w, surface->h };
        SDL_BlitSurface(surface, 0, m_surface, &rect);
        rv->tex = m_texture->slice(rv->x + m_padding, rv->y + m_padding,
                                   surface->w, surface->h);
        return rv->tex;
    }

    void atlas::freeze()
    {
        assert(!frozen());
        m_texture->init_from_surface(m_surface);
        delete m_surface;
        m_surface = 0;
    }

And the Atlas in Use
--------------------

Now how does this work in practice?  This is how this is used (pseudocode)
for my font rendering:

.. sourcecode:: c++

    m_atlas = new atlas(128, 128);
    for (int i = 0; i < 255; i++) {
        SDL_Surface *surface = render_glyph(i);
        m_glyphs[i] = m_atlas->add(surface);
        SDL_FreeSurface(surface);
    }
    m_atlas->freeze();

And this is how a font uploaded into such an atlas looks like:

.. image:: /static/blog-media/atlas-for-fonts.png
   :align: center

As you can see from this image there is a lot of empty space in there
which could be nice using.  Unfortunately you cannot predict an advance
how well your images fit into an atlas.  It's in fact an NP-complete
problem as far as I'm aware so some optimisting guessing upfront is a good
idea.  Because fonts render out really quickly for instance what I am
doing is calculating the average expected glyph size times the number of
glyphs I am expecting and creating an atlas of that size, then filling it.
If it turns out that my guess was wrong I will double the size of one of
the sides and try again.

It's not perfect, but it works good enough for the time being that I don't
care too much about it.
