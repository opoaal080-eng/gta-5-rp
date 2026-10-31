#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <netdb.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <sys/time.h>
static UIColor *bg(void){return [UIColor colorWithRed:.075 green:.08 blue:.09 alpha:1];}
static UIColor *card(void){return [UIColor colorWithRed:.14 green:.145 blue:.16 alpha:1];}
static UIColor *orange(void){return [UIColor colorWithRed:1 green:.4 blue:.1 alpha:1];}
@interface RPWindow:UIWindow
@property(nonatomic,weak) UIView *launcherButton;
@property(nonatomic) BOOL menuOpen;
@end
@implementation RPWindow
-(UIView*)hitTest:(CGPoint)p withEvent:(UIEvent*)e{
 if(!self.menuOpen){UIView *b=self.launcherButton;if(!b)return nil;
 CGPoint q=[self convertPoint:p toView:b];if(![b pointInside:q withEvent:e])return nil;}
 return [super hitTest:p withEvent:e];
}
@end
@interface RPController:UIViewController<UITextFieldDelegate>
@property(nonatomic,weak) RPWindow *overlay;
@property(nonatomic,strong) UIButton *floating;
@property(nonatomic,strong) UIView *menu;
@property(nonatomic,strong) UITextField *nameField;
@property(nonatomic,strong) UITextField *hostField;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UILabel *online;
@property(nonatomic,strong) UITextView *servers;
@property(nonatomic,strong) NSURLSessionDataTask *task;
@end
@implementation RPController
-(UILabel*)label:(NSString*)text size:(CGFloat)size strong:(BOOL)strong{
 UILabel*l=[UILabel new];l.text=text;l.numberOfLines=0;l.textColor=UIColor.whiteColor;
 l.font=[UIFont systemFontOfSize:size weight:strong?UIFontWeightBlack:UIFontWeightRegular];return l;
}
-(UIButton*)button:(NSString*)text action:(SEL)action bright:(BOOL)bright{
 UIButton*b=[UIButton buttonWithType:UIButtonTypeSystem];b.backgroundColor=bright?orange():card();
 b.layer.cornerRadius=12;[b setTitle:text forState:UIControlStateNormal];
 [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
 b.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
 [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
-(UITextField*)field:(NSString*)placeholder text:(NSString*)text{
 UITextField*f=[UITextField new];f.backgroundColor=card();f.textColor=UIColor.whiteColor;
 f.layer.cornerRadius=10;f.text=text;f.font=[UIFont systemFontOfSize:15];
 f.attributedPlaceholder=[[NSAttributedString alloc]initWithString:placeholder attributes:@{NSForegroundColorAttributeName:UIColor.lightGrayColor}];
 f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.autocorrectionType=UITextAutocorrectionTypeNo;
 f.delegate=self;f.returnKeyType=UIReturnKeyDone;
 f.leftView=[[UIView alloc]initWithFrame:CGRectMake(0,0,12,2)];f.leftViewMode=UITextFieldViewModeAlways;
 [f.heightAnchor constraintEqualToConstant:48].active=YES;return f;
}
-(void)viewDidLoad{
 [super viewDidLoad];self.view.backgroundColor=UIColor.clearColor;
 UIButton*floatButton=[self button:@"★ RP" action:@selector(toggle) bright:YES];self.floating=floatButton;
 [self.view addSubview:floatButton];floatButton.translatesAutoresizingMaskIntoConstraints=NO;
 [NSLayoutConstraint activateConstraints:@[
 [floatButton.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-14],
 [floatButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
 [floatButton.widthAnchor constraintEqualToConstant:74],[floatButton.heightAnchor constraintEqualToConstant:43]]];
 UIView*menu=[UIView new];self.menu=menu;menu.backgroundColor=bg();menu.hidden=YES;
 [self.view addSubview:menu];menu.translatesAutoresizingMaskIntoConstraints=NO;
 [NSLayoutConstraint activateConstraints:@[
 [menu.topAnchor constraintEqualToAnchor:self.view.topAnchor],[menu.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
 [menu.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[menu.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];
 UIStackView*page=[UIStackView new];page.axis=UILayoutConstraintAxisVertical;
 [menu addSubview:page];page.translatesAutoresizingMaskIntoConstraints=NO;
 [NSLayoutConstraint activateConstraints:@[
 [page.topAnchor constraintEqualToAnchor:menu.safeAreaLayoutGuide.topAnchor],[page.bottomAnchor constraintEqualToAnchor:menu.safeAreaLayoutGuide.bottomAnchor],
 [page.leadingAnchor constraintEqualToAnchor:menu.safeAreaLayoutGuide.leadingAnchor],
 [page.trailingAnchor constraintEqualToAnchor:menu.safeAreaLayoutGuide.trailingAnchor]]];
 UIView*header=[UIView new];header.backgroundColor=card();[page addArrangedSubview:header];[header.heightAnchor constraintEqualToConstant:65].active=YES;
 UILabel*title=[self label:@"★ GTA5 RP   MOBILE" size:22 strong:YES];
 UIButton*close=[self button:@"✕" action:@selector(toggle) bright:YES];[header addSubview:title];[header addSubview:close];
 title.translatesAutoresizingMaskIntoConstraints=NO;close.translatesAutoresizingMaskIntoConstraints=NO;
 [NSLayoutConstraint activateConstraints:@[
 [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:18],[title.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
 [title.trailingAnchor constraintLessThanOrEqualToAnchor:close.leadingAnchor constant:-6],
 [close.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-14],
 [close.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
 [close.heightAnchor constraintEqualToConstant:42],[close.widthAnchor constraintEqualToConstant:45]]];
 UIScrollView*scroll=[UIScrollView new];[page addArrangedSubview:scroll];
 UIStackView*stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=12;
 [scroll addSubview:stack];stack.translatesAutoresizingMaskIntoConstraints=NO;
 [NSLayoutConstraint activateConstraints:@[
 [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
 [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
 [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
 [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
 [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]]];
 [stack addArrangedSubview:[self label:@"СЕРВЕРЫ GTA5RP" size:27 strong:YES]];
 UILabel*description=[self label:@"Публичный онлайн RAGE MP, без загрузки игровых ресурсов." size:13 strong:NO];
 description.textColor=UIColor.lightGrayColor;[stack addArrangedSubview:description];
 self.nameField=[self field:@"Название сервера" text:@"Eclipse"];[stack addArrangedSubview:self.nameField];
 UIButton*refresh=[self button:@"ОБНОВИТЬ ОНЛАЙН" action:@selector(fetchMaster) bright:YES];
 [stack addArrangedSubview:refresh];[refresh.heightAnchor constraintEqualToConstant:51].active=YES;
 self.online=[self label:@"ОНЛАЙН: НЕТ ДАННЫХ" size:23 strong:YES];[stack addArrangedSubview:self.online];
 self.servers=[UITextView new];self.servers.editable=NO;self.servers.layer.cornerRadius=12;
 self.servers.backgroundColor=card();self.servers.textColor=UIColor.whiteColor;
 self.servers.font=[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
 self.servers.text=@"Каталог не загружен";[stack addArrangedSubview:self.servers];
 [self.servers.heightAnchor constraintEqualToConstant:110].active=YES;
 UILabel*network=[self label:@"RAKNET UDP · ПРОВЕРКА СЕРВЕРА" size:20 strong:YES];
 network.textColor=orange();[stack addArrangedSubview:network];
 self.hostField=[self field:@"Домен или IP:22005" text:@""];[stack addArrangedSubview:self.hostField];
 UIButton*probe=[self button:@"ПРОВЕРИТЬ UDP" action:@selector(probe) bright:YES];
 [stack addArrangedSubview:probe];[probe.heightAnchor constraintEqualToConstant:51].active=YES;
 self.status=[self label:@"UDP: адрес не указан" size:14 strong:NO];[stack addArrangedSubview:self.status];
 UIButton*back=[self button:@"ВЕРНУТЬСЯ В ИГРУ ▶" action:@selector(toggle) bright:YES];
 [stack addArrangedSubview:back];[back.heightAnchor constraintEqualToConstant:51].active=YES;
 UILabel*note=[self label:@"ТЕСТОВАЯ ВЕРСИЯ: встроенный P2P-онлайн GTA V сохранён. RAGE MP авторизация и синхронизация персонажей GTA5RP НЕ реализованы. Проверка UDP не означает вход в GTA5RP." size:12 strong:NO];
 note.textColor=UIColor.lightGrayColor;
 [stack addArrangedSubview:note];
}
-(BOOL)textFieldShouldReturn:(UITextField*)f{[f resignFirstResponder];return YES;}
-(void)toggle{
 BOOL show=self.menu.hidden;self.menu.hidden=!show;self.floating.hidden=show;
 self.overlay.menuOpen=show;[self.nameField resignFirstResponder];[self.hostField resignFirstResponder];
 if(show)[self fetchMaster];
}
-(void)fetchMaster{
 [self.task cancel];self.online.text=@"ОНЛАЙН: ПРОВЕРКА";self.servers.text=@"Получение публичного каталога…";
 NSURLRequest*req=[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://cdn.rage.mp/master/"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:12];
 __weak typeof(self)weak=self;
 self.task=[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData*data,NSURLResponse*response,NSError*error){
 dispatch_async(dispatch_get_main_queue(),^{
 __strong typeof(weak)obj=weak;if(!obj)return;
 if(error){if(error.code==NSURLErrorCancelled)return;obj.online.text=@"ОНЛАЙН: НЕТ ДАННЫХ";obj.servers.text=error.localizedDescription;return;}
 if(![response isKindOfClass:NSHTTPURLResponse.class]||((NSHTTPURLResponse*)response).statusCode!=200||data.length>20000000){
 obj.online.text=@"ОНЛАЙН: НЕТ ДАННЫХ";obj.servers.text=@"Ошибка HTTP";return;}
 id parsed=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
 if(![parsed isKindOfClass:NSDictionary.class]){obj.online.text=@"ОНЛАЙН: НЕТ ДАННЫХ";obj.servers.text=@"Неизвестный формат";return;}
 NSString*name=[obj.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(!name.length)name=@"Eclipse";
 NSMutableArray*rows=[NSMutableArray new];NSInteger online=0,limit=0;
 for(id key in (NSDictionary*)parsed){
 id item=[(NSDictionary*)parsed objectForKey:key];if(![item isKindOfClass:NSDictionary.class])continue;
 NSString*title=item[@"name"];if(![title isKindOfClass:NSString.class])continue;
 NSString*flat=[[title lowercaseString]stringByReplacingOccurrencesOfString:@" " withString:@""];
 if(![flat containsString:@"gta5rp"]||[title rangeOfString:name options:NSCaseInsensitiveSearch].location==NSNotFound)continue;
 NSNumber*n=item[@"players"],*m=item[@"maxplayers"];
 if(![n isKindOfClass:NSNumber.class]||![m isKindOfClass:NSNumber.class]||n.integerValue<0||m.integerValue<=0||n.integerValue>m.integerValue)continue;
 online+=n.integerValue;limit+=m.integerValue;
 [rows addObject:[NSString stringWithFormat:@"%@ : %ld/%ld\n%@",title,(long)n.integerValue,(long)m.integerValue,key]];
 }
 if(rows.count){obj.online.text=[NSString stringWithFormat:@"ОНЛАЙН: %ld / %ld",(long)online,(long)limit];obj.servers.text=[rows componentsJoinedByString:@"\n\n"];}
 else{obj.online.text=@"ОНЛАЙН: НЕТ ДАННЫХ";obj.servers.text=@"Совпадений нет. Это не значит, что сервер выключен.";}
 });
 }];[self.task resume];
}
-(void)probe{
 [self.hostField resignFirstResponder];
 NSString*input=[self.hostField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSArray<NSString*>*parts=[input componentsSeparatedByString:@":"];
 if(parts.count<1||parts.count>2||!parts.firstObject.length){self.status.text=@"UDP: укажи домен:порт";return;}
 NSString*host=parts.firstObject;NSInteger port=parts.count==2?parts.lastObject.integerValue:22005;
 if(port<1||port>65535){self.status.text=@"UDP: неверный порт";return;}
 self.status.text=@"UDP: отправка RakNet ping…";
 __weak typeof(self)weak=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
 struct addrinfo hints={0},*result=NULL;hints.ai_family=AF_UNSPEC;hints.ai_socktype=SOCK_DGRAM;
 NSString*pstr=[NSString stringWithFormat:@"%ld",(long)port];int err=getaddrinfo(host.UTF8String,pstr.UTF8String,&hints,&result);
 NSString*message=nil;BOOL pong=NO;
 if(err)message=[NSString stringWithFormat:@"DNS: %s",gai_strerror(err)];
 else{
 static const unsigned char magic[]={0,255,255,0,254,254,254,254,253,253,253,253,18,52,86,120};
 unsigned char packet[33]={0};packet[0]=1;
 uint64_t t=(uint64_t)(NSDate.date.timeIntervalSince1970*1000);
 for(int i=0;i<8;i++)packet[1+i]=(t>>(56-8*i))&255;
 memcpy(packet+9,magic,16);
 for(struct addrinfo*a=result;a;a=a->ai_next){
 int fd=socket(a->ai_family,SOCK_DGRAM,IPPROTO_UDP);if(fd<0)continue;
 struct timeval tv={2,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));
 ssize_t sent=sendto(fd,packet,33,0,a->ai_addr,a->ai_addrlen);
 unsigned char recv[4096];ssize_t count=sent==33?recvfrom(fd,recv,sizeof(recv),0,NULL,NULL):-1;close(fd);
 if(count>=35&&recv[0]==0x1c&&memcmp(recv+17,magic,16)==0){pong=YES;break;}
 }
 freeaddrinfo(result);
 message=pong?@"Получен ответ RakNet Pong. Сервер отвечает, игровая сессия НЕ создана.":@"Нет ответа RakNet Pong. Это не доказывает недоступность сервера.";
 }
 dispatch_async(dispatch_get_main_queue(),^{__strong typeof(weak)obj=weak;if(obj)obj.status.text=message;});
 });
}
@end
@interface RPBoot:NSObject @end
@implementation RPBoot
static RPWindow *gWindow=nil;
+(void)load{
 dispatch_async(dispatch_get_main_queue(),^{
 [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(wake:) name:UIApplicationDidBecomeActiveNotification object:nil];
 [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(wake:) name:UISceneDidActivateNotification object:nil];
 [self install:0];});
}
+(void)wake:(NSNotification*)note{[self install:0];}
+(void)install:(NSUInteger)attempt{
 if(gWindow||attempt>40)return;
 UIWindowScene*scene=nil;
 for(UIScene*s in UIApplication.sharedApplication.connectedScenes)
 if([s isKindOfClass:UIWindowScene.class]&&s.activationState==UISceneActivationStateForegroundActive){scene=(UIWindowScene*)s;break;}
 if(!scene&&!UIApplication.sharedApplication.windows.count){
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self install:attempt+1];});return;}
 RPWindow*win=scene?[[RPWindow alloc]initWithWindowScene:scene]:[[RPWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
 win.backgroundColor=UIColor.clearColor;win.windowLevel=UIWindowLevelAlert+3;
 RPController*control=[RPController new];win.rootViewController=control;control.overlay=win;
 win.hidden=NO;[win layoutIfNeeded];win.launcherButton=control.floating;gWindow=win;
}
@end
