Description
===========

KeyPathBindings is a library for binding a property to a key path on another object. This can be particularly useful when you want a property on an object to mirror a property on another object. The library can optionally be configured with [MAZeroingWeakRef](https://github.com/mikeash/MAZeroingWeakRef) to automatically zero bindings.

_Note: This library subclasses observed objects -- which means already KVO'd objects will not work._

Example
========

      @class PeopleHolder, PetsHolder;
      
      @interface MammalHolder : NSObject
      {
        NSArray *people;
        NSArray *pets;
      }

      @property(nonatomic, retain) NSArray *people;
      @property(nonatomic, retain) NSArray *pets;
      @end
      
      @implementation Holder
      @end
      
      ...
      
      [peopleHolder bindProperty:@"people" onTarget:holder toKeyPath:@"people"];
      [petsHolder bindProperty:@"pets" onTarget:holder toKeyPath:@"pets"];


Authors
=======

* Justin DeWind (dewind@atomicobject.com, @dewind on Twitter)
