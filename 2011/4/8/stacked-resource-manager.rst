public: yes
tags: [c++, opengl, resources]
summary: |
  Tired of manually managing resources?  Have a look at this ridiculously
  simple way to handle resource management in a C++ game project.

A Stacked Resource Manager
==========================

Independently of if you are using C, C++, C# or any other language out
there for your game, the memory and resource problem will come up.
Because you have to manage resources that are stored on the graphics
device you cannot just use your language's memory management concept the
way you are used to do that.  Loading images takes them, converting them
too, and then you have to upload them to a separate device.  When it's no
longer needed you will have to delete it from there.

What's worse is that OpenGL context's are bound to a thread, so you can't
just clean up remote resources in any other thread.  So what does this
mean in practice?  For a very basic game that does not use streaming or
some other fancy methods you will want to do something like this:

-   when loading a level or something new, you remember the currently
    loaded resources.
-   you start loading all the new resources that are necessary for this
    level.
-   when done loading you run the game code.
-   at the end of the level you get rid of all the resources that were
    loaded for this level.

So essentially this thing would work similar to a key/value store with
multiple levels.  When loading up the game you immediately load the
resources you always need (fonts, debug images, GUI shaders etc.).  When
you are entering a new map you push a new layer on that key/value store
and start feeding it with new data.  When done with the level, you pop the
highest level from the store and you are back to where you started.

Resource Template
-----------------

Now in order to make resource loading really simple we will have to create
a baseclass for all our resources.  This baseclass has a virtual
destructor and an internal reference to the resource manager that created
it.  It's a friend of the actual resource manager so that the resource
manager can change the `m_resmgr` field.

The idea is that you can create an instance of a resource the traditional
way and no resource manager is attached, or you create an instance through
the resource manager and the resource manager is attached to the resource
itself.  That way we can easily figure out if something is going to be
released by the resource manager of it it's supposed to be deleted by
hand.  This can be a huge time safer when debugging.

This is what this resource baseclass looks like:

.. sourcecode:: c++

    class resource_manager;

    class resource_base {
    public:
        resource_base() { m_resmgr = 0; }
        virtual ~resource_base() {}
        bool managed() const { return m_resmgr != 0; }
        resource_manager *resmgr() { return m_resmgr; }
        const resource_manager *resmgr() const { return m_resmgr; }

    private:
        friend class resource_manager;
        resource_manager *m_resmgr;
    };

Something that is not obvious from this code is that subclasses will also
have to provide a static method on the class called `load_as_resource`
which takes a string as only argument.  This is what the resource manager
will use for loading later.  Assuming we want to extend the `texture
class <../../7/sdl-surface-to-texture/>`_ to support loading as a
resource, we would modify the class like this:

.. sourcecode:: c++

    class texture : public resource_base {
        /* ... */

        static texture *load_as_resource(const std::string &filename)
        {
            SDL_Surface *img = load_image("ball.png");
            texture *rv = texture_from_surface(img);
            SDL_FreeSurface(img);
            return rv;
        }
    }

Resource Manager API
--------------------

The resource manager itself is just a nice wrapper around a vector of
maps that map the string that is passed to `load_as_resource` to the
return value of that method.  As you might have guessed we want to use a
template for the loading method.  The intended used for this resource
manager then will look like this:

.. sourcecode:: c++

    resource_manager resmgr;

    class level {
    public:
        level()
        {
            resmgr.push();
            m_ball = resmgr.get<texture>("textures/ball.png");
            m_paddle = resmgr.get<texture>("textures/paddle.png");
        }

        ~level()
        {
            resmgr.pop();
        }

    private:
        texture *m_ball;
        texture *m_paddle;
    };

So what does this give use over directly creating the texture in the
level constructor ourselves and then deleting it in the destructor?
Imagine you want to create a bunch of soldiers.  The soldier class could
just request the texture in the constructor and if it was already loaded
(because it's in the resource manager) it will just return the same
object:

.. sourcecode:: c++

    class soldier {
    public:
        solider()
        {
            m_texture = resmgr.get<texture>("textures/soldier.png");
        }

    private:
        texture *m_texture;
    };

Now this soldier does not have to manage the memory for the texture at
all.  The resource manager does that for us (or the class that controls
the resource manager).  That way we can create a bunch of soldiers and we
can even use the automatically created copy constructor of this class to
create a bunch of clones from it if we feel like it, without having to be
afraid of double-deleting stuff.

Resource Manager Implementation
-------------------------------

And this is how the resource manager implementation could look like:

.. sourcecode:: c++

    #include <cassert>
    #include <map>
    #include <vector>
    
    class resource_manager {
    public:
        resource_manager()
        {
            push();
        }

        ~resource_manager()
        {
            pop();
        }

        void push()
        {
            m_stack.push_back(std::map<std::string, resource_base *>());
        }

        void pop()
        {
            std::map<std::string, resource_base *> &v = m_stack[m_stack.size() - 1];
            std::map<std::string, resource_base *>::iterator iter;
            for (iter = v.begin(); iter != v.end(); ++iter)
                delete iter->second;
            m_stack.pop_back();
        }

        size_t stack_size() { return m_stack.size(); }

        template <class T>
        T *get(const std::string &filename)
        {
            std::map<std::string, resource_base *>::iterator iter;
            for (int i = m_stack.size() - 1; i >= 0; i--) {
                iter = m_stack[i].find(filename);
                if (iter != m_stack[i].end()) {
                    T *ptr = dynamic_cast<T *>(iter->second);
                    assert(ptr);
                    return ptr;
                }
            }
            T *rv = T::load_as_resource(filename);
            rv->m_resmgr = this;
            m_stack[m_stack.size() - 1][filename] = rv;
            return rv;
        }

    private:
        std::vector<std::map<std::string, resource_base *> > m_stack;
    };

As you can see the implementation is very basic.  We have an internal
vector of maps.  There are methods to push and pop new maps to and from
this list.  By default we start with one empty map.  The key of each of
these maps is the string that is also passed to the `load_as_resource`
static method of the resource class we want to load.

When we pop a layer from the resource manager we also invoke the
destructor for each object that was stored on that layer.  The `get<T>`
method itself walks the vector in reverse order and tries to see if there
is already an object with the given key present.  If it finds one it will
dynamically cast it to the expected type and return it.  This assumes that
keys are not reused for different types.  If it could not find the
resource at that point, it will load it by invoking `T::load_as_resource`
with the given key and stores the return value in the highest level in the
vector.  Then it returns the loaded object.

As a way to improve this performance wise one could substitute `std::map`
with a hashmap that provides :math:`O(1)` access instead of
:math:`O(\mathrm{log}(n))` access like the current one.
