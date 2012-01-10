public: yes
tags: [webgl, javascript]
summary: |
  Some random things I came across when using WebGL over Christmas.

Random Notes on WebGL
=====================

I spend a lot of time over Christmas to play around with WebGL and to
attempt to port my Minecrafty renderer over to JavaScript and WebGL and I
thought it would be wise to share some of the experiences I had with that
with others.

This post contains a bunch of random notes I wish I would have known
before I started my experiment :-)

First things first: I'm not a huge fan of CoffeeScript but it's a
wonderful language to share code snippets since it's concise and very
readable.  All the examples on this page are in CoffeeScript or GLSL.

.. image:: /static/blog-media/voxel-world.png
   :align: center
   :alt: Picture explanation of my minecrafty renderer.

.. raw:: html

   <small>

The above image is the finished results of my adventures.

.. raw:: html

   </small>

Matrix Libraries
----------------

You will need a matrix library when working with WebGL.  There is one that
is used in every tutorial which I really don't like and there is
`gl-matrix <https://github.com/toji/gl-matrix>`_ which is actually good.
Use that.  It's fast and it has a sane API.

gl-matrix does not define it's own types, it uses the ``Float32Array`` for
matrices and vectors which makes a lot of sense since this are also the
types that you can pass through the WebGL APIs.  And they are also fast
and memory efficient.

Unfortunately it misses a few essential types such as support for vectors
of 4 so I had to add a few of these missing functions on my own when I
used it.

Debugging WebGL
---------------

Before you do anything with WebGL, head over to this page: `WebGL
Debugging <http://www.khronos.org/webgl/wiki/Debugging>`_.  You can thank
me later :-)

Awaiting Async Events
---------------------

The first pattern I found very useful is the general concept of awaiting
for asynchronous requests.  It's basically a form of locking where you
wait for a bunch of asynchronous events to all happen before you continue.
A good example for this is for instance waiting for all the images needed
to load before starting to render.

The idea there is that you have a counter of all the outstanding events
and then once that counter reaches zero *and* all the events were
triggered you can call the final callback.

This for instance is a simplified version of the resource manager I am
using:

.. sourcecode:: coffeescript

    class ResourceManager
      constructor: ->
        @resourceDefs = {}
        @callbacks = {}
        @resources = {}
        @loaded = 0
        @total = 0

      add: (key, filename, def = {}, callback = null) ->
        def.key = key
        def.type = this.guessType filename
        def.filename = filename
        @resourceDefs[key] = def
        @total++
        (@callbacks[key] ?= []).push callback if callback?
        this.triggerLoading def

      doneLoading: ->
        @loaded >= @total

      wait: (callback) ->
        return callback() if this.doneLoading()
        (@callbacks.__all__ ?= []).push callback

      triggerLoading: (def) ->
        @loaders[def.type] this, def, (obj) =>
          @resources[def.key] = obj
          callbacks = @callbacks[def.key]
          delete @callbacks[def.key]
          @loaded++
          for callback in callbacks || []
            callback obj
          if this.doneLoading()
            this.notifyWaiters()

      notifyWaiters: ->
        callbacks = @callbacks.__all__ || []
        delete @callbacks.__all__
        for callback in callbacks
          callback()

      guessType: (filename) ->
        return 'image' if /\.(png|gif|jpe?g)$/.test filename

      loaders:
        image: (mgr, def, callback) ->
          rv = new Image()
          rv.onload = -> callback rv
          rv.src = def.filename

The way it works is that you create an instance of the resource manager,
add all the resources it should load and while you're already adding the
resources the browser already starts to fetch stuff.  Once you call
``wait()`` with a callback it will either directly call the callback if
everything was already loaded or defer the callback.

After each resource is loaded it checks if there are callbacks for people
waiting and will fire them appropriately.

The ``guessType()`` function here detects the type of resource from the
filename and returns the name of the loader that can trigger the loading.
In this case there is only one loader for images.

Here an example usage:

.. sourcecode:: coffeescript

    resmgr = new ResourceManager()
    resmgr.add 'blocks/grass', 'assets/blocks/grass.png'
    resmgr.add 'blocks/water', 'assets/blocks/water.png'
    resmgr.wait ->
      game.mainloop()
      # resources are on resmgr.resources['blocks/grass'] etc.

Since it's possible to wait for individual resources you can also have
resources load other resources.  For instance I check if a filename has
``.texture`` as suffix, in which case I assume that the first part of the
filename refers to the image.  That way I trigger the loading of the image
before I create the texture:

.. sourcecode:: coffeescript

    guessType: (filename) ->
      # ...
      return 'texture' if /\.texture$/.test filename

    loaders:
      # ...

      texture: (mgr, def, callback) ->
        imageFilename = def.filename.match(/^(.*)\.texture$/)[1]
        mgr.add 'auto/' + imageFilename, imageFilename, {}, (image) =>
          callback createTexturefromImage(image, def)

In this case the resource load triggered by the texture is given a unique
key (``auto/`` as prefix plus the filename of that resource).  Once loaded
it's forwarded to a function that can convert an image into a texture.

If you want to be conservative with resources you could iterate over all
items in ``@resources`` and get rid of all the (now unnecessary) ``auto/``
resources.

Shader Management
-----------------

One annoying property of GLSL shaders is that they do not have any concept
of modules or even includes.  If you want to reuse common bits and pieces
between different shaders you need to write your own preprocessor.

This especially becomes very annoying quickly because error messages
generated by the GLSL compiler are implementation specific and will point
you to the wrong locations when you do very naive preprocessing.

On top of all that GLSL wants you to have the fragment and vertex shader
in two different files even though you rarely can mix them.

The solution I use for these problems is to move the vertex and fragment
shader into the same file and reimplement a very basic preprocessor that
resolves ``#include`` statements and adds appropriate line informations.

My shader loading code looks basically like this:

.. sourcecode:: coffeescript

    lastSourceID = 0
    shaderSourceCache = {}
    shaderReverseMapping = {}

    shaderFromSource = (type, source, filename = null) ->
      shader = gl.createShader gl[type]
      source = '#define ' + type + '\n' + source
      gl.shaderSource shader, source
      gl.compileShader shader
      if !gl.getShaderParameter shader, gl.COMPILE_STATUS
        log = gl.getShaderInfoLog shader
        # do something with the shader log here to make it
        # visible in the console
        # ...
      shader

    preprocessSource = (filename, source, sourceID, callback) ->
      lines = []
      shadersToInclude = 0
      done = false
      checkDone = ->
        callback lines.join('\n') if done && shadersToInclude == 0

      lines.push '#line 0 ' + sourceID

      for line in source.split /\r?\n/
        if !(match = line.match /^\s*#include\s+"(.*?)"\s*$/)
          lines.push line
          continue
        pos = lines.length
        lines.push null
        shadersToInclude++
        do (pos) ->
          loadShaderSource match[1], (source) ->
            lines[pos] = source + '\n#line ' + pos + ' ' + sourceID
            shadersToInclude--
            checkDone()

      done = true
      checkDone()

    loadShaderSource = (filename, callback) ->
      process = (source) ->
        entry = shaderSourceCache[filename]
        if !entry
          shaderSourceCache[filename] = entry = [source, lastSourceID++]
          shaderReverseMapping[entry[1]] = filename
        preprocessSource filename, source, entry[1], callback
      if cached = shaderSourceCache[filename]
        return process cached[0]
      jQuery.ajax
        url: filename
        dataType: 'text'
        success: process


    class Shader

      constructor: (source, filename = null) ->
        @id = gl.createProgram()
        @vertexShader = shaderFromSource 'VERTEX_SHADER', source, filename
        @fragmentShader = shaderFromSource 'FRAGMENT_SHADER', source, filename
        gl.attachShader @id, @vertexShader
        gl.attachShader @id, @fragmentShader
        gl.linkProgram @id

      this.fromFile: (filename) ->
        loadShaderSource filename, (source) ->
          return new Shader source, filename

      destroy: ->
        gl.destroyProgram @id
        gl.destroyShader @vertexShader
        gl.destroyShader @fragmentShader

The shader can be loaded via ``Shader.fromFile('sample.glsl')`` for
instance.  What's interesting is how the shaders are written.  It defines
a ``VERTEX_SHADER`` constant in the shader if it's loaded as vertex
shader, or ``FRAGMENT_SHADER`` if it's loaded as fragment shader.

A very basic shader could look like this:

.. sourcecode:: glsl

    #include "common.glsl"
    varying vec2 vTextureCoord;

    #ifdef VERTEX_SHADER
    void main(void)
    {
        gl_Position = uModelViewProjectionMatrix * vec4(aVertexPosition, 1.0);
        vTextureCoord = aTextureCoord;
    }
    #endif

    #ifdef FRAGMENT_SHADER
    void main(void)
    {
        gl_FragColor = texture2D(uTexture, vTextureCoord);
    }
    #endif

The common uniforms and varyings are then in a ``common.glsl`` like this:

.. sourcecode:: glsl

    #ifndef COMMON_GLSL_INCLUDED
    #define COMMON_GLSL_INCLUDED
    
    precision highp float;
    
    #ifdef VERTEX_SHADER
    attribute vec3 aVertexPosition;
    attribute vec3 aVertexNormal;
    attribute vec2 aTextureCoord;
    #endif

    uniform mat4 uModelMatrix;
    uniform mat4 uViewMatrix;
    uniform mat4 uProjectionMatrix;
    uniform mat4 uModelViewProjectionMatrix;
    uniform sampler2D uTexture;

    #endif

This saves keeps things simple and easy :-)

Other Shader Tips
-----------------

I have two other tips about shaders I wish I think are worth sharing.

Uniform Management
~~~~~~~~~~~~~~~~~~

In the fixed function pipeline the builtin uniforms were set
automatically.  That obviously is not the case in modern OpenGL or WebGL,
so when should you set uniforms?  For things I have defined in the
``commmon.glsl`` that is included in every shader I have a function called
``flushUniforms()`` that knows when things have changed on the shader and
sends changes to the device as necessary.  For this I increment a count
whenever things change on the JavaScript side of things and compare the
count as stored on my shader object:

.. sourcecode:: coffeescript

    currentShader = null
    projectionMatrix = mat4.create();
    uniformVersion = 0

    class Shader
      
      constructor: (source, filename = null) ->
        # ...
        @_uniformVersion = 0

      bind: ->
        gl.useProgram this
        currentShader = this

    flushUniforms = ->
      return if uniformVersion == currentShader._uniformVersion
      loc = gl.getUniformLocation currentShader.id, "uProjectionMatrix"
      gl.uniformMatrix4fv loc, false, projectionMatrix if loc
      # ...
      currentShader._uniformVersion = uniformVersion

Now every time you modify the projection matrix or anything else you will
need to remember to increment ``uniformVersion`` as well.  I created
myself some helper functions that that also feel a little bit closer to
the fixed function pipeline by having a matrix stack.

Why did I check above if the location is there if it should always be
there since it's in the ``common.glsl``?  Because if the optimizer sees
that a uniform is unused it removes it completely and you won't be able to
find the location.

Shader Debugging
~~~~~~~~~~~~~~~~

If you're using my shader load code from above you will have a mapping of
source ID to filename.  This can be used to provide proper tracebacks in
the browser's console that point to the actual filename and line number:

.. sourcecode:: coffeescript

    onShaderError = (log, filename = '<string>') ->
      console.error "Shader error in #{filename}"
      console.debug "Shader debug information:"
      lines = log.split /\r?\n/
      for line in lines
        match = line.match /(\w+):\s+(\d+):(\d+):\s*(.*)$/
        if match
          [dummy, level, sourceID, lineno, message] = match
          errorFilename = shaderReverseMapping[sourceID]
          console.warn "[#{level}] #{errorFilename}:#{lineno}: #{message}"
        else
          console.log line
      throw "Abort: Unable to load shader '#{filename}' because of errors"

And here what it looks like:

.. image:: /static/blog-media/shader-error.png
   :align: center
   :alt: Picture explanation of a shader error in firebug.

The above error message was further extended to also include the type of
shader that failed compiling.

What WebGL is Missing
---------------------

WebGL is approximately OpenGL ES 2.0 and I should have known this
beforehand.  It limits what you can do somewhat and you have to apply a
bunch of tricks to deal with those limitations.  Initially I was quite
convinced that my entry level hackery on WebGL would not hit its
limitations but I was very wrong on this.

I collected a list of features you will find that WebGL is lacking or not
supporting properly and why it might or might not be a problem for you.

Texture Arrays
~~~~~~~~~~~~~~

If you ever have looked at Minecraft you will know that the world is made
out of blocks where each block has a texture.  In order to draw a cube
world the simplest way possible is to draw only the surfaces where a solid
block hits air so you save the whole blocks that are not at all visible to
any possible viewer.

Assuming you draw a surface of 128x128x128 blocks you will iterater
2097152 times over your world.  In a naive version like the one I wrote
this also involves to check for each block about neighbors which also
means that I have at least a million block lookups.  That's okay in terms
of performance but it's not exceptionally fast.  So what I did was
dividing the world into smaller chunks and upload the vertices for those
to the graphics device  as vertex buffer objects..  Then every time you
change a block you only need to invalidate the vertex buffer objects that
are affected by the block change and you're good.  Also a draw call for
each surface would be slow and is also unsupported by WebGL.

Limitations there: Each VBO can only reference a single texture.

One solution is storing all textures on a single image and then
referencing different areas of that image.  This is commonly referred to
as a `texture atlas <../../../../2011/4/11/texture-atlases/>`_.  The
problem with a texture atlas is that your textures will start bleeding
around the edges because of rounding errors and mipmapping starts creating
huge visual artefacts.

In OpenGL the solution for this problem has been a version of 3D textures
were the `Z` coordinate was referring to the item in the array.  This way
for as long as you have images of the same size for all items of the array
you have perfect mipmapping and no texture bleeding.

WebGL does not have that.  Who is affected by this?  Everybody that wants
to do tile based rendering with mipmapping or filtering.  So strategy
games, things like Minecraft and a few others.  You can either disable
filtering on your textures and get rid of mipmapping or you try to apply
some hacks around it.

For instance this is how I upload my textures to the graphics device:  I
load the image and then arrange it in a 3x3 formation.  The source image
in the center and then I surround it by 8 copies of itself.  This way if
the texture starts bleeding due to mipmapping or filtering it bleeds into
itself.  That works fine for most parts but it still falls flat when
looking at cubes from odd angles.

.. image:: /static/blog-media/3x3-texture-blit.png
   :align: center
   :alt: Example of the 3x3 texture blitting.

Since anisotropic filtering is unavailable as well, odd angles are
somewhat of an issue anyways.

Reading Texture Data
~~~~~~~~~~~~~~~~~~~~

For my renderer I was attempting to utilize the GPU for perlin simplex
noise generation.  The idea was to generate the noise on the GPU, render
it into a texture, download it to the CPU and then use this noise data to
randomly generate a world.

WebGL by itself does not have floating point textures but there is an
extension for it: ``OES_texture_float``.  Good news is: it's somewhat
supported by now.  Bad news: the extension makes float textures possible
but provides no way to access the float data from the JavaScript side of
things.  WebGL only specifies behavior for ``gl.readPixels`` when called
for ``RGBA`` texture formats with a channel type of ``UNSIGNED_BYTE``.

Even if you're fine with byte precision for data you still have to fetch
all four channels which is unfortunate.  There are probably some ways
around that such as encoding 32bit of information into the four 8bit
channels but something tells me that this has horrible performance and
rouding artifacts on shaders that do not provide integers.

Multiple Render Targets
~~~~~~~~~~~~~~~~~~~~~~~

In WebGL and OpenGL ES 2.0 a fragment shader can do two things: it can
assign a value to ``gl_FragColor`` as an end result or to ``gl_FragData[i]``
where ``i`` is between zero and ``gl_MaxDrawBuffers`` —
``gl_MaxDrawBuffers`` is 1.

This is very, very unfortunate since it means you need multiple render
passes for something that could be calculated in one and as such it makes
for worse performance than necessary.  For things like deferred shading
multiple render targets are an integral part of what makes it interesting.
A fragment shader can calculate per-fragment colors, normals or positions.
Considering that multiple render targets are available in DX9 and OpenGL
2.0 it's very sad that we can't use it on the web.  It limits what you can
do with acceptable performance a lot.

Antialiasing
~~~~~~~~~~~~

Everybody hates jaggies.  Aliasing is what degrades a good image to
something awful looking, especially if you're dealing with high view
distances and small objects in the background.  OpenGL for ages likes to
make ignore that problem altogether and decides to move the burden of
multisampling antialiasing to whoever creates the OpenGL context.

In WebGL the same rule applies.  When creating a WebGL context you can
tell it to enable antialiasing.  But that only solves the issue for as
long as you don't start to use frame buffer objects.  The moment you
decide to render into an FBO instead to the screen all the aliasing magic
goes away and you're left with jaggies.  And rendering to an FBO is
necessary if you want to create some screen-space effects like SSAO.

Also on some browsers the builtin antialiasing is a huge performance
killer.  This is especially true on older versions of Firefox.  The good
news is that solutions like FXAA exist which are simple to implement
(`example implementation for WebGL
<https://github.com/mitsuhiko/webgl-meincraft/blob/master/assets/shaders/fxaa.glsl>`_)
which can operate on aliased images and try to reconstruct subpixels.

Maybe this is where things are going in general but it does require some
extra effort on the developers part which is annoying.

JavaScript is Slow
~~~~~~~~~~~~~~~~~~

I knew from the start that JavaScript would not be the fastest thing in
the world but I expected Python like performance if not better.  Depending
on what you do that is the case, but some things I would have never
written in Python to start with.  For instance if I needed noise I would
write that in C and use that from Python.

My simplex noise generator which I mostly copied from the “`Simplex noise
demystified
<http://www.itn.liu.se/~stegu/simplexnoise/simplexnoise.pdf>`_” paper was
fast enough that I could do the world generation in the main thread.  In
JavaScript I moved the world generation into four web workers and each
worker spends around two seconds for a single chunk of 32x32x32 blocks.  I
don't have any hard numbers to back this up since there are differences in
the implementation that could affect this, but I would assume that it's
around 100 times slower at the very least.

User Expectations and Interactive Content
-----------------------------------------

One last thing I thought about was how feasible multiplayer games with
websockets and WebGL would be.  And all things considered, it's probably
possible but a lot more expensive than a native implementation.

The main reason is that the only tool you have available for communication
are websockets.  Besides the fact that they are TCP based they are also
developed in a way that they do not support point to point communication
between browsers.  This makes peer to peer hosting impossible (by
design!).  I also doubt that users that see a website would be hosting
their own servers for multiplayer games like they use to do for PC
shooters for instance.  This makes hosting multiplayer games for web games
a lot harder than for native games.

What else?
----------

WebGL is fun.  It's fun because it does not crash.  You can interactively
play from your browser's JavaScript console with it.  You don't have to
develop your own developer console, just use the tools of your browser.

You can easily dump states of textures to images and inspect them and
figure out where problems are.  That said, there will be an ugly first
week of using it.  I was frustrated for a long time until I stopped
applying my OpenGL knowledge on WebGL in all situations.  Just because you
get a familiar error code from OpenGL does not mean the error code does
not have a new meaning in WebGL.

In many situations where previously you would have received a segfault or
just memory corruption you now get ``INVALID_OPERATION`` back or something
similar.
