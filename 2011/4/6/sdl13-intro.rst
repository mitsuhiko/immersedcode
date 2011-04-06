public: yes
tags: [sdl, opengl]
day-order: 2
summary: |
  The missing SDL 1.3 tutorial that gets you started quickly with cross
  platform OpenGL development.

A Gentle Introduction into SDL 1.3
==================================

If your plan is to dive into game development and you are not too afraid
of dealing with gory details you probably want to use `SDL
<http://libsdl.org/>`__ 1.3.  It's the as of writing unreleased version of
SDL, but clearly the one you want to use.  What this tutorial tries to
show you is not how to utilize SDL or OpenGL but how to get a project
running that is based on SDL and OpenGL (the build tool aspect, how to
initialize SDL properly and how a mainloop is structured).  Don't expect
anything else from it, though there might be a separate post that
continues where this left off.

SDL originally was created as a helper library by Sam Lantinga to help
porting Windows games over to Linux.  However it does not only support
Linux, it also works perfectly fine on OS X, Windows, the Nintendo DS,
iOS, Android and a bunch of other operating systems.  It does basic sound
processing, has a simple 2D rendering API, can create you an OpenGL
context, opens windows and so on.

The majority of tutorials you will find right now is targeted towards SDL
1.2.  However the upcoming 1.3 release is where the magic is happening.
Compared to SDL 1.2 it comes with a whole bunch of new functionality:

-   largely improved API for surface and texture handling
-   support for multiple OpenGL contexts, windows and displays
-   support for multi-touch and gestures
-   abstraction for high performance counters
-   support for haptic devices (force feedback)
-   support for OpenGL 3

Now the rest of this article assumes that you have no idea about what SDL
is.  We will have a look at what SDL 1.3 is, how to obtain it and how to
use it on OS X, Windows and Linux.  If you are curious about handheld
development I am sure it should not be too complicated to further expand
from that point.  Also this tutorial assumes that you want to use OpenGL
for the actual rendering then and not SDL itself.

Getting Started
---------------

As a best practice guide I will use `CMake <http://www.cmake.org/>`_ here
as the build tool of choice and I strongly recommend using this.  Even if
all you care about is one platform, the advantages of CMake over Makefiles
or your IDE integrated build system is just too high that it would be
worth dismissing this as unnecessary.

Once you have CMake installed we need a folder to drop our project into.
Here is how the structure looks in my case::

    hello-sdl/
        CMakeLists.txt
        libs/
        scripts/
        src/
            hello.cpp
        include/
            hello/hello.hpp

For the time being just create a bunch of empty files and folders which we
will fill with content shortly.

SDL 1.3 can be obtained by checking it out from `mercurial
<http://hg-scm.org/>`_.  If you don't have mercurial installed, do that
now.  SDL does have nightly tarballs, but you really want to use the
mercurial checkout in order to quickly be able to update.  Make sure to
clone into the `libs/` folder::

    $ cd libs
    $ hg clone http://hg.libsdl.org/SDL sdl-1.3

For the time being I also urge you to not install SDL globally on OS X or
linux as 1.3 is not API compatible with SDL 1.2 and it will probably cause
more harm than good if you try that.  Instead I recommend “installing” it
into a local folder and telling CMake to look for SDL there.  If you are
on OS X or Linux, this is how you do it::

    $ cd sdl-1.3
    $ ./configure --prefix=`pwd`/local
    $ make && make install

In case you are on Windows it's even easier.  Open the “sdl-1.3” folder
and navigate into the “VisualC” sub folder.  It will contain a bunch of
Visual Studio solution files for different versions of Visual Studio.
Just open it and build “SDL” and “SDLmain” in release mode and you are
good to go.

Configuring CMake
-----------------

The next thing we have to do is to write a “CMakeLists.txt” file.  The
purpose of this file is not only to build our project but also to set up
the compiler properly to add the necessary header files to the include
path and to automatically link in SDL and OpenGL as well as a bunch of
other things that might be necessary.

Add this into your “CMakeLists.txt” file:

.. sourcecode:: cmake

    cmake_minimum_required(VERSION 2.6)
    project(HelloSDL)

    # A list of header and source files used by your application.
    set(SOURCES
        src/hello.cpp
    )
    set(HEADERS
        hello/hello.hpp
    )

    # The following code finds SDL 1.3 in your checkout on OS X, Linux
    # as well as Windows.  On Windows I am lazy and only look for the
    # release version of SDL, feel free to make this also look for debug
    # modes depending on the cmake build target.
    set(SDL_FOLDER ${CMAKE_CURRENT_SOURCE_DIR}/libs/sdl-1.3
        CACHE STRING "Path to SDL 1.3" FORCE)
    find_library(SDL_LIBRARY
        NAMES SDL-1.3.0 SDL
        PATHS ${SDL_FOLDER}
        PATH_SUFFIXES local/lib VisualC/SDL/Release
        NO_DEFAULT_PATH
    )
    find_library(SDLMAIN_LIBRARY
        NAMES SDLmain
        PATHS ${SDL_FOLDER}
        PATH_SUFFIXES local/lib VisualC/SDLmain/Release
        NO_DEFAULT_PATH
    )

    # we also need to find the system's OpenGL version
    find_package(OpenGL REQUIRED)

    # on OS X we also have to add '-framework Cocoa' as library.  This is
    # actually a bit of an hack but it's easy enough and reliable.
    set(EXTRA_LIBS "")
    if (APPLE)
        set(EXTRA_LIBS ${EXTRA_LIBS} "-framework Cocoa")
    endif()

    # our own include folder and the SDL one are additional folders we
    # want to have on our path.
    include_directories(
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${SDL_FOLDER}/include
    )

    # Now we define what makes our executable.  First thing is the name,
    # WIN32 is needed to make this a Win32 GUI application, MACOSX_BUNDLE
    # activates bundle mode on OS X and the last two things are our source
    # and header files this executable consists of.
    add_executable(
        HelloSDL
        WIN32
        MACOSX_BUNDLE
        ${SOURCES}
        ${HEADERS}
    )

    # Lastly we have to link the OpenGL libraries, SDL and the cocoa
    # framework to our application.  The latter is only happening on
    # OS X obviously.
    target_link_libraries(
        HelloSDL
        ${OPENGL_LIBRARIES}
        ${SDL_LIBRARY}
        ${SDLMAIN_LIBRARY}
        ${EXTRA_LIBS}
    )

Now in theory this should be enough to make everything work.
Unfortunately it's not exactly that easy.  In fact, it's that easy on
in case SDL is installed globally, but usually it's not.  Depending on the
operating system different things have to happen now.  Why?  Because SDL
is dynamically linked to your application.  You want dynamic linking for
two reasons: first because it's easier licensing wise as SDL is LGPL
licensed.  Secondly because it's the preferred way to deal with this
problem.

Now with dynamic linking it means we have to have the dynamic library
somewhere on the application's path.  On linux it usually means that the
library is globally installed somewhere in “/usr/lib”.  On Windows and OS
X that is a no-go.  The solution on Windows is to copy the DLL next to
your executable:

.. sourcecode:: cmake

    if(WIN32)
        set(VS_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_CFG_INTDIR})
        add_custom_command(TARGET HelloSDL POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${SDL_FOLDER}/VisualC/SDL/Release/SDL.dll ${VS_OUTPUT_DIR}/SDL.dll)
    endif()

How do we solve this problem on OS X?  On OS X applications are supposed
to ship their dynamic libraries inside the “.app” bundle in the
“Frameworks” folder.  Because making a library behave so that it loads
properly from such a “Framework” folder is totally non-obvious I wrote a
script that automates that process.  You can get it from my github
repository: `frameworkify.py
<https://github.com/mitsuhiko/frameworkify/raw/master/frameworkify.py>`__.
Just drop it into the `scripts/` folder and add this to your
“CMakeLists.txt”:

.. sourcecode:: cmake

    if(APPLE)
        set(BUNDLE_BINARY
            ${CMAKE_CURRENT_BINARY_DIR}/HelloSDL.app/Contents/MacOS/HelloSDL)
        add_custom_command(TARGET HelloSDL POST_BUILD
            COMMAND python scripts/frameworkify.py ${BUNDLE_BINARY}
            ${SDL_LIBRARY})
    endif()

This script will modify your application to be search for the given
dynamic library in the “Frameworks” folder and also copy the dylib into
that folder automatically for you.

So how does this work on Linux?  I don't really know what's the best
deployment method on Linux is.  Probably installing SDL-1.3 globally and
hoping for the best.  Alternatively you could drop it into a folder and
write a wrapper bash script that sets the `LD_LIBRARY_PATH` environment
variable so that Linux looks for dynamic libraries in that folder before
executing the actual binary.

Now that we have a “CMakeLists.txt” file we can use the `cmake` command to
create makefiles or Visual Studio solutions.  If you are on Linux or OS X
all you need is this::

    $ cmake .

If you are on Windows this would work too, but I recommend creating the
Visual Studio solution in a separate folder as Visual Studio is creating a
bunch of files you probably want to get rid of every once in a while.  And
there it's easiest if you can just delete a folder and rerun cmake.  This
is how you do it::

    > mkdir vs
    > cd vs
    > cmake ..

A C-ish C++
-----------

I love C and I would love to use C in these examples.  Unfortunately
Microsoft's C support is abysmal and stuck in the early 90's.  As a result
of this I got with the C-ish version of C++ instead in these examples.
Also to keep it short and concise I am using global variables and a whole
bunch of stuff you really shouldn't do in an actual application.

However it does give you an idea of how stuff works, so bear with me and
ignore for a moment that you are looking at ugly C++ code doing things you
wouldn't do yourself.  In fact, I encourage you to immediately convert
what you're looking at into nicely structured code.

About Magic Mains
-----------------

Before I explain what this headline is about, drop the following lines
into your `hello.hpp` file:

.. sourcecode:: c++

    #ifndef INC_HELLOSDL_HELLO_HPP
    #define INC_HELLOSDL_HELLO_HPP

    /* Include windows.h properly on Windows */
    #if defined(WIN32) || defined(_WINDOWS)
    #  define WIN32_LEAN_AND_MEAN
    #  define NOMINMAX
    #  include <windows.h>
    #endif
    
    /* SDL */
    #include <SDL.h>
    #include <SDL_opengl.h>
    #ifndef HELLO_MAGIC_MAIN
    #  undef main
    #endif
    
    #endif

Now that you saw the header, what is this crazy `HELLO_MAGIC_MAIN` thing
there about?  Let me explain.  On many operating systems the way the C
standard library works is that it defines an entrypoint for your operating
system's executable loader which then invokes a special method named
`main`.  Turns out that depending on the environment you are on, this
might be slightly different.  On windows for example, a GUI application
has a different main method: `WinMain`.  Also on OS X (due to the fact that
a lot of the functionality you need to bootstrap an OpenGL application is
available in Cocoa which is written in Objective-C) you won't be able to
write the main function yourself as SDL will have to perform some hackery
before your code is executed.

So where is all the sanity in this madness?  The SDL developers came up
with a nice hack to make this work.  They define a `main` macro which
replaces the token `main` with a different name.  Then they provide a
separate library called `SDLmain` which has the actual `main` (or
`WinMain`) function which the invokes your main function (which magically
got renamed thanks to the `main` macro).

Now this work fine, but I tend to hate macros with very generic names
(like `min` or `main` as you might have a method or member with the same
name).  Because of this what I do when working with SDL is by default
undefining this special `main` macro again and only keeping it defined for
the one `.cpp` / `.c` file which has the actual main method.

As a logical result will the `hello.cpp` file have to define the
`HELLO_MAGIC_MAIN` macro in order to not undefine the `main` macro:

.. sourcecode:: c++

    #define HELLO_MAGIC_MAIN
    #include <hello/hello.hpp>

    int main(int argc, char **argv)
    {
        /* TODO */
        return 0;
    }

I think it's important to point out how this hackery works and how to keep
it under control.  If you don't care, just remove the `HELLO_MAGIC_MAIN`
define in the `.cpp` file and the `ifndef` block in the header.

This is also the reason we want to include the “windows.h” file outselves
with the `WIN32_LEAN_AND_MEAN` and `NOMINMAX` options.  It includes only
the smallest set necessary and does not define the entirely pointless
`min` and `max` macros which will otherwise conflict with `std::min` and
`std::max` in a very bad way.

At that point we should be able to compile the project (with Visual Studio
or by typing `make`).  It won't do anything useful yet but at least it
should run without complaining.

Hello SDL
---------

So much work for nothing?  Now let's try to get something on our screen.
The first thing we have to do when we boot up is initializing the features
of SDL we care about.  Because we also want OpenGL we will have to create
an OpenGL context and a window to draw into.

This is what your startup code will most likely look like most of the
time:

.. sourcecode:: c++

    static const int window_width = 800;
    static const int window_height = 600;

    static SDL_Window *win;
    static SDL_GLContext ctx;

    static void critical_error(const std::string &title, const std::string &text)
    {
    #if defined(WIN32) || defined(_WINDOWS)
        MessageBoxA(0, text.c_str(), title.c_str(),
            MB_OK | MB_SETFOREGROUND | MB_ICONSTOP);
    #else
        std::cout << "Critical error: " << title << std::endl << text << std::endl;
    #endif
        exit(1);
    }

    void mainloop()
    {
        /* TODO */
    }

    int main(int argc, char **argv)
    {
        if (SDL_Init(SDL_INIT_VIDEO) < 0)
            critical_error("Could not initialize SDL", SDL_GetError());
        
        SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
        SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
        SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
        SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
        SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
        SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 8);
        
        win = SDL_CreateWindow("Hello SDL",
            SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,
            window_width, window_height,
            SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);
        if (!win)
            critical_error("Unable to create render window", SDL_GetError());

        ctx = SDL_GL_CreateContext(win);
        SDL_GL_SetSwapInterval(1);

        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0.0f, window_width, window_height, 0.0f, 0.0f, 1000.0f);

        glMatrixMode(GL_MODELVIEW);

        mainloop();

        SDL_GL_DeleteContext(ctx);
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 0;
    }

So what does this monster of a piece of code do?  Ignoring the error
helper function above we try to do the following things:

1.  initialize SDL with video support.  This will do some magic inside SDL
    so that we can use the video hardware.
2.  SDL can configure the operating system's OpenGL driver so this is what
    we want to do next.  `SDL_GL_MULTISAMPLEBUFFERS` tells OpenGL that we
    are interested in multisampling antialiasing and
    `SDL_GL_MULTISAMPLESAMPLES` specifies how many samples we want (in
    this case 4.  The higher the nicer but also the more expensive).  We
    are also interested in double buffering, a 24bit depth buffer and
    evenly distributed bits for each color channel.
3.  Then we create a window to render into.
4.  After that we create an OpenGL context and activate vsync.
5.  Lastly we configure OpenGL's projection matrix to be orthographic,
    with the origin in the top left corner and a general resolution of 800
    by 600 pixel as internal coordinate system.  Assuming you want to do
    2D graphics, this is a good starting point.
6.  Then we invoke the `mainloop` and after this stopped, we shut down the
    SDL stuff again.

Now at that point we still don't see anything.  If we would run it, we
might see a window flashing for a splitsecond, but that's it.  So what we
really need to do is to have a loop that is running for as long as the
user wants to see something.

The Mainloop
------------

Now this is where it gets interesting.  The mainloop (or event loop) is
where the magic is happening in a game.  A general main loop does a couple
of things.

-   For as long as the mainloop is running:
    
    1.  While there are events in the queue handle events.
    2.  Update the game state
    3.  Render the current state
    4.  Swap the buffers and display the rendered image on the screen.

That much is clear and probably obvious to you.  So how do event loops
look in pratice?  There are two main approaches to mainloops.  Either your
main loop runs at a fixed speed or everything what is happening for each
state update takes the elapsed time into account.  The first thing is what
games did in the old days when computers where slow and predictable, the
second one is what you want to do these days which is why we only talk
about the latter here.

The idea is that you take a high performance counter in your computer and
measure the time at the beginning of the frame.  Then you subtract from
this timestamp the timestamp of the last iteration and divide it by the
frequency of your counter.  The value you get is a floating point value
with the time in seconds since the last frame.  This timedelta can then be
used for all compuations.

Lastly you don't want to render as fast as possible, you only want to
render as fast as useful.  That means you want to wait a tiny fraction of
the second to give the operating system an indication that you are now
done doing something useful and that it might give another process a shot
now.  If we don't give the operating system that indication it will cause
our application to consume 100% CPU at all times even if it's not
necessarily what we want.

Without further ado, this is our mainloop template:

.. sourcecode:: c++

    static bool running = true;

    void handle_event(SDL_Event &evt, float dt)
    {
        if (evt.type == SDL_QUIT)
            running = false;
    }

    void update(float dt)
    {
        /* TODO */
    }

    void render()
    {
    }

    void mainloop()
    {
        SDL_Event evt;
        uint64_t old = SDL_GetPerformanceCounter();

        while (running) {
            uint64_t now = SDL_GetPerformanceCounter();
            float dt = (now - old) / (float)SDL_GetPerformanceFrequency();
            old = now;

            if (dt > 0.1f)
                dt = 0.0016f;

            while (SDL_PollEvent(&evt))
                handle_event(evt, dt);

            if (dt > 0.0f)
                update(dt);
            render();

            SDL_GL_SwapWindow(win);
            SDL_Delay(1);
        }
    }

This should be mostly straightforward, but what is this `if` condition in
there that checks if `dt` is greater `0.1f`?  That's a hack that allows
you to respond to breakpoints or halted executions without destroying your
simulation completely.  Consider you hit a breakpoint and you continue the
execution after 10 seconds.  There is no way your calculation which
normally ends in way less than 16 milliseconds will be able to be still
correct if the time between two frames is suddenly 10 seconds.  In fact,
you don't even want to have the 10 seconds stopped time simulated.  So we
will just assume in that case that the time between the last frame and the
current frame is around 16 milliseconds which is the time you have between
frames if you're rendering at 60 frames per second.

The second `if` in there which might be funky is the one around the
`update` call.  The idea is that if we're rendering faster than the
resolution of our counter we will get back a delta time of zero.  In this
case there is absolutely no update to be done and we can skip a whole
bunch of updating logic.  In theory this should not happen because we have
vsync enabled which caps the update rate at our monitor's refresh rate,
but someone might have forced vsync to off in the driver settings.

A Word on Timing
----------------

How does timing work on a computer?  If we look at an Intel x86 processor
there are different components in the computer that can be used for timing
purposes.  The easiest one is the PIT (Programmable Interval Timer).  The
PIT consists of an oscillator and three frequency dividers and runs at
1.193182 MHz.  It's nontrivial to use and gives a very low resolution
of time and usually drives of about a second each day.  It's an ancient
piece of technology and a leftover mostly.  Modern computers also provide
the HPET (High Precision Timer) as an alternative.

Now your computer also has a realtime clock on your chip.  This however is
even worse than the PIT as the clock by itself is very slow to read and
and only gives a resolution of a second.  It however similar to the PIT
also has a mode where it can trigger an interrupt every once in a while so
could also be used for timing purposes.

Your operating system most likely uses a combination of RTC/PIT or if
supported by your hardware and operating system a combination of RTC/HPET.

Now also a while ago some folk at Intel figured that this was a huge hack
to do timing and added the RDTSC register.  It's a 64bit register which is
incremented every time the CPU executes an instruction.  As it's stored in
a register it's also incredible quick to query.  This however predates the
widespread use of multicore systems and RDTSC counts on a per-core basis.

So if your thread alternates between different cores you will get wrong
values.  Also it's very hard to figure out the frequency of your processor
reliably which is why you don't want to query RDTSC yourself.  Depending
on the operating system your operating system will account for this and
provide some methods.

On Windows there is the `QueryPerformanceCounter
<http://support.microsoft.com/kb/172338>`_ function which is used by the
SDL one used above which accounts for the frequency problem by taking
frequency changes into account.  What this however does not do is ensuring
that you're running on the same core always which is something you will
have to do:

.. sourcecode:: c++

    #if defined(WIN32) || defined(_WINDOWS)
    ULONG_PTR affinity_mask;
    ULONG_PTR process_affinity_mask;
    ULONG_PTR system_affinity_mask;

    if (!GetProcessAffinityMask(GetCurrentProcess(),
                                &process_affinity_mask,
                                &system_affinity_mask))
        return;

    // run on the first core
    affinity_mask = (ULONG_PTR)1 << 0;
    if (affinity_mask & process_affinity_mask)
        SetThreadAffinityMask(GetCurrentThread(), affinity_mask);
    #endif

On Linux and OS X the situation is differently.  There the operating
systems provide monolithic clocks that are fast to query and have a very
high precision.  Behind the scenes these are doing all the magic in
delivering the best precision possible.  The downsides is that most clocks
by default might go back in time (sync with internet time, DST etc.).
Fortunately SDL's performance counter query functions will use the
`MONOTONIC` clocks instead.  These are made to always run forward in time.

On these operating systems it's pointless to pin the thread to one
processor as the operating system by itself will provide a clock that is
monotonic and takes switching between cores into account.

Drawing Something
-----------------

Now it's time to draw something.  Because this tutorial is already quite
long and this is more about SDL than OpenGL we will just cause the screen
to be filled with one color until the application closes:

.. sourcecode:: c++

    void render()
    {
        glClearColor(0.3f, 0.6f, 0.9f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
    }

Now if you start the application you should see a red window that does
absolutely nothing and will shut down when you click on the X on the top
right / top left depending on what operating system you are on.

For a general OpenGL tutorial I don't have any good recommendations for
the time being.  If you do 3D: screw the fixed function pipeline and
replace your whole stack with shaders and custom matrix and vector
classes.  It's totally worth it.  The best tutorials on the topic that are
easy to understand are about WebGL, so Google for that.  If you do 2D:
start up with wrapping the OpenGL functions to work 2D space and never
ever even call OpenGL functions in the game directly.  This makes it
possible to then easily switch to the programmable pipeline which will be
absolutely necessary if you want to target OpenGL ES 2.0.
