#import <Foundation/Foundation.h>

#define USE_ZEROING_WEAK_REFERENCES 1

@interface NSObject(KeyPathBindings)
- (void)bindProperty:(NSString *)property onTarget:(id)target toKeyPath:(NSString *)keyPath;
- (void)unBindProperty:(NSString *)property onTarget:(id)target forKeyPath:(NSString *)keyPath;
@end
