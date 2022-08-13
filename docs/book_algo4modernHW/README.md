https://en.algorithmica.org/hpc/complexity/languages/

The key lesson here is that using a native, low-level language doesn’t necessarily give you performance; but it does give you `control over performance`.

Regardless of the execution environment, it is still largely a programmer’s job to use the opportunities that the hardware provides.


https://en.algorithmica.org/hpc/architecture/

When I began learning how to optimize programs myself, one big mistake I made was to rely primarily on the empirical approach. Not understanding how computers really worked, I would semi-randomly swap nested loops, rearrange arithmetic, combine branch conditions, inline functions by hand, and follow all sorts of other performance tips I’ve heard from other people, blindly hoping for improvement.

It would have probably saved me dozens, if not hundreds of hours if I learned computer architecture before doing algorithmic programming. So, even if most people aren’t excited about it, we are going to spend the first few chapters studying how CPUs work and start with learning assembly.


