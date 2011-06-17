#import "NSObject+KeyPathBindings.h"
#import "MAWeakDictionary.h"
#import <pthread.h>
#import <objc/runtime.h>

static void *kBindingContext = &kBindingContext;
static pthread_mutex_t gMutex = PTHREAD_MUTEX_INITIALIZER;
static NSMutableSet *gCustomSubclasses;
static NSMutableDictionary *gCustomSubclassMap;

#pragma mark -
#pragma mark Utilities

// No-ops for non-retaining objects.
static const void* RetainNoOp(CFAllocatorRef allocator, const void *value) { return value; }
static void ReleaseNoOp(CFAllocatorRef allocator, const void *value) { }

static NSMutableDictionary* CreateNonRetainingDictionary() {
  CFDictionaryKeyCallBacks keyCallbacks = kCFTypeDictionaryKeyCallBacks;
  CFDictionaryValueCallBacks callbacks = kCFTypeDictionaryValueCallBacks;
  callbacks.retain = RetainNoOp;
  callbacks.release = ReleaseNoOp;
  return (NSMutableDictionary*)CFDictionaryCreateMutable(nil, 0, &keyCallbacks, &callbacks);
}

#pragma mark -
#pragma mark Custom Binding Class Lookup (Credit: Mike Ash)

static Class GetCustomSubclass(id obj)
{
  Class class = object_getClass(obj);
  while(class && ![gCustomSubclasses containsObject: class])
    class = class_getSuperclass(class);
  return class;
}

static Class GetRealSuperclass(id obj)
{
  Class class = GetCustomSubclass(obj);
  return class_getSuperclass(class);
}

#pragma mark -
#pragma mark Custom Binding Methods

static void CustomDealloc(id obj, SEL sel)
{
  NSMutableDictionary *keyPathToPropertyMappings = objc_getAssociatedObject(obj, @"keyPathToPropertyMappings");
  for (NSString *keyPath in [keyPathToPropertyMappings keyEnumerator]) {
    [obj removeObserver:obj forKeyPath:keyPath];
  }  
  objc_setAssociatedObject(obj, @"keyPathToPropertyMappings", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  Class superclass = GetRealSuperclass(obj);
  IMP superDealloc = class_getMethodImplementation(superclass, @selector(dealloc));
  ((void (*)(id, SEL))superDealloc)(obj, sel);
}

static void ObserveValueForKeyPath(id obj, SEL sel, NSString *keyPath, id changedObject, NSDictionary *change, void *context)
{
  NSMutableDictionary *keyPathToPropertyMappings = objc_getAssociatedObject(obj, @"keyPathToPropertyMappings");
  
  // If we want to support KVO inheritance in the future this context check
  // will not work.
  
  if (context == kBindingContext) {
    NSMutableArray *targets = [keyPathToPropertyMappings objectForKey:keyPath];
    for (NSMutableDictionary *targetInfo in targets) {
      id target = [targetInfo objectForKey:@"target"];
      NSString *property = [targetInfo objectForKey:@"property"];
      [target setValue:[change objectForKey:@"new"] forKey:property];
    }
  } else {
    Class superclass = GetRealSuperclass(obj);
    IMP superObserverValueForKeyPath = class_getMethodImplementation(superclass, @selector(observeValueForKeyPath:ofObject:change:context:));
    ((void (*)(id, SEL, NSString*, id, NSDictionary*, void*))superObserverValueForKeyPath)(obj, sel, keyPath, changedObject, change, context);
  }
   
}

#pragma mark -
#pragma mark Create and Register Subclasses

static Class CreateCustomSubclass(Class class)
{
  NSString *newName = [NSString stringWithFormat: @"%s_AOKeyBindingObservation", class_getName(class)];
  const char *newNameC = [newName UTF8String];
  
  Class subclass = objc_allocateClassPair(class, newNameC, 0);
  
  Method observeValueForKeyPath = class_getInstanceMethod(class, @selector(observeValueForKeyPath:ofObject:change:context:));
  class_addMethod(subclass, @selector(observeValueForKeyPath:ofObject:change:context:), (IMP)ObserveValueForKeyPath, method_getTypeEncoding(observeValueForKeyPath));  
  Method dealloc = class_getInstanceMethod(class, @selector(dealloc));
  class_addMethod(subclass, @selector(dealloc), (IMP)CustomDealloc, method_getTypeEncoding(dealloc));  
  
  objc_registerClassPair(subclass);
  
  return subclass;
}

static void RegisterCustomSubclass(Class subclass, Class superclass)
{
  [gCustomSubclassMap setObject: subclass forKey: superclass];
  [gCustomSubclasses addObject: subclass];
}

static void EnsureCustomSubclass(id obj)
{
  pthread_mutex_lock(&gMutex);
  
  if (!gCustomSubclassMap) gCustomSubclassMap = [[NSMutableDictionary alloc] init];  
  if (!gCustomSubclasses) gCustomSubclasses = [[NSMutableSet alloc] init];
  

  if(!GetCustomSubclass(obj))
  {
    Class class = object_getClass(obj);
    Class subclass = [gCustomSubclassMap objectForKey: class];
    if(!subclass)
    {
      subclass = CreateCustomSubclass(class);
      RegisterCustomSubclass(subclass, class);
    }
    if(class_getSuperclass(subclass) == class)
      object_setClass(obj, subclass);
  }
  
  pthread_mutex_unlock(&gMutex);
}

#pragma mark -

@implementation NSObject(KeyPathBindings)

- (void)bindProperty:(NSString *)property onTarget:(id)target toKeyPath:(NSString *)keyPath {
  EnsureCustomSubclass(self);
  NSMutableDictionary *keyPathToPropertyMappings = objc_getAssociatedObject(self, @"keyPathToPropertyMappings");  
  if (!keyPathToPropertyMappings) {
    keyPathToPropertyMappings = [[[NSMutableDictionary alloc] init] autorelease];
    objc_setAssociatedObject(self, @"keyPathToPropertyMappings", keyPathToPropertyMappings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  
  NSMutableArray *targets = [keyPathToPropertyMappings objectForKey:keyPath];
  if (!targets) {
    targets = [[[NSMutableArray alloc] init] autorelease];
    [keyPathToPropertyMappings setObject:targets forKey:keyPath];
    
    [self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:kBindingContext];
  }
  
  NSMutableDictionary *targetInfo = USE_ZEROING_WEAK_REFERENCES ? [[[MAWeakDictionary alloc] init] autorelease] : CreateNonRetainingDictionary();
  [targetInfo setObject:target forKey:@"target"];
  [targetInfo setObject:property forKey:@"property"];
  [targets addObject:targetInfo];
  [target setValue:[self valueForKeyPath:keyPath] forKey:property];  
}

- (void)unBindProperty:(NSString *)property onTarget:(id)target forKeyPath:(NSString *)keyPath {
  NSMutableDictionary *keyPathToPropertyMappings = objc_getAssociatedObject(self, @"keyPathToPropertyMappings");  
  NSMutableArray *targets = [keyPathToPropertyMappings objectForKey:keyPath];
  for (NSDictionary *targetInfo in [[targets mutableCopy] autorelease]) {
    if ([targetInfo objectForKey:@"target"] == target) {
      [targets removeObject:targetInfo];
    }
  }
}

@end
