public: yes
tags: [sdl, opengl, ios]
summary: |
  Extending on my SDL tutorial this guide shows how one can get
  SDL 1.3 and OpenGL ES running on iOS with the help of cmake.

SDL 1.3 on iOS
==============

Personally I try to avoid Objective-C and Xcode if possible.  I am not a
fan of the language and I rather keep my stuff in a way that I can port it
to other platforms with little amount of extra work.  As such SDL 1.3 and
Cmake are ideal candidates to target iOS and still be under full control
of your stuff with simple porting possible to other platforms.

This tutorial assumes that you're in a similar boat.  I will be using SDL
1.3 here in combination with cmake as build tool.  Cmake automatically
generates Xcode projects, so you can use Xcode for the actual development
if you like to do that.  In fact, keeping xcode open for compiling is a
good idea because it automatically runs the iPhone simulator.

I personally don't pay for the yearly license currently so I run my
experiments with the simulator only currently.  You will need a developer
license from apple to upload your applications to your phone for testing.
Also as of recently SDL switched to the zlib license for 1.3 which means
it's completely free for iOS or embedded development.

What are the reasons for SDL instead of UIKit?  Your application can be
ported to Android, WebOS, the Nintendo DS or any desktop operating system
easily without having to replace large chunks of code.  The license of SDL
also allows you to modify any part of the SDL code without having to share
them which makes it easy to adjust SDL to your particular needs if you hit
a limit.

Compiling SDL 1.3
-----------------

First we need to get hold of SDL 1.3.  If you have mercurial installed,
that's straightforward::

    $ hg clone http://hg.libsdl.org/SDL sdl-1.3

Once that's done, navigate to the “Xcode-iPhoneOS/SDL” folder and open the
“SDLiPhoneOS.xcodeproj”.  While the readme tells you to just set the SDK
target, that is currently not possible.  You will have to change the SDK
to the one you want to develop with in the Project settings.  During local
development you want “iPhone Simulator 4.0”, on deployment you want
“iPhone Device 4.0”.  You can change the SDK by going to “Project -> Edit
Project Settings” and then in the “Build” tab under “Base SDK”:

.. image:: /static/blog-media/sdl-ios-menu.png
   :align: left

.. image:: /static/blog-media/sdl-ios-dialog.png
   :align: right

.. class:: clear

Afterwards just hit the “Build and Run” button and you're good to go or do
the correct thing and just build (⌘B).

Once built, you can find the “libSDL.a” file in the
“build/Debug-iphonesimulator” folder together with the headers.
Unfortunately the headers are in a full canonical folder structure
(“usr/local/include” instead of “SDL”) which would be more helpful.

What you will have to do is to move and rename a bunch of files:

-   `libSDL.a` -> libs/SDL/Debug/libSDL.a
-   `usr/local/include` -> libs/SDL/include

For local development you only need a simulator build instead of the
device one.

Creating the CMakeLists.txt
---------------------------

Once that is done, create a file called `CMakeLists.txt` next to your
`libs` folder with the following contents:

.. sourcecode:: cmake

    cmake_minimum_required(VERSION 2.8)
    project(MyApp)
    
    set(HEADERS
        include/myapp/myapp.hpp
    )
    set(SOURCES
        src/main.cpp
    )
    
    set(IOS_FRAMEWORKS
    	Foundation
    	AudioToolbox
    	CoreGraphics
    	QuartzCore
    	UIKit
    	OpenGLES
    )
    
    set(CMAKE_OSX_SYSROOT iphonesimulator4.0)
    set(CMAKE_OSX_ARCHITECTURES "$(ARCHS_STANDARD_32_BIT)")
    foreach(FW ${IOS_FRAMEWORKS})
    	set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework ${FW}")
    endforeach()
    
    include_directories(
    	${CMAKE_CURRENT_SOURCE_DIR}/include
    	${CMAKE_CURRENT_SOURCE_DIR}/libs/SDL/include
    )
    link_directories(
    	${CMAKE_CURRENT_SOURCE_DIR}/libs/SDL
    )
    
    set(MACOSX_BUNDLE_GUI_IDENTIFIER "com.mycompany.\${PRODUCT_NAME:identifier}")
    
    add_executable(
        MyApp
    	MACOSX_BUNDLE
        ${HEADERS}
        ${SOURCES}
    )
    
    target_link_libraries(MyApp SDL)
    
If you want to run it on the phone you will need to change and add a bunch
of things:

.. sourcecode:: cmake

    set(CMAKE_OSX_SYSROOT iphonedevice4.0)
    set_target_properties(${NAME} PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer: My Name")

In that case SDL will have to be built against the device and not the
simulator.  Once you're at that point, you should consider adding a switch
to your configuration.


Hello iPhone
------------

On the iPhone or other iOS devices you have OpenGL ES 2.0 to your
disposal.  Devices before the 3GS only have OpenGL ES 1.0, but these
devices are slowly disappearing so for a small project it's not worth the
hassle to support both.  The differences between those two are quite big
(the former only does fixed function, the latter only does programmable
pipeline).

To verify that everything works, create these two files:

include/myapp/myapp.hpp:

.. sourcecode:: c++

    #ifndef MYAPP_MYAPP_HPP_INC
    #define MYAPP_MYAPP_HPP_INC
    
    #include <SDL.h>
    #include <SDL_opengles.h>
    
    #endif

src/main.cpp

.. sourcecode:: c++

    #include <iostream>
    #include <cstdlib>
    #include <myapp/myapp.hpp>

    static const int screen_width = 320;
    static const int screen_height = 480;

    static SDL_Window *win;
    static SDL_GLContext ctx;


    void sdl_error_die()
    {
        std::clog << "Error: " << SDL_GetError() << std::endl;
        exit(1);
    }

    int main(int argc, char **argv)
    {
        if (SDL_Init(SDL_INIT_VIDEO) < 0)
            sdl_error_die();

        win = SDL_CreateWindow(NULL, 0, 0, screen_width, screen_height,
                               SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);
        if (!win)
            sdl_error_die();

        ctx = SDL_GL_CreateContext(m_win);
        SDL_GL_SetSwapInterval(1);

        bool running = true;
        SDL_Event event;

        while (running) {
            while (SDL_PollEvent(&event)) {
                if (event.type == SDL_QUIT)
                    running = false;
            }

            glClearColor(1.0, 0.0, 0.0, 1.0);
            glClear(GL_COLOR_BUFFER_BIT);
        }
        
        SDL_GL_DeleteContext(ctx);
        SDL_DestroyWindow(win);
        SDL_Quit();
    }

Building and Running
--------------------

To build this now you need to run cmake with the XCode generator::

    $ mkdir xcode
    $ cd xcode
    $ cmake -GXcode ..

This will generate an Xcode project inside the “xcode” folder.  Open it
and hit the “build and run” button.  If everything works the simulator
should start and show you a red window.

At that point you can operated with the device as if it was a regular SDL
target.  The accelerometer reacts as if it was a joystick and the
touchscreen sends `finger <http://wiki.libsdl.org/moin.cgi/SDL_TouchFingerEvent>`_
and `button touch <http://wiki.libsdl.org/moin.cgi/SDL_TouchButtonEvent>`_
events.  Currently the haptics support does not work on iOS so you won't
be able to vibrate the device.  However there are two ways out: you can
either provide a patch for SDL which shouldn't be too hard, or add an
objective C file yourself and send the iPhone the appropriate commands
yourself.
