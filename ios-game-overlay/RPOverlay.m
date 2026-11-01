#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <netdb.h>
#import <unistd.h>
#import <arpa/inet.h>
#import <errno.h>
#import <string.h>
#include "RPStunProbe.inc"
#include "RPStunNative.inc"
#include "RPRageHandshakeProbe.inc"
#include "RPP2PDiscovery.inc"
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
@property(nonatomic,strong) UILabel *stunInfo;
@property(nonatomic,strong) UILabel *nativeStunInfo;
@property(nonatomic,strong) UILabel *rageInfo;
@property(nonatomic,strong) UILabel *resourcesInfo;
@property(nonatomic,strong) UILabel *p2pInfo;
@property(nonatomic,strong) nw_browser_t p2pBrowser;
@property(nonatomic) BOOL p2pBusy;
@property(nonatomic) BOOL stunBusy;
@property(nonatomic) BOOL nativeStunBusy;
@property(nonatomic) BOOL rageBusy;
@property(nonatomic) BOOL resourcesBusy;
@property(nonatomic,strong) UITextField *server;
@property(nonatomic,strong) UITextField *host;
@property(nonatomic,strong) NSURLSessionDataTask *task;
@property(nonatomic,strong) NSLayoutConstraint *buttonCenterY;
@property(nonatomic,strong) NSLayoutConstraint *buttonBottom;
@property(nonatomic) BOOL probing;
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
 [launch.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
 [launch.widthAnchor constraintEqualToConstant:74],
 [launch.heightAnchor constraintEqualToConstant:46]]];
 // Landscape: floating control at the center of the right edge.
 // Portrait: keep it near the bottom-right. Autolayout handles safe-area cutouts.
 self.buttonCenterY=[launch.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor];
 self.buttonBottom=[launch.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18];
 [self updateButtonPlacement];
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
 [stack.centerXAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.centerXAnchor],
 [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:18],
 [stack.trailingAnchor constraintLessThanOrEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-18],
 [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:12],
 [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-22],
 [stack.widthAnchor constraintLessThanOrEqualToConstant:590],
 [stack.widthAnchor constraintLessThanOrEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-36]]];
 UILabel *title=[self label:@"★ GTA5RP MOBILE · FIVESTAR" size:27];title.textColor=orange();
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

 UILabel *stunHeading=[self label:@"ПРОВЕРКА UDP ЧЕРЕЗ GOOGLE STUN" size:20];
 stunHeading.textColor=orange();[stack addArrangedSubview:stunHeading];
 UIButton *stun=[self button:@"ПРОВЕРИТЬ STUN 19302" click:@selector(stunProbe)];
 [stack addArrangedSubview:stun];[stun.heightAnchor constraintEqualToConstant:50].active=YES;
 self.stunInfo=[self label:@"Тест STUN ещё не запущен" size:14];
 [stack addArrangedSubview:self.stunInfo];
 UIButton *nativeButton=[self button:@"ПРОВЕРИТЬ NATIVE UDP (iOS)" click:@selector(nativeStunProbe)];
 [stack addArrangedSubview:nativeButton];
 [nativeButton.heightAnchor constraintEqualToConstant:50].active=YES;
 self.nativeStunInfo=[self label:@"Альтернативная проверка через Apple Network.framework" size:14];
 [stack addArrangedSubview:self.nativeStunInfo];
 UIButton *ping=[self button:@"ПРОВЕРИТЬ UDP 22005" click:@selector(probe)];
 [stack addArrangedSubview:ping];[ping.heightAnchor constraintEqualToConstant:50].active=YES;
 self.networkInfo=[self label:@"Ожидается адрес сервера" size:14];[stack addArrangedSubview:self.networkInfo];
 UILabel *stage=[self label:@"НАЧАЛЬНЫЙ ОБМЕН RAKNET" size:20];
 stage.textColor=orange();[stack addArrangedSubview:stage];
 UIButton *startProbe=[self button:@"ПРОВЕРИТЬ UDP ДЛИНЫ 576 / 1200 / 1400" click:@selector(rageProbe)];
 [stack addArrangedSubview:startProbe];
 [startProbe.heightAnchor constraintEqualToConstant:50].active=YES;
 self.rageInfo=[self label:@"Этап 0/3: ещё не проверен" size:14];
 [stack addArrangedSubview:self.rageInfo];
 UIButton *resourceProbe=[self button:@"ПРОВЕРИТЬ HTTP HEAD 22006" click:@selector(resourcesProbe)];
 [stack addArrangedSubview:resourceProbe];
 [resourceProbe.heightAnchor constraintEqualToConstant:50].active=YES;
 self.resourcesInfo=[self label:@"Порт+1: HTTP-заголовки не проверены" size:14];
 [stack addArrangedSubview:self.resourcesInfo];
 UILabel *notice=[self label:@"Проверки показывают только доступность сети. Официальный игровой handshake, авторизация и синхронизация GTA5RP пока НЕ реализованы. P2P-порт сохранён." size:13];
 notice.textColor=UIColor.lightGrayColor;[stack addArrangedSubview:notice];
 UILabel *discoveryHeading=[self label:@"P2P-ПОИСК ИЗ ВТОРОГО ПОРТА" size:20];
 discoveryHeading.textColor=orange();[stack addArrangedSubview:discoveryHeading];
 UIButton *findPeers=[self button:@"НАЙТИ P2P-СЕССИИ В WI-FI" click:@selector(startP2PDiscovery)];
 [stack addArrangedSubview:findPeers];
 [findPeers.heightAnchor constraintEqualToConstant:50].active=YES;
 self.p2pInfo=[self label:@"Ищем объявления _gtavmp._udp, используемые вторым iOS-портом. Просмотр игроков и вход в сессию пока не поддерживаются." size:13];
 [stack addArrangedSubview:self.p2pInfo];
 UILabel *traceHeading=[self label:@"ДИАГНОСТИЧЕСКИЙ ОТЧЁТ" size:20];
 traceHeading.textColor=orange();[stack addArrangedSubview:traceHeading];
 UILabel *traceHint=[self label:@"Сохраняет только текст уже выполненных проверок. Отчёт может содержать внешний IP. Отправка происходит только по твоему выбору." size:12];
 traceHint.textColor=UIColor.lightGrayColor;[stack addArrangedSubview:traceHint];
 UIButton *exportLogs=[self button:@"ПОДЕЛИТЬСЯ ОТЧЁТОМ" click:@selector(exportDiagnostics)];
 [stack addArrangedSubview:exportLogs];
 [exportLogs.heightAnchor constraintEqualToConstant:50].active=YES;
 UIButton *back=[self button:@"ВЕРНУТЬСЯ В GTA V ▶" click:@selector(toggle)];
 [stack addArrangedSubview:back];[back.heightAnchor constraintEqualToConstant:50].active=YES;
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];
 [self updateButtonPlacement];
}
- (void)updateButtonPlacement {
 BOOL landscape=self.view.bounds.size.width > self.view.bounds.size.height;
 if(landscape && self.buttonCenterY && !self.buttonCenterY.active) {
  self.buttonBottom.active=NO;
  self.buttonCenterY.active=YES;
 } else if(!landscape && self.buttonBottom && !self.buttonBottom.active) {
  self.buttonCenterY.active=NO;
  self.buttonBottom.active=YES;
 }
}
- (void)startP2PDiscovery {
 if(self.p2pBusy)return;
 self.p2pBusy=YES;
 self.p2pInfo.text=@"Поиск _gtavmp._udp...";
 __weak typeof(self) weakSelf=self;
 void (^log)(NSString *)=^(NSString *line){
  dispatch_async(dispatch_get_main_queue(),^{
   __strong typeof(weakSelf) owner=weakSelf;if(!owner)return;
   NSString *prior=owner.p2pInfo.text ?: @"";
   owner.p2pInfo.text=prior.length?[prior stringByAppendingFormat:@"\n%@",line]:line;
  });
 };
 self.p2pBrowser=RPP2PBrowse(log,^{
  __strong typeof(weakSelf) owner=weakSelf;
  if(owner){owner.p2pBusy=NO;owner.p2pBrowser=nil;}
 });
}
- (void)exportDiagnostics {
 NSDateFormatter *df=[NSDateFormatter new];
 df.dateFormat=@"yyyy-MM-dd HH:mm:ss Z";
 NSString *date=[df stringFromDate:NSDate.date];
 NSArray<NSArray<NSString *> *> *parts=@[
  @[@"ONLINE", self.info.text ?: @"not checked"],
  @[@"UDP / RAKNET 0x01",self.networkInfo.text ?: @"not checked"],
  @[@"STUN / BSD",self.stunInfo.text ?: @"not checked"],
  @[@"STUN / NETWORK.FRAMEWORK",self.nativeStunInfo.text ?: @"not checked"],
  @[@"RAKNET 0x05",self.rageInfo.text ?: @"not checked"],
  @[@"HTTP RESOURCE HEAD",self.resourcesInfo.text ?: @"not checked"],
  @[@"P2P BONJOUR DISCOVERY",self.p2pInfo.text ?: @"not checked"]
 ];
 NSMutableString *report=[NSMutableString stringWithFormat:
   @"GTA5RP Online Lab v1.0 (experimental, no game connection)\nTimestamp: %@\nSelected server: %@\nAddress: %@\nDevice: %@ / iOS %@\n\n",
   date,
   self.server.text ?: @"",
   self.host.text ?: @"",
   UIDevice.currentDevice.model,
   UIDevice.currentDevice.systemVersion];
 for(NSArray<NSString *> *part in parts){
  [report appendFormat:@"[%@]\n%@\n\n",part[0],part[1]];
 }
 [report appendString:@"This report does not contain an authorized RAGE MP gameplay session.\n"];
 UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[report]
     applicationActivities:nil];
 UIPopoverPresentationController *popup=share.popoverPresentationController;
 if(popup){popup.sourceView=self.menu;popup.sourceRect=CGRectMake(CGRectGetMidX(self.menu.bounds),
          CGRectGetMidY(self.menu.bounds),1,1);popup.permittedArrowDirections=0;}
 [self presentViewController:share animated:YES completion:nil];
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
- (BOOL)probeTargetHost:(NSString **)host port:(uint16_t *)port {
 NSString *input=[self.host.text stringByTrimmingCharactersInSet:
                    NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSArray<NSString *> *parts=[input componentsSeparatedByString:@":"];
 if(parts.count>2 || parts.firstObject.length==0 ||
    [parts.firstObject containsString:@"/"] ||
    [parts.firstObject containsString:@" "]){
  return NO;
 }
 NSInteger number=parts.count==2?[parts.lastObject integerValue]:22005;
 if(number<1||number>65534)return NO;
 *host=parts.firstObject;
 *port=(uint16_t)number;
 return YES;
}
- (void)rageAppend:(NSString *)line {
 NSString *prior=self.rageInfo.text ?: @"";
 self.rageInfo.text=prior.length?[prior stringByAppendingFormat:@"\n%@",line]:line;
}
- (void)rageProbe {
 if(self.rageBusy)return;
 NSString *host=nil;uint16_t port=0;
 if(![self probeTargetHost:&host port:&port]){
  self.rageInfo.text=@"Неверный адрес, укажи host:port";return;
 }
 self.rageBusy=YES;
 self.rageInfo.text=[NSString stringWithFormat:@"Этап 1/3: %@:%u, три длины UDP (по одному запросу)",
                    host,port];
 __weak typeof(self) weakSelf=self;
 void (^log)(NSString *)=^(NSString *message){
  dispatch_async(dispatch_get_main_queue(),^{
   __strong typeof(weakSelf) owner=weakSelf;
   if(owner)[owner rageAppend:message];
  });
 };
 RPRaknetOpenProbe(host,port,log,^{
  dispatch_async(dispatch_get_main_queue(),^{weakSelf.rageBusy=NO;});
 });
}
- (void)resourcesAppend:(NSString *)line {
 NSString *prior=self.resourcesInfo.text ?: @"";
 self.resourcesInfo.text=prior.length?[prior stringByAppendingFormat:@"\n%@",line]:line;
}
- (void)resourcesProbe {
 if(self.resourcesBusy)return;
 NSString *host=nil;uint16_t port=0;
 if(![self probeTargetHost:&host port:&port]){
  self.resourcesInfo.text=@"Неверный адрес, укажи host:port";return;
 }
 uint16_t resourcePort=port+1;
 self.resourcesBusy=YES;
 self.resourcesInfo.text=[NSString stringWithFormat:@"Проверка HTTP HEAD %@:%u без скачивания…",
                         host,resourcePort];
 __weak typeof(self) weakSelf=self;
 void (^log)(NSString *)=^(NSString *message){
  dispatch_async(dispatch_get_main_queue(),^{
   __strong typeof(weakSelf) owner=weakSelf;
   if(owner)[owner resourcesAppend:message];
  });
 };
 RPRageResourcePortProbe(host,resourcePort,log,^{
  dispatch_async(dispatch_get_main_queue(),^{weakSelf.resourcesBusy=NO;});
 });
}
- (void)nativeStunLog:(NSString *)message {
 NSString *old=self.nativeStunInfo.text ?: @"";
 self.nativeStunInfo.text=old.length?[old stringByAppendingFormat:@"\n%@",message]:message;
}
- (void)nativeStunProbe {
 if(self.nativeStunBusy)return;
 self.nativeStunBusy=YES;
 self.nativeStunInfo.text=@"Проверка №1: Google STUN 19302";
 __weak typeof(self) weakSelf=self;
 void (^log)(NSString *)=^(NSString *message) {
  dispatch_async(dispatch_get_main_queue(),^{
   __strong typeof(weakSelf) owner=weakSelf;
   if(owner)[owner nativeStunLog:message];
  });
 };
 RPStunNative("stun.l.google.com","19302",log,^(BOOL success){
  if(success){
   dispatch_async(dispatch_get_main_queue(),^{weakSelf.nativeStunBusy=NO;});
  }else{
   log(@"Google STUN не ответил. Проверка №2: Cloudflare STUN 3478.");
   RPStunNative("stun.cloudflare.com","3478",log,^(BOOL otherSuccess){
    if(!otherSuccess)log(@"Оба STUN-сервера не ответили через Apple Network.framework.");
    dispatch_async(dispatch_get_main_queue(),^{weakSelf.nativeStunBusy=NO;});
   });
  }
 });
}
- (void)stunProbe {
 if(self.stunBusy)return;
 self.stunBusy=YES;
 self.stunInfo.text=@"Начало STUN-теста…";
 __weak typeof(self) weakSelf=self;
 RPStunProbe(^(NSString *message) {
  dispatch_async(dispatch_get_main_queue(), ^{
   __strong typeof(weakSelf) controller=weakSelf;
   if(!controller)return;
   NSString *previous=controller.stunInfo.text ?: @"";
   controller.stunInfo.text=previous.length?
      [previous stringByAppendingFormat:@"\n%@",message]:message;
   if([message containsString:@"НЕ вход в GTA5RP"]||
      [message containsString:@"тайм-аут"]||
      [message containsString:@"не соответствует"]||
      [message containsString:@"Некорректная длина"]||
      [message containsString:@"нет публичного"]||
      [message containsString:@"невозможно создать"]||
      [message containsString:@"STUN отправка"])controller.stunBusy=NO;
  });
 });
}
- (void)appendDiagnostic:(NSString *)message {
 if(!message.length)return;
 NSString *current=self.networkInfo.text ?: @"";
 self.networkInfo.text=current.length?[current stringByAppendingFormat:@"\n%@",message]:message;
}
- (void)probe {
 if(self.probing)return;
 [self.host resignFirstResponder];
 NSString *target=[self.host.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSArray *parts=[target componentsSeparatedByString:@":"];
 if(parts.count>2||![(NSString *)parts.firstObject length]){
  self.networkInfo.text=@"Укажи домен:порт";return;
 }
 NSString *host=parts.firstObject;
 NSInteger port=parts.count==2?[parts.lastObject integerValue]:22005;
 if(port<=0||port>65535){self.networkInfo.text=@"Неверный UDP-порт";return;}
 self.probing=YES;
 self.networkInfo.text=[NSString stringWithFormat:@"1. DNS: %@…",host];
 NSString *portText=[NSString stringWithFormat:@"%ld",(long)port];
 __weak typeof(self) weakSelf=self;
 void (^log)(NSString *)=^(NSString *message){
  dispatch_async(dispatch_get_main_queue(), ^{
   __strong typeof(weakSelf) owner=weakSelf;
   if(owner)[owner appendDiagnostic:message];
  });
 };
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
  struct addrinfo hints={0},*addresses=NULL;
  hints.ai_family=AF_UNSPEC;
  hints.ai_socktype=SOCK_DGRAM;
  hints.ai_protocol=IPPROTO_UDP;
  int dns=getaddrinfo(host.UTF8String,portText.UTF8String,&hints,&addresses);
  if(dns!=0){
   log([NSString stringWithFormat:@"✕ Системный DNS: %s",gai_strerror(dns)]);
   dispatch_async(dispatch_get_main_queue(),^{weakSelf.probing=NO;});
   return;
  }
  NSMutableArray<NSString *> *ips=[NSMutableArray array];
  BOOL allSynthetic=YES;
  BOOL hasCandidate=NO;
  for(struct addrinfo *p=addresses;p;p=p->ai_next){
   char ip[NI_MAXHOST]={0};
   if(getnameinfo(p->ai_addr,(socklen_t)p->ai_addrlen,ip,sizeof(ip),NULL,0,NI_NUMERICHOST)!=0)continue;
   NSString *value=[NSString stringWithUTF8String:ip];
   [ips addObject:value];
   if(p->ai_family==AF_INET){
    uint8_t a[4];
    memcpy(a,&((struct sockaddr_in *)p->ai_addr)->sin_addr,4);
    BOOL synthetic=(a[0]>=240 || (a[0]==198&&(a[1]==18||a[1]==19)));
    if(!synthetic){allSynthetic=NO;hasCandidate=YES;}
   } else if(p->ai_family==AF_INET6){
    allSynthetic=NO;hasCandidate=YES;
   }
  }
  log([NSString stringWithFormat:@"✓ DNS системы: %@",ips.count?[ips componentsJoinedByString:@", "]:@"пустой ответ"]);
  if(ips.count>0&&allSynthetic&&!hasCandidate){
   log(@"! Адрес зарезервирован (Fake-IP/VPN DNS). Не отправляем UDP в 240/4 или 198.18/15.");
   log(@"2. Запрашиваем публичный IPv4 через HTTPS DNS…");
   // Both providers use an ordinary public JSON DNS response. No fabricated result and no
   // undocumented GTA5RP handshake. The user explicitly pressed the diagnostic button.
   NSArray<NSString *> *providers=@[@"dns.google", @"cloudflare-dns.com"];
   NSString *resolved=nil;
   for(NSString *provider in providers){
    NSURLComponents *component=[NSURLComponents new];
    component.scheme=@"https";component.host=provider;
    component.path=[provider isEqualToString:@"dns.google"]?@"/resolve":@"/dns-query";
    component.queryItems=@[
     [NSURLQueryItem queryItemWithName:@"name" value:host],
     [NSURLQueryItem queryItemWithName:@"type" value:@"A"]
    ];
    if(!component.URL)continue;
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:component.URL];
    request.timeoutInterval=6;
    [request setValue:@"application/dns-json" forHTTPHeaderField:@"Accept"];
    NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest=6;
    config.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:config];
    dispatch_semaphore_t done=dispatch_semaphore_create(0);
    __block NSData *responseData=nil;
    __block NSInteger httpCode=0;
    NSURLSessionDataTask *task=[session dataTaskWithRequest:request
     completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
      if(!error && [(id)response isKindOfClass:NSHTTPURLResponse.class]){
       responseData=data;
       httpCode=((NSHTTPURLResponse *)response).statusCode;
      }
      dispatch_semaphore_signal(done);
     }];
    [task resume];
    long wait=dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,7*NSEC_PER_SEC));
    if(wait!=0)[task cancel];
    [session invalidateAndCancel];
    if(wait!=0||httpCode!=200||responseData.length>100000)continue;
    NSDictionary *response=[NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
    if(![response isKindOfClass:NSDictionary.class]||[response[@"Status"] integerValue]!=0)continue;
    for(id item in response[@"Answer"]){
     if(![item isKindOfClass:NSDictionary.class]||[item[@"type"] integerValue]!=1)continue;
     NSString *address=item[@"data"];
     if(![address isKindOfClass:NSString.class])continue;
     struct in_addr parsed;
     if(inet_pton(AF_INET,address.UTF8String,&parsed)!=1)continue;
     const uint8_t *octets=(const uint8_t *)&parsed;
     BOOL special=octets[0]==0||octets[0]==10||octets[0]==127||
      octets[0]>=224 || (octets[0]==169&&octets[1]==254) ||
      (octets[0]==172&&octets[1]>=16&&octets[1]<=31) ||
      (octets[0]==192&&octets[1]==168) ||
      (octets[0]==198&&(octets[1]==18||octets[1]==19));
     if(special)continue;
     resolved=address;
     break;
    }
    if(resolved){
     log([NSString stringWithFormat:@"✓ DoH %@: %@",provider,resolved]);
     break;
    }
    log([NSString stringWithFormat:@"! DoH %@ не вернул проверяемый публичный IPv4",provider]);
   }
   freeaddrinfo(addresses);
   addresses=NULL;
   if(!resolved){
    log(@"Итог: только Fake-IP; DoH не дал реальный адрес. Проверь режим DNS/VPN, исключи gta5rp.com из Fake-IP.");
    dispatch_async(dispatch_get_main_queue(),^{weakSelf.probing=NO;});
    return;
   }
   hints.ai_family=AF_INET;
   hints.ai_flags=AI_NUMERICHOST;
   dns=getaddrinfo(resolved.UTF8String,portText.UTF8String,&hints,&addresses);
   if(dns!=0){
    log([NSString stringWithFormat:@"✕ Сетевой адрес DoH: %s",gai_strerror(dns)]);
    dispatch_async(dispatch_get_main_queue(),^{weakSelf.probing=NO;});
    return;
   }
   log(@"3. UDP-проба отправляется на публичный IP. VPN всё ещё может блокировать UDP.");
  } else if(!hasCandidate){
   log(@"Итог: DNS не дал подходящих адресов.");
   if(addresses)freeaddrinfo(addresses);
   dispatch_async(dispatch_get_main_queue(),^{weakSelf.probing=NO;});
   return;
  } else {
   log(@"2. Системный DNS дал обычный IP. Продолжаем UDP-проверку.");
  }
  static const unsigned char magic[16]={0,255,255,0,254,254,254,254,253,253,253,253,18,52,86,120};
  BOOL sentAny=NO,replyAny=NO,valid=NO;
  NSUInteger attempted=0;
  for(struct addrinfo *p=addresses;p&&attempted<4;p=p->ai_next){
   if(p->ai_family!=AF_INET&&p->ai_family!=AF_INET6)continue;
   if(p->ai_family==AF_INET){
    const uint8_t *o=(const uint8_t *)&((struct sockaddr_in *)p->ai_addr)->sin_addr;
    if(o[0]>=240||(o[0]==198&&(o[1]==18||o[1]==19)))continue;
   }
   attempted++;
   int fd=socket(p->ai_family,SOCK_DGRAM,IPPROTO_UDP);
   if(fd<0){
    log([NSString stringWithFormat:@"✕ UDP socket: %s",strerror(errno)]);
    continue;
   }
   struct timeval timeout={2,0};
   setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
   unsigned char ping[33]={0};
   ping[0]=0x01;
   uint64_t timestamp=(uint64_t)(NSDate.date.timeIntervalSince1970*1000);
   for(int i=0;i<8;i++)ping[1+i]=(timestamp>>(56-i*8))&255;
   memcpy(ping+9,magic,sizeof(magic));
   uint64_t guid=((uint64_t)arc4random()<<32)|arc4random();
   for(int i=0;i<8;i++)ping[25+i]=(guid>>(56-i*8))&255;
   CFAbsoluteTime began=CFAbsoluteTimeGetCurrent();
   ssize_t bytes=sendto(fd,ping,sizeof(ping),0,p->ai_addr,(socklen_t)p->ai_addrlen);
   if(bytes!=sizeof(ping)){
    log([NSString stringWithFormat:@"✕ UDP отправка: %s",strerror(errno)]);
    close(fd);continue;
   }
   sentAny=YES;
   log([NSString stringWithFormat:@"2. UDP: отправлено %zd байта, адрес #%lu",bytes,(unsigned long)attempted]);
   unsigned char pong[2048]={0};
   ssize_t received=recvfrom(fd,pong,sizeof(pong),0,NULL,NULL);
   int receivedErrno=errno;
   double elapsed=(CFAbsoluteTimeGetCurrent()-began)*1000;
   close(fd);
   if(received<=0){
    if(receivedErrno==EAGAIN||receivedErrno==EWOULDBLOCK)
     log([NSString stringWithFormat:@"3. Ответ: тайм-аут %.0f мс",elapsed]);
    else
     log([NSString stringWithFormat:@"3. Ответ: ошибка %s",strerror(receivedErrno)]);
    continue;
   }
   replyAny=YES;
   log([NSString stringWithFormat:@"3. Получено %zd байт за %.0f мс, ID 0x%02X",received,elapsed,pong[0]]);
   if(received>=35&&pong[0]==0x1c&&memcmp(pong+17,magic,16)==0){
    valid=YES;
    log(@"✓ RakNet Pong подтверждён");
    break;
   }
   log(@"! Полученный пакет не соответствует ожидаемому RakNet Pong");
  }
  if(addresses)freeaddrinfo(addresses);
  if(valid)log(@"Итог: UDP ответил. Вход и авторизация GTA5RP НЕ выполнены.");
  else if(replyAny)log(@"Итог: UDP ответ есть, но протокол не подтверждён.");
  else if(sentAny)log(@"Итог: ответ не получен. Возможно, сервер блокирует ping; это НЕ доказывает, что он выключен.");
  else log(@"Итог: не удалось отправить UDP-пакет.");
  dispatch_async(dispatch_get_main_queue(),^{weakSelf.probing=NO;});
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
