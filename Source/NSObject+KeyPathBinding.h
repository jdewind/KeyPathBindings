#import <Foundation/Foundation.h>

@interface NSObject(KeyPathBinding)
- (void)bindProperty:(NSString *)property onTarget:(id)target toKeyPath:(NSString *)keyPath;
- (void)unBindProperty:(NSString *)property onTarget:(id)target forKeyPath:(NSString *)keyPath;
@end
