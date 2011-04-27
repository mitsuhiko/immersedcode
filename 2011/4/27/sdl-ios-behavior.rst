public: yes
tags: [sdl, opengl, ios]
summary: |
  SDL 1.3 works on iOS but because the operating system is quite different
  from your average desktop OS, some things work slightly different.  This
  should give you a good overview.

SDL 1.3 Behavior on iOS
=======================

SDL 1.3 works on iOS and it's `easy to get started
<../../25/sdl-on-ios/>`_.  Unfortunately the docs are not too clear
however on how to respond to some of the iOS features and so on.  This
here should hopefully help you a little bit.


Switching OpenGL ES Modes
-------------------------

Starting with the 3GS your phone supports both OpenGL ES 1.0 and OpenGL ES
2.0.  Because these two are completely different systems you need to
decide which to use.  There are two important things here.  First of all
the functions available at compile time are different for these two
standards.  To cope with that, SDL provides you with two headers to chose
from: `SDL_opengles.h` and `SDL_opengles2.h`.  You need to include the one
you want to use yourself.

On top of that, the device will boot up in OpenGL ES 1.0 mode currently,
so if you want OpenGL ES 2.0 you need to tell SDL to give you such a
context:

.. sourcecode:: c++

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    m_win = SDL_CreateWindow(0, 0, 0, screen_width, screen_height,
                             SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);

The Statusbar
-------------

On iOS your application will have a status bar on top that shows the
carrier and battery levels.  For games you often want the extra 12 pixel
from the top and have this bar hidden.  All you need to do to hide the
status bar is passing `SDL_WINDOW_BORDERLESS` as additional flag to the
`SDL_CreateWindow` function call:

.. sourcecode:: c++

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    m_win = SDL_CreateWindow(0, 0, 0, screen_width, screen_height,
                             SDL_WINDOW_OPENGL | SDL_WINDOW_BORDERLESS |
                             SDL_WINDOW_SHOWN);

Respond to Rotation
-------------------

If you want to respond to rotation events of the phone you will need to
pass the `SDL_WINDOW_RESIZABLE` flag to `SDL_CreateWindow`.  Whenever the
device is rotated, SDL will switch width and height and fire an
`SDL_WINDOWEVENT` with the `window.event` flag set to
`SDL_WINDOWEVENT_RESIZED`:

.. sourcecode:: c++

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    m_win = SDL_CreateWindow(0, 0, 0, screen_width, screen_height,
                             SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE |
                             SDL_WINDOW_SHOWN);

Here is how you could respond to such an event:

.. sourcecode:: c++

    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_WINDOWEVENT &&
            event.window.event == SDL_WINDOWEVENT_RESIZED)
            update_opengl_viewport();
        else
            handle_event(event);
    }

Retina Display and Display Sizes
--------------------------------

The iPad supports multiple screens and the iPhone 4 has a much higher
screen resolution than older devices.  So how can you deal with that?  SDL
provides a function called `SDL_GetNumDisplayModes` that in combination
with `SDL_GetDisplayMode` will tell you the supported display modes for a
given screen.  The screen “0” is the builtin one.  On an iPhone 4 it will
spit out the high resolution, on an iPhone 3GS or iPad it will just return
a lower resolution.  SDL automatically configures the phone in a way that
it will scale to a full screen resolution for you if the size does not
match.  That way you can configure the app to have a context o 320x480 and
it will upscale to the retina resolution automatically.

Here is how `SDL_GetNumDisplayModes` works:

.. sourcecode:: c++

    int screen = 0;
    int modes = SDL_GetNumDisplayModes(screen);
    for (int i = 0; i < modes; i++) {
        SDL_DisplayMode mode;
        SDL_GetDisplayMode(screen, i, &mode);
        printf("%dx%d\n", mode.w, mode.h);
    }

Touch Events
------------

Generally the events on the touchscreen are emitted as mouse events so you
can just use that if you like.  For extra control you might however want
to use the dedicated touch API.  It reports things differently and you
will be notified about the indivdual finger motions.

There are three events to look out for: `SDL_FINGERDOWN`, `SDL_FINGERUP`,
and `SDL_FINGERMOTION`.  All of them carry the event data in the `tfinger`
attribute on the event.  The interesting fields are these:

*   `touchId` — the identifier of the touch device.  There is just one
    touch device on iOS, but you will need this information to get the touch
    state.
*   `fingerId` — the number of the finger used
*   `x`, `y`, `dx`, `dy` — the position information in its own scale.
    This is not the pixel scale, you will have to calculate this yourself.
    `dx` and `dy` are only available for `SDL_FINGERMOTION`.
*   `pressure` — the pressure applied, this is also needs to be normalized
    yourself to make use of this.

So how can you convert from the values in `x` and `y` to actually useful
values?  For this you need the actual `SDL_Touch` struct of the device
which you can get with the `SDL_GetTouch` function which returns a pointer
to the touch struct.  This struct will tell you the resolution of `x` and
`y` and of the `pressure`.

*   SDL_Touch->\ `xres` — resolution in X direction
*   SDL_Touch->\ `yres` — resolution in Y direction
*   SDL_Touch->\ `pressures` — resolution of the pressure values

The following core normalizes the touch values into the range 0-1.  You
can multiply this with the screen resolution to get actual pixel values
back.  As the touch device has a higher resolution than the actual screen
you don't want to do this when using the touchscreen as joystick
replacement.

.. sourcecode:: c++

    if (evt.type == SDL_FINGERDOWN) {
        SDL_Touch *state = SDL_GetTouch(evt.tfinger.touchId);
        float x = (float)evt.tfinger.x / state->xres;
        float y = (float)evt.tfinger.y / state->yres;
        printf("%f/%f\n", x, y);
    }

Generally speaking you really want to use the regular mouse events if all
you want to do is to select things on the screen and the touch API if you
want to work with gestures.  At the point where you work with gestures you
need to have an actual phone hooked up as the simulator cannot be used to
do that.

CMake and Info.plist
--------------------

This one is a bonus if you are using CMake.  CMake will automatically
create an Info.plist file for you so you don't have to worry about that.
But if you want to extend it, you will need to specify a different
template for this file.  Just add this to your CMakeLists.txt:

.. sourcecode:: cmake

    set_target_properties(YourTarget PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer"
    )

And then provide an Info.plist.in file like this:

.. sourcecode:: xml

    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
      "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>English</string>
        <key>CFBundleExecutable</key>
        <string>${MACOSX_BUNDLE_EXECUTABLE_NAME}</string>
        <key>CFBundleGetInfoString</key>
        <string>${MACOSX_BUNDLE_INFO_STRING}</string>
        <key>CFBundleIdentifier</key>
        <string>${MACOSX_BUNDLE_GUI_IDENTIFIER}</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleLongVersionString</key>
        <string>${MACOSX_BUNDLE_LONG_VERSION_STRING}</string>
        <key>CFBundleName</key>
        <string>${MACOSX_BUNDLE_BUNDLE_NAME}</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>${MACOSX_BUNDLE_SHORT_VERSION_STRING}</string>
        <key>CFBundleSignature</key>
        <string>????</string>
        <key>CFBundleVersion</key>
        <string>${MACOSX_BUNDLE_BUNDLE_VERSION}</string>
        <key>CSResourcesFileMapped</key>
        <true/>
        <key>NSHumanReadableCopyright</key>
        <string>${MACOSX_BUNDLE_COPYRIGHT}</string>
        <!-- custom stuff here -->
        <key>UIStatusBarHidden</key>
        <true/>
    </dict>
    </plist>

The file above overrides the `UIStatusBarHidden` value which will hide the
status bar during startup of the application.  There is a lot more that
can be customized in the Info.plist file, just refer to the apple
documentation for more information.
