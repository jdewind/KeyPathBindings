Description
===========

KeyPathBindings is a library for binding a property to a key path on another object. This can be particularly useful when you want a property on an object to mirror a property on another object. The library can optionally be configured with [MAZeroingWeakRef](https://github.com/mikeash/MAZeroingWeakRef) to automatically zero bindings.

_Note: This library subclasses observed objects -- which means already KVO'd objects will not work._

Example
========

      @interface MySlider : NSObject
      {
        CGFloat percentComplete
      }

      @property(nonatomic, assign) CGFloat *percentComplete;
      @end
      
      ...
      
      [request bindProperty:@"percentComplete" onTarget:mySlider toKeyPath:@"percent"];
      
      request.percent = 0.54f;
      NSCAssert(mySlider.percentComplete == request.percent);

Authors
=======

* Justin DeWind (dewind@atomicobject.com, @dewind on Twitter)
