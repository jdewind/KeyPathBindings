#import "SpecHelper.h"

id AddToContext(NSString *key, id value) {
	[[SpecHelper specHelper].sharedExampleContext setObject:value forKey:key];
	return value;
}

id m(NSString *key) {
  id var = GetFromContext(key);
  NSCAssert(var != nil, @"Attempted to retrieve object from context that did not exist");
  return var;
}

id GetFromContext(NSString *key) {
  return [[SpecHelper specHelper].sharedExampleContext objectForKey:key];
}