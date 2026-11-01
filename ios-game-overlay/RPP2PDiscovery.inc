// Read-only discovery of the _gtavmp._udp Bonjour service advertised by the
// second user-supplied iOS P2P GTA V port. Discovery != joining a session.
#import <Network/Network.h>
static nw_browser_t RPP2PBrowse(void (^report)(NSString *),void (^complete)(void)){
 nw_browse_descriptor_t descriptor=nw_browse_descriptor_create_bonjour_service("_gtavmp._udp",NULL);
 nw_parameters_t parameters=nw_parameters_create_secure_tcp(
              NW_PARAMETERS_DISABLE_PROTOCOL,NW_PARAMETERS_DEFAULT_CONFIGURATION);
 nw_parameters_set_include_peer_to_peer(parameters,true);
 nw_browser_t browser=nw_browser_create(descriptor,parameters);
 if(!browser){report(@"Не удалось создать Bonjour browser");complete();return nil;}
 dispatch_queue_t queue=dispatch_get_main_queue();
 nw_browser_set_queue(browser,queue);
 __block NSUInteger count=0;
 NSMutableSet<NSString *> *known=[NSMutableSet set];
 __block BOOL finished=NO;
 void (^finish)(void)=^{
  if(finished)return;finished=YES;
  nw_browser_cancel(browser);
  report([NSString stringWithFormat:@"Поиск окончен: найдено %lu P2P-объявлений",
                  (unsigned long)known.count]);
  report(@"Это обнаружение LAN-сессий, а не вход в мир другого клиента.");
  complete();
 };
 nw_browser_set_state_changed_handler(browser,^(nw_browser_state_t state,nw_error_t err){
  if(finished)return;
  if(state==nw_browser_state_ready){
   report(@"Поиск GTA V P2P по локальной сети запущен (12 сек.)");
  }else if(state==nw_browser_state_waiting){
   report([NSString stringWithFormat:@"Bonjour ожидает сеть/разрешение (%d)",
                       err?nw_error_get_error_code(err):0]);
  }else if(state==nw_browser_state_failed){
   report([NSString stringWithFormat:@"Ошибка Bonjour browser (%d)",
                       err?nw_error_get_error_code(err):0]);
   finish();
  }
 });
 nw_browser_set_browse_results_changed_handler(browser,^(
           nw_browse_result_t old_result,nw_browse_result_t new_result,bool changes_complete){
  if(finished||!new_result)return;
  nw_endpoint_t endpoint=nw_browse_result_copy_endpoint(new_result);
  if(!endpoint||nw_endpoint_get_type(endpoint)!=nw_endpoint_type_bonjour_service)return;
  const char *cname=nw_endpoint_get_bonjour_service_name(endpoint);
  NSString *name=cname?[NSString stringWithUTF8String:cname]:@"Неизвестный P2P хост";
  if(name.length>80)name=[name substringToIndex:80];
  if([known containsObject:name])return;
  if(count++>=20)return;
  [known addObject:name];
  report([NSString stringWithFormat:@"Обнаружена P2P-сессия: %@",name]);
 });
 nw_browser_start(browser);
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),queue,^{finish();});
 return browser;
}
