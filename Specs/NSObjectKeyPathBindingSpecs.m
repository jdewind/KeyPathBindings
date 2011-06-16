#import "SpecHelper.h"
#import "NSObject+KeyPathBinding.h"

@interface Photo : NSObject
{
  NSString *_caption;
}

@property (nonatomic, copy) NSString *caption;

@end

@implementation Photo
@synthesize caption = _caption;

- (void)dealloc {
  [_caption release];
  [super dealloc];
}
@end


@interface KeyPathBinding_Observed : NSObject
{
  NSString *_string;
  Photo *_photo;
}

@property (nonatomic, copy) NSString *string;
@property (nonatomic, retain) Photo *photo;

@end

@implementation KeyPathBinding_Observed
@synthesize string = _string;
@synthesize photo = _photo;

- (void)dealloc {
  [_photo release];
  [_string release];
  [super dealloc];
}
@end


@interface KeyPathBinding_Observer : NSObject
{
  NSString *_boundString;
  NSString *_boundPhotoCaption;
}

@property (nonatomic, copy) NSString *boundString;
@property (nonatomic, retain) NSString *boundPhotoCaption;
@end

@implementation KeyPathBinding_Observer
@synthesize boundString = _boundString;
@synthesize boundPhotoCaption = _boundPhotoCaption;

- (void)dealloc {
  [_boundString release];
  [_boundPhotoCaption release];
  [super dealloc];
}
@end



SPEC_BEGIN(NSObjectKeyPathBindingSpecs)

beforeEach(^{
  AddToContext(@"photo", [[[Photo alloc] init] autorelease]);
  AddToContext(@"observed", [[[KeyPathBinding_Observed alloc] init] autorelease]);
  AddToContext(@"observer", [[[KeyPathBinding_Observer alloc] init] autorelease]);
  [m(@"observed") setString:@"Hello"];
  [m(@"observed") setPhoto:m(@"photo")];
  [m(@"photo") setCaption:@"hello"];
});

it(@"binds a property on one object to another", ^{
  [m(@"observed") bindProperty:@"boundString" onTarget:m(@"observer") toKeyPath:@"string"];
  
  assertThat([m(@"observer") boundString], is(@"Hello"));
  [m(@"observed") setString:@"World"];
  assertThat([m(@"observer") boundString], is(@"World"));
});

it(@"supports binding to different targets", ^{
  id anotherObserver = [[[KeyPathBinding_Observer alloc] init] autorelease];
  [m(@"observed") bindProperty:@"boundString" onTarget:m(@"observer") toKeyPath:@"string"];
  [m(@"observed") bindProperty:@"boundString" onTarget:anotherObserver toKeyPath:@"string"];

  assertThat([m(@"observer") boundString], is(@"Hello"));
  assertThat([anotherObserver boundString], is(@"Hello"));
  [m(@"observed") setString:@"World"];
  assertThat([m(@"observer") boundString], is(@"World"));
  assertThat([anotherObserver boundString], is(@"World"));
});

it(@"can bind a property to a property that is contained in another property", ^{
  [m(@"observed") bindProperty:@"boundPhotoCaption" onTarget:m(@"observer") toKeyPath:@"photo.caption"];
  assertThat([m(@"observer") boundPhotoCaption], is(@"hello"));
  [[m(@"observed") photo] setCaption:@"My Caption"];
  assertThat([m(@"observer") boundPhotoCaption], is(@"My Caption"));  
});

it(@"is OK when a observer object is released", ^{
  id observer = [[KeyPathBinding_Observer alloc] init];
  [m(@"observed") bindProperty:@"boundPhotoCaption" onTarget:observer toKeyPath:@"photo.caption"];
  [observer release];
  [[m(@"observed") photo] setCaption:@"My Caption"];
});

it(@"an object can unbind itself", ^{
  [m(@"observed") bindProperty:@"boundPhotoCaption" onTarget:m(@"observer") toKeyPath:@"photo.caption"];
  [m(@"observed") bindProperty:@"boundString" onTarget:m(@"observer") toKeyPath:@"string"];
  [m(@"observed") unBindProperty:@"boundPhotoCaption" onTarget:m(@"observer") forKeyPath:@"photo.caption"];
  
  [m(@"observed") setString:@"World"];
  [[m(@"observed") photo] setCaption:@"My Caption"];
    
  assertThat([m(@"observer") boundPhotoCaption], is(@"hello"));  
});

SPEC_END
