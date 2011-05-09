public: yes
tags: [c++, thoughts]
summary: |
  My personal set of features I use of C++ and a few reasons for why
  and why not other parts.  YMMV

My Favorite C++ Subset for Game Development
===========================================

I went through a couple of iterations with my latest attempts to get into
game development and ended up switching programming languages and
technologies multiple times.  Due to the fact that I actually want to
understand how things work on all layers I prefer if I can stick as close
to the metal as possible, so the choice was pretty much C or C++ as
writing bindings for all kinds of low-level libraries is painful usually.

Also the amount of game development resources for C and C++ are huge
compared to *any* other programming language with the exception of maybe
actionscript.

I did decide for a certain subset of C++ instead of doing C directly for
two very simple reasons: a) C sucks in Visual Studio, b) the STL is
actually pretty damn useful for games.

Word of warnings first: I am still new to all this stuff, so that is my
unprofessional personal opinion.

Features I Love
---------------

First the list of C++ that I absolutely adore and can only recommend to
actually use:

STL
~~~

The majority of the stuff in the STL is very useful for game development
and the API is mostly exception less.  I know that if you are a
professional game development studio you might want to use something else
than STL instead, but EA wrote a (MIT licensed) STL inspired library
called EASTL which provides most of the same functionality with a
different allocation model.  The STL is certainly not without it's faults,
but the criticism there is on a very high level.

Generally you should ignore that iostreams exist, these things are
horrible.  Also strings in general are intended to be efficently
copy-constructed, but I strongly recommend only having const string
references around.  The non-constant item access operators of strings will
internally have to copy the data over, even if you only want to read from
the string.

Operator Overloading
~~~~~~~~~~~~~~~~~~~~

For game developers, matrix and vector classes are a must and these things
are pretty horrible to use if you cannot overload operators.  There are
already tons of vector and matrix libraries around which are easy to use
so you don't have to do that yourself.  I personally prefer `glm
<http://glm.g-truc.net/>`_ for the very simple reason that I use OpenGL a
lot and the glm library is based on the vector and matrix types and
operations available in GLSL.  It's constantly updated and has every
methods you might ever need.

Namespaces
~~~~~~~~~~

C++'s namespaces are great.  I don't use them extensively (so only one or
two levels deep) but I never ever declare something outside of a
namespace.  Something I personally found very useful is ``using`` other
stuff into my project namespace if it helps portability or switching
depending libraries at one point.

For instance I have something like this in my code:

.. sourcecode:: c++

    #include <tr1/functional>

    namespace myproj {
        using std::tr1::function;
        using std::tr1::bind;
    }

This has the advantage that when I move with this codebase to a platform
where the tr1 stuff is not available, I can just hook in the
implementations from boost and use those instead.  Also if stuff ever
moves into the normal ``std`` namespace it's just a matter of updating
this file and having some `ifdef` magic around the using part.

Sadly you cannot rename things this way.  Typedefs are also only an option
if you are not dealing with templates, as current C++ versions don't allow
you to typedef templates partially.

TR1 / C++ 2011 Features
~~~~~~~~~~~~~~~~~~~~~~~

There is a ton of stuff new to C++ that is very helpful and not widely
used yet.  Not everything in there is useful for every situation, but a
lot is a good thing to have.  The parts I find very useful are
`std::tr1::function`, `std::tr1::mem_fn`, `std::tr1::bind` which is the
most painless way these days to have callbacks to regular or member
functions, `std::tr1::unordered_map` which is essentially a hashtable, and
the new random generator header which provides a mersenne twister random
generator.

A bunch of stuff from C++ 2011 would be pretty useful such as the new
rvalue references and move constructors, but I am afraid these will be
unavailable for a few years to come.

Macros / The CPP
~~~~~~~~~~~~~~~~

I just love the C preprocessor.  I know it has faults, but it makes a lot
of code much cleaner to look at.  Generally I limit macros to `.cpp` files
and if I need a macro in a `.hpp` file I prefix it with my namespace.

I love keeping my code within ~80 to 100 characters a line max, and macros
are often a nice way to keep many calls or deeply nested loops simple.
For instance it's not uncommon to have loop that go over three dimensional
coordinates where the two outer loops have no other statement in the body
than the next loop.  A simple macro can simplify this and remove two
levels of indentation and improve readability.

Especially in games where you have to do an operation multiple times into
all different directions macros are a godsend.  For example this snippet
comes from my voxel engine and performs a basic Air->Surface test to see
if it should create a polygon for a voxel.  I removed a bunch of code
here that handles textures and memory management, but the core principle
is the same and shows quite nice how macros can be used:

.. sourcecode:: c++

    /* helper macro to simplify three level iterations over blocks
       that should go into a VBO */
    #define FOR_ALL_BLOCKS_IN_VBO(X, Y, Z, x, y, z) \
        for (int X = x; X < x + (int)vbo_dim(); X++) \
        for (int Y = y; Y < y + (int)vbo_dim(); Y++) \
        for (int Z = z; Z < z + (int)vbo_dim(); Z++)

    void pd::map::update_vbo(pd::map::vbo_entry *entry, int sx, int sy, int sz)
    {
        pd::cube_maker maker(1.0f);
    
        float off_x = -(int)m_dim_x / 2.0f;
        float off_z = -(int)m_dim_z / 2.0f;
    
    #define TEST_SIDE(Face, X, Y, Z) \
        if (get(X, Y, Z)->transparent()) { \
            maker.add_##Face##_face((float)(off_x + x), \
                                    (float)y, (float)(off_z + z)); \
            sides++; \
        }
    
        FOR_ALL_BLOCKS_IN_VBO(x, y, z, sx, sy, sz) {
            int sides = 0;
            const pd::block *block = get(x, y, z);
            if (block->transparent())
                continue;
    
            TEST_SIDE(left, x - 1, y, z);
            TEST_SIDE(right, x + 1, y, z);
            TEST_SIDE(bottom, x, y - 1, z);
            TEST_SIDE(top, x, y + 1, z);
            TEST_SIDE(far, x, y, z - 1);
            TEST_SIDE(near, x, y, z + 1);
        }
    
        maker.update_or_init_vbo(entry->vbo);
        entry->dirty = false;
    }

I used something very similar to implement a ray->axis aligned bounding
box intersection test which also normally would require pretty much the
same code for each of all 6 sides of the AABB.

Things I do not use
-------------------

And here a range of features I chose not to use.

References
~~~~~~~~~~

I do use references, but in a very limited form.  I only use constant
references or references when the language semantics require them
(operator overloading mainly).  There are two reasons for this.  The first
one is that references work badly with containers and that a lot of
functionality with references requires exceptions.  More importantly
references don't really give you anything.

A common argument for references is that they cannot be null.  This
however is not true, because if you dereference a pointer and pass it to a
function expecting a reference, this will nicely cause a reference with
the value of 0 end up in the function.  Either way you will get a crash as
soon as you try to do something with this reference, but you can no longer
test if the reference is indeed zero.

Also references absolutely must be initialized from constructors and if
you work without exceptions as I do, constructors are usually very
lightweight and the actual initialization might happen in another function
later, so references in classes are a no-go.

Mutable references in functions are especially bad because from the caller
side you can no longer see if something might modify a value.  “Out
parameters” I always implement using pointers instead.  That way you can
also pass a null-pointer to tell the code that you are not interested in
the value:

.. sourcecode:: c++

    void get_screen_size(int *width, int *height)
    {
        if (width)
            *width = m_width;
        if (height)
            *height = m_height;
    }

Exceptions
~~~~~~~~~~

That should go without saying.  Exceptions are probably okay if they are
fatal, but then what's the point in using them.  There are three reasons
for not using C++ exceptions': first of all they don't work with C which
makes it hard to expose a C ABI for your objects, secondly they unwind the
stack and this is a very expensive and hard to predict.  Lastly all your
code has to be exception safe for this and at the very least all the C
APIs are not.  Making them exception safe requires wrappers that either
add overhead or are hard to write, or a combination of both.

So really, for games exceptions don't add much, so why bother.

Copy Constructors / Assignment Operators
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Unless I have a class that is suppose to work like a value type (think
vectors etc.) I keep copy constructor and assignment operator private.  I
do not use the noncopyable pattern because it yields horrible error
messages but keep a macro around that adds the necessary dummy
declarations.  If I do have a class I want to clone, I add a clone method
to it.  Partially also because I really hate the idea of having code that
looks like this:

.. sourcecode:: c++

    my_class *foo_clone = new my_class(*foo);

This tells the intentions much clearer:

.. sourcecode:: c++

    my_class *foo_clone = foo->clone();

Using Namespace / ADL
~~~~~~~~~~~~~~~~~~~~~

Of course I cannot get rid of argument dependent lookup (and also don't
really want to), but I can make my life much easier by not depending on it
for regular method calls and stuff like that.  Obviously operator
overloading often still depends on it, so that's a valid use case.

I never, ever use `using` besides pulling something *into* a namespace
(eg: alias `std::tr1::unordered_map` to `myproj::unordered_map`).  Even in
the C++ files I explicitly write the namespace in front of everything.
I do this because my C++ code is all lowercase with underscores, even for
classes.  That way you can avoid a lot of confusion by being explicit.

My code looks something like this usually:

.. sourcecode:: c++

    pw::unit::unit(const unit_spec *spec, pw::player *player, int x, int y)
    {
        m_spec = spec;
        m_state = spec->default_state();
        m_used = false;
        
        m_health = 1.0f;
        m_fuel = spec->max_fuel;
        m_amunition = spec->max_amunition;
        m_armor = spec->armor;

        m_pos = pw::ivec2(x, y);
        m_player = player;
    }

Because I do keep everything prefixed with the namespace, I am choosing
very short namespace names.  I know that these might collide, but
honestly, that two things use the same namespace *and* name is very
unlikely.  I usually go with two to six letters there.

Boost
~~~~~

Boost gives me a little bit too much power.  And when I am sick with power
I tend to abuse it.  The last two C++ game-ish projects I ended up rewriting
half finished code over and over again because I found a new trick in the
boost toolbox to make it more elegant.  Also, a lot of boost makes your
compile times take a really bad hit, so also not exactly something to aim
for, especially with games where you already have to wait a bit for the
whole thing to start up.

Things I Use Mostly
-------------------

Where my patterns are mostly in line with what I am suppose to do
according to modern C++ books.

Constructors
~~~~~~~~~~~~

I obviously do use constructors, but when I have constructors that might
fail and I have to respond to them, I break up the constructor into three
things: a minimal, inlined constructor, a initialization method and a
factory method that combines the first with a `new` operator and the init
call.  If something fails, `0` is returned and memory is freed up.  That
keeps the common case simple.

Constructors in C++ make a lot more sense if you keep in mind how they
would look like in C.  The following C++ code:

.. sourcecode:: c++

    my_class *obj = new my_class(1, 2, 3);

Really maps to this idom in C:

.. sourcecode:: c

   struct my_class *obj = malloc(sizeof(obj));
   my_class_initialize(obj, 1, 2, 3);

As such the constructor is not responsible for allocating, it's
responsible for filling it with sensible defaults.  And you don't do that
in C either, what you do is usually moving all of that code into a
function that also allocates the object.  And you can do this with C++
too:

.. sourcecode:: c++

    class my_class {
    public:
        my_class() { m_x = 0; m_y = 0; }
        bool init(int x, int y)
        {
            if (x < 0 || y < 0)
                return false;
            m_x = x;
            m_y = y;
            return true;
        }

        static my_class *create(int x, int y)
        {
            my_class *rv = new my_class();
            if (rv->init(x, y))
                return rv;
            delete rv;
            return 0;
        }

    private:
        int m_x;
        int m_y;
    };

Also with that extra init call you can have one initializer call another
one, and you can use virtual methods which is not possible with
constructors.  Much win there.

I noticed however that the majority of my classes will never fail in the
constructor or fail so badly that I have to kill the game anyways.  This
might change once I have a game that needs to deal with information
downloaded from the network where I can no longer trust that things look
in a certain way.  Right now however, that's the way to go for me
personally.

Destructors
~~~~~~~~~~~

Destructors are amazing.  Not because they are guaranteed to be executed,
but because you are in tight control of the time when they are triggered.
And this makes a few things in C++ possible that are completely impossible
in other languages.  For as long as you are not passing your objects to
other threads you can use the constructor/destructor combination to memory
manage resources on the graphics device (textures, VBOs, FBOs, shaders
etc.).  That's just amazing and makes very clean code.

What I do not use are placeholder objects where the only purpose of the
object is to lay around on the stack and to trigger code in the
constructor/destructor.  That just makes code that is hard to understand.
And if you don't have exceptions, there is no need for that anyways.

Overloading
~~~~~~~~~~~

I only overload by argument count, not by argument type with the notable
exception of method templates if I do use them.  There are just too many
ways where you could get burned.  Especially with all the implicit
constructors that exist there is too much confusion.  For instance a
method with the same name for an integer and an `std::string` is not
necessarily safe as `std::string` also accepts a `const char *` as
implicit constructor and this is ambiguous for the number 0.

RTTI / C++ Style Casts
~~~~~~~~~~~~~~~~~~~~~~

I do use a little bit of RTTI, mainly `dynamic_cast` in a handful of
situations to augment templates.  Generally I do not use enough C++ style
casts, but I really should do more of them.  I rarely cast anything else
than primitives though, so I don't mind too much there.

What I wish I could Use
-----------------------

I can't wait for the stuff in C++ 2011.  Finally a for loop construct that
does not me to tear out my eyes, ranges, the move semantics and rvalue
references.  So much cool stuff in there that is actually useful for most
applications out there.  Also finally a good use for the `auto` keyword as
well.
