#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <netdb.h>
#import <unistd.h>
#import <arpa/inet.h>
static UIColor *orange(void){return [UIColor colorWithRed:1 green:.40 blue:.10 alpha:1];}
static UIColor *dark(void){return [UIColor colorWithRed:.065 green:.070 blue:.082 alpha:1];}
@interface RPHUDWindow : UIWindow
@property(nonatomic,weak) UIView *launcher;
@property(nonatomic) BOOL expanded;
@end
@implementation RPHUDWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
 if (!self.expanded && self.launcher){
   CGPoint q=[self convertPoint:p toView:self.launcher];
   if (![self.launcher pointInside:q withEvent:e])return nil;
 }
 return [super hitTest:p withEvent:e];
}
@end
@interface RPHUDController : UIViewController<UITextFieldDelegate>
@property(nonatomic,weak) RPHUDWindow *overlay;
@property(nonatomic,strong) UIButton *launchButton;
@property(nonatomic,strong) UIView *menu;
@property(nonatomic,strong) UILabel *info;
@property(nonatomic,strong) UILabel *networkInfo;
@property(nonatomic,strong) UITextField *server;
@property(nonatomic,strong) UITextField *host;
@property(nonatomic,strong) NSURLSessionDataTask *task;
@end
@implementation RPHUDController
- (UIButton *)button:(NSString *)text click:(SEL)action {
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
 [b setTitle:text forState:UIControlStateNormal];
 [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
 b.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
 b.titleLabel.adjustsFontSizeToFitWidth=YES;
 b.backgroundColor=orange();b.layer.cornerRadius=10;
 [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
 return b;
}
- (UILabel *)label:(NSString *)value size:(CGFloat)size {
 UILabel *v=[UILabel new];v.text=value;v.textColor=UIColor.whiteColor;
 v.font=[UIFont systemFontOfSize:size weight:UIFontWeightBold];v.numberOfLines=0;
 return v;
}
- (UITextField *)field:(NSString *)hint value:(NSString *)value {
 UITextField *v=[UITextField new];v.placeholder=hint;v.text=value;
 v.backgroundColor=[UIColor colorWithWhite:.17 alpha:1];v.textColor=UIColor.whiteColor;
 v.attributedPlaceholder=[[NSAttributedString alloc]initWithString:hint attributes:@{NSForegroundColorAttributeName:UIColor.lightGrayColor}];
 v.layer.cornerRadius=10;v.font=[UIFont systemFontOfSize:16];
 v.autocorrectionType=UITextAutocorrectionTypeNo;
 v.autocapitalizationType=UITextAutocapitalizationTypeNone;
 v.returnKeyType=UIReturnKeyDone;v.delegate=self;
 UIView *left=[[UIView alloc]initWithFrame:CGRectMake(0,0,12,2)];
 v.leftView=left;v.leftViewMode=UITextFieldViewModeAlways;
 [v.heightAnchor constraintEqualToConstant:46].active=YES;
 return v;
}
- (BOOL)textFieldShouldReturn:(UITextField*)field{[field resignFirstResponder];return YES;}
- (void)viewDidLoad {
 [super viewDidLoad];self.view.backgroundColor=UIColor.clearColor;
 UIButton *launch=[self button:@"★ RP" click:@selector(toggle)];self.launchButton=launch;
 launch.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:launch];
 [NSLayoutConstraint activateConstraints:@[
 [launch.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
 [launch.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18],
 [launch.widthAnchor constraintEqualToConstant:78],
 [launch.heightAnchor constraintEqualToConstant:44]]];
 UIView *menu=[UIView new];self.menu=menu;menu.hidden=YES;menu.backgroundColor=dark();
 menu.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:menu];
 [NSLayoutConstraint activateConstraints:@[
 [menu.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
 [menu.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
 [menu.topAnchor constraintEqualToAnchor:self.view.topAnchor],
 [menu.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]]];
 UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;
 [menu addSubview:scroll];
 [NSLayoutConstraint activateConstraints:@[
 [scroll.leadingAnchor constraintEqualToAnchor:menu.safeAreaLayoutGuide.leadingAnchor],
 [scroll.trailingAnchor constraintEqualToAnchor:menu.safeAreaLayoutGuide.trailingAnchor],
 [scroll.topAnchor constraintEqualToAnchor:menu.safeAreaLayoutGuide.topAnchor],
 [scroll.bottomAnchor constraintEqualToAnchor:menu.safeAreaLayoutGuide.bottomAnchor]]];
 UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=13;
 stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[
 [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:18],
 [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-18],
 [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:15],
 [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-30],
 [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-36]]];
 UILabel *title=[self label:@"★ GTA5RP MOBILE" size:27];title.textColor=orange();
 [stack addArrangedSubview:title];
 UILabel *sub=[self label:@"Диагностика RAGE MP поверх GTA V. Не является входом в игровую сессию." size:13];sub.textColor=UIColor.lightGrayColor;
 [stack addArrangedSubview:sub];
 self.server=[self field:@"Название сервера" value:@"Eclipse"];[stack addArrangedSubview:self.server];
 UIButton *refresh=[self button:@"ПОКАЗАТЬ РЕАЛЬНЫЙ ОНЛАЙН" click:@selector(refresh)];
 [stack addArrangedSubview:refresh];[refresh.heightAnchor constraintEqualToConstant:50].active=YES;
 self.info=[self label:@"ОНЛАЙН: ЕЩЁ НЕ ЗАПРОШЕН" size:19];[stack addArrangedSubview:self.info];
 UILabel *div=[self label:@"ПРОВЕРКА ПОДКЛЮЧЕНИЯ" size:21];div.textColor=orange();[stack addArrangedSubview:div];
 self.host=[self field:@"server.gta5rp.com:22005" value:@"eclipse.gta5rp.com:22005"];
 [stack addArrangedSubview:self.host];
 UIButton *ping=[self button:@"ПРОВЕРИТЬ UDP 22005" click:@selector(probe)];
 [stack addArrangedSubview:ping];[ping.heightAnchor constraintEqualToConstant:50].active=YES;
 self.networkInfo=[self label:@"Ожидается адрес сервера" size:14];[stack addArrangedSubview:self.networkInfo];
 UILabel *notice=[self label:@"Сохранён оригинальный P2P-онлайн порта. RAGE MP протокол, авторизация и синхронизация игроков пока НЕ реализованы." size:13];
 notice.textColor=UIColor.lightGrayColor;[stack addArrangedSubview:notice];
 UIButton *back=[self button:@"ВЕРНУТЬСЯ В GTA V ▶" click:@selector(toggle)];
 [stack addArrangedSubview:back];[back.heightAnchor constraintEqualToConstant:50].active=YES;
}
- (void)toggle {
 BOOL open=self.menu.isHidden;self.menu.hidden=!open;self.launchButton.hidden=open;
 self.overlay.expanded=open;[self.server resignFirstResponder];[self.host resignFirstResponder];
 if(open)[self refresh];
}
- (void)refresh {
 [self.task cancel];self.info.text=@"Получаем онлайн…";
 NSString *which=[self.server.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
 if(!which.length)which=@"eclipse";
 NSURLRequest *req=[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://cdn.rage.mp/master/"]
 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:12];
 __weak typeof(self) weakSelf=self;
 self.task=[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data,NSURLResponse *response,NSError *err) {
  dispatch_async(dispatch_get_main_queue(), ^{
   __strong typeof(weakSelf) owner=weakSelf;if(!owner)return;
   if(err){if(err.code!=NSURLErrorCancelled)owner.info.text=@"Каталог недоступен";return;}
   if(![response isKindOfClass:NSHTTPURLResponse.class] || ((NSHTTPURLResponse*)response).statusCode!=200 || data.length>20000000){owner.info.text=@"Сервер статистики не ответил";return;}
   id root=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
   if(![root isKindOfClass:NSDictionary.class]){owner.info.text=@"Неизвестный формат статистики";return;}
   NSInteger count=0,limit=0,hits=0;
   for(id key in (NSDictionary*)root){
    id entry=((NSDictionary*)root)[key];if(![entry isKindOfClass:NSDictionary.class])continue;
    NSString *title=entry[@"name"];if(![title isKindOfClass:NSString.class])continue;
    NSString *t=[[title lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""];
    if(![t containsString:@"gta5rp"]||![t containsString:which])continue;
    NSNumber *n=entry[@"players"],*max=entry[@"maxplayers"];
    if(![n isKindOfClass:NSNumber.class]||![max isKindOfClass:NSNumber.class])continue;
    if(n.integerValue<0||max.integerValue<=0||n.integerValue>max.integerValue)continue;
    count+=n.integerValue;limit+=max.integerValue;hits++;
   }
   owner.info.text=hits?[NSString stringWithFormat:@"ОНЛАЙН: %ld / %ld",(long)count,(long)limit]:
       @"Нет сведений в RAGE MP masterlist";
  });
 }];
 [self.task resume];
}
- (void)probe {
 NSString *target=[self.host.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSArray *parts=[target componentsSeparatedByString:@":"];
 if(parts.count>2||![(NSString *)parts.firstObject length]){self.networkInfo.text=@"Укажи домен:порт";return;}
 NSString *host=parts.firstObject;NSInteger port=parts.count==2?[parts.lastObject integerValue]:22005;
 if(port<=0||port>65535){self.networkInfo.text=@"Неверный UDP-порт";return;}
 self.networkInfo.text=@"Проверяем RakNet UDP…";
 __weak typeof(self) weakSelf=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
  struct addrinfo hints={0},*list=NULL;hints.ai_family=AF_UNSPEC;hints.ai_socktype=SOCK_DGRAM;
  NSString *portText=[NSString stringWithFormat:@"%ld",(long)port];
  int rc=getaddrinfo(host.UTF8String,portText.UTF8String,&hints,&list);
  BOOL received=NO;
  if(rc==0){
   static const unsigned char magic[]={0,255,255,0,254,254,254,254,253,253,253,253,18,52,86,120};
   unsigned char ping[33]={0};ping[0]=1;
   uint64_t tick=(uint64_t)(NSDate.date.timeIntervalSince1970*1000);
   for(int i=0;i<8;i++)ping[1+i]=(tick>>(56-8*i))&255;
   memcpy(ping+9,magic,sizeof(magic));
   uint64_t guid=arc4random();
   for(int i=0;i<8;i++)ping[25+i]=(guid>>(56-8*i))&255;
   for(struct addrinfo *entry=list;entry;entry=entry->ai_next){
    int s=socket(entry->ai_family,SOCK_DGRAM,IPPROTO_UDP);if(s<0)continue;
    struct timeval to={2,0};setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&to,sizeof(to));
    ssize_t sent=sendto(s,ping,sizeof(ping),0,entry->ai_addr,entry->ai_addrlen);
    unsigned char pong[2048];ssize_t got=sent==sizeof(ping)?recvfrom(s,pong,sizeof(pong),0,NULL,NULL):-1;
    close(s);
    if(got>=35&&pong[0]==0x1c&&memcmp(pong+17,magic,16)==0){received=YES;break;}
   }
   freeaddrinfo(list);
  }
  dispatch_async(dispatch_get_main_queue(), ^{
   __strong typeof(weakSelf) owner=weakSelf;if(!owner)return;
   owner.networkInfo.text=received?@"UDP сервер ответил. Вход в GTA5RP НЕ выполнен.":
     (rc==0?@"Не получен RakNet Pong. Это не означает, что сервер выключен.":@"DNS-адрес не найден.");
  });
 });
}
@end

@interface RPBoot : NSObject @end
@implementation RPBoot
static RPHUDWindow *activeWindow=nil;
static NSInteger installAttempts=0;
+ (void)load {
 // UIKit scene lifecycle can start AFTER the injected dylib +load callback.
 // Never create a detached UIWindow; do not mark a failed install successful.
 dispatch_async(dispatch_get_main_queue(), ^{
  NSArray<NSNotificationName> *signals=@[
    UIApplicationDidBecomeActiveNotification,
    UISceneDidActivateNotification,
    UISceneWillEnterForegroundNotification,
    UIWindowDidBecomeVisibleNotification
  ];
  for(NSNotificationName name in signals)
   [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(activated:) name:name object:nil];
  [self install];
 });
}
+ (void)activated:(NSNotification *)note {
 dispatch_async(dispatch_get_main_queue(), ^{ [self install]; });
}
+ (void)install {
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self install];});return;}
 UIWindowScene *scene=nil;
 UIWindow *gameWindow=nil;
 for(UIScene *candidate in UIApplication.sharedApplication.connectedScenes){
  if(![candidate isKindOfClass:UIWindowScene.class])continue;
  if(candidate.activationState!=UISceneActivationStateForegroundActive)continue;
  UIWindowScene *candidateScene=(UIWindowScene*)candidate;
  for(UIWindow *window in candidateScene.windows){
   if(window==activeWindow||window.hidden||window.alpha<0.05)continue;
   if(!gameWindow||window.isKeyWindow)gameWindow=window;
  }
  if(gameWindow){scene=candidateScene;break;}
 }
 if(!scene){
  if(installAttempts++<120)
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(NSEC_PER_SEC/2)),dispatch_get_main_queue(),^{[self install];});
  return;
 }
 installAttempts=0;
 if(activeWindow && activeWindow.windowScene==scene && !activeWindow.hidden)return;
 if(activeWindow){activeWindow.hidden=YES;activeWindow=nil;}
 RPHUDWindow *window=[[RPHUDWindow alloc]initWithWindowScene:scene];
 window.frame=scene.coordinateSpace.bounds;
 window.backgroundColor=UIColor.clearColor;
 window.windowLevel=UIWindowLevelAlert+8;
 RPHUDController *controller=[RPHUDController new];
 window.rootViewController=controller;
 controller.overlay=window;
 (void)controller.view; // Force viewDidLoad to create the control before assigning hit-testing.
 window.launcher=controller.launchButton;
 activeWindow=window;
 window.hidden=NO;
 [window layoutIfNeeded];
 NSLog(@"[GTA5RP Overlay] Installed in active UIWindowScene %@, button=%@",scene,window.launcher);
}
@end
