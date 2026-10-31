// One-shot, user-initiated, *unauthenticated* RakNet initial probe.
// This is generic RakNet 0x05/0x06/0x19, NOT the proprietary RAGE MP client handshake.
#import <Network/Network.h>
static void RPRaknetOpenProbeSingle(NSString *host, uint16_t port, NSUInteger mtu,
                             void (^log)(NSString *), void (^done)(void)) {
 dispatch_queue_t queue=dispatch_queue_create("fun.nightwell.raknet.probe",DISPATCH_QUEUE_SERIAL);
 nw_endpoint_t endpoint=nw_endpoint_create_host(host.UTF8String,
                              [NSString stringWithFormat:@"%u",port].UTF8String);
 nw_parameters_t parameters=nw_parameters_create_secure_udp(
                 NW_PARAMETERS_DISABLE_PROTOCOL,NW_PARAMETERS_DEFAULT_CONFIGURATION);
 nw_connection_t connection=nw_connection_create(endpoint,parameters);
 nw_connection_set_queue(connection,queue);
 __block BOOL finished=NO;
 dispatch_source_t timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,queue);
 void (^finish)(void)=^{
  if(finished)return;
  finished=YES;
  dispatch_source_cancel(timer);
  nw_connection_cancel(connection);
  done();
 };
 dispatch_source_set_timer(timer,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),
                             DISPATCH_TIME_FOREVER,100*NSEC_PER_MSEC);
 dispatch_source_set_event_handler(timer,^{
  log([NSString stringWithFormat:@"RakNet UDP-длина %lu: тайм-аут 2 с",(unsigned long)mtu]);
  log(@"Отсутствие ответа не доказывает блокировку или несовместимость сервера.");
  finish();
 });
 dispatch_resume(timer);
 nw_connection_set_state_changed_handler(connection,
      ^(nw_connection_state_t state,nw_error_t error) {
  if(finished)return;
  if(state==nw_connection_state_waiting){
   log([NSString stringWithFormat:@"UDP маршрут: ожидание (%d)",
             error?nw_error_get_error_code(error):0]);
  } else if(state==nw_connection_state_failed){
   log([NSString stringWithFormat:@"UDP маршрут: ошибка %d",
             error?nw_error_get_error_code(error):0]);
   finish();
  } else if(state==nw_connection_state_ready){
   const uint8_t magic[16]={0,255,255,0,254,254,254,254,
                            253,253,253,253,18,52,86,120};
   NSMutableData *packet=[NSMutableData dataWithLength:mtu];
   uint8_t *p=(uint8_t *)packet.mutableBytes;
   p[0]=0x05;
   memcpy(p+1,magic,16);
   p[17]=0x09; // Common RAGE MP RakNet version candidate, not an official compatibility claim.
   NSData *immutable=[packet copy];
   CFAbsoluteTime started=CFAbsoluteTimeGetCurrent();
   nw_connection_receive_message(connection,^(dispatch_data_t content,
                   nw_content_context_t context,bool complete,nw_error_t receiveError) {
    if(finished)return;
    if(receiveError){
     log([NSString stringWithFormat:@"RakNet: ошибка чтения %d",
                       nw_error_get_error_code(receiveError)]);
     finish();return;
    }
    if(!content){
     log(@"RakNet: пришёл пустой UDP-ответ");finish();return;
    }
    const void *bytes=NULL;size_t count=0;
    dispatch_data_t mapped=dispatch_data_create_map(content,&bytes,&count);
    (void)mapped;
    const uint8_t *response=(const uint8_t *)bytes;
    double ms=(CFAbsoluteTimeGetCurrent()-started)*1000;
    if(count<1){log(@"RakNet: нулевая длина пакета");finish();return;}
    uint8_t kind=response[0];
    log([NSString stringWithFormat:@"Ответ UDP: ID=0x%02X, %zu байт, %.0f мс",
           kind,count,ms]);
    if(kind==0x06){
     if(count<26 || memcmp(response+1,((const uint8_t *)immutable.bytes)+1,16)!=0){
      log(@"Ответ 0x06: неверный magic / слишком короткий пакет");
     }else{
      uint64_t guid=0;
      for(int i=17;i<25;i++)guid=(guid<<8)|response[i];
      log([NSString stringWithFormat:@"✓ RakNet OpenConnectionReply1, сервер GUID 0x%llX",
               (unsigned long long)guid]);
      log([NSString stringWithFormat:@"Флаг security: %@, расширение ответа: %zu байт",
             response[25]?@"включён":@"выключен",count-26]);
      log(@"Это лишь начальный ответ, ещё НЕ соединение GTA5RP.");
     }
    }else if(kind==0x19){
     if(count>=18 && memcmp(response+2,((const uint8_t *)immutable.bytes)+1,16)==0)
      log([NSString stringWithFormat:@"Версия RakNet несовместима: сервер сообщает %u",
                       (unsigned)response[1]]);
     else log(@"Пакет 0x19, но структура не подтверждена");
    }else{
     log(@"Неожиданный тип: сервер не подтвердил стандартный первый этап RakNet.");
    }
    finish();
   });
   void *payload=malloc(immutable.length);
   if(!payload){log(@"Ошибка выделения памяти");finish();return;}
   memcpy(payload,immutable.bytes,immutable.length);
   dispatch_data_t datagram=dispatch_data_create(payload,immutable.length,queue,^{free(payload);});
   nw_connection_send(connection,datagram,NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,true,
       ^(nw_error_t sendError) {
    if(finished)return;
    if(sendError){
     log([NSString stringWithFormat:@"RakNet: отправка не прошла (%d)",
                               nw_error_get_error_code(sendError)]);
     finish();
    } else {
     log([NSString stringWithFormat:@"OpenConnectionRequest1 отправлен: версия 9, UDP-длина %lu, ID 0x05",(unsigned long)mtu]);
    }
   });
  }
 });
 nw_connection_start(connection);
}
static void RPRaknetOpenProbe(NSString *host, uint16_t port,
                             void (^log)(NSString *),void (^done)(void)) {
 // Three sequential bounded UDP datagram lengths, not measurements of path MTU.
 // No authentication, no 0x07 or game sync.
 NSArray<NSNumber *> *sizes=@[@576,@1200,@1400];
 __block NSUInteger index=0;
 __block void (^next)(void)=nil;
 next=^{
  if(index>=sizes.count){
   log(@"Итог: все три длины UDP проверены. Тайм-ауты не доказывают невозможность входа в GTA5RP.");
   done();
   next=nil;return;
  }
  NSUInteger mtu=sizes[index++].unsignedIntegerValue;
  log([NSString stringWithFormat:@"UDP длина %lu: начинаем проверку %lu/3",
                    (unsigned long)mtu,(unsigned long)index]);
  RPRaknetOpenProbeSingle(host,port,mtu,log,^{next();});
 };
 next();
}
// Only HEAD / is sent. No client_resources files or bodies are downloaded.
static void RPRageResourcePortProbe(NSString *host,uint16_t port,
                                   void (^log)(NSString *),void (^done)(void)) {
 dispatch_queue_t queue=dispatch_queue_create("fun.nightwell.rage.httphead",DISPATCH_QUEUE_SERIAL);
 nw_endpoint_t target=nw_endpoint_create_host(host.UTF8String,
                                  [NSString stringWithFormat:@"%u",port].UTF8String);
 nw_parameters_t params=nw_parameters_create_secure_tcp(
                  NW_PARAMETERS_DISABLE_PROTOCOL,NW_PARAMETERS_DEFAULT_CONFIGURATION);
 nw_connection_t conn=nw_connection_create(target,params);
 nw_connection_set_queue(conn,queue);
 __block BOOL finished=NO;
 dispatch_source_t timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,queue);
 void (^finish)(void)=^{
  if(finished)return;
  finished=YES;
  dispatch_source_cancel(timer);
  nw_connection_cancel(conn);
  done();
 };
 dispatch_source_set_timer(timer,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),
                          DISPATCH_TIME_FOREVER,NSEC_PER_SEC/10);
 dispatch_source_set_event_handler(timer,^{
  log(@"TCP/HTTP HEAD: тайм-аут 5 с. Это не доказывает недоступность ресурсов.");
  finish();
 });
 dispatch_resume(timer);
 nw_connection_set_state_changed_handler(conn,^(nw_connection_state_t state,nw_error_t error){
  if(finished)return;
  if(state==nw_connection_state_ready){
   log([NSString stringWithFormat:@"✓ TCP %u подключен",port]);
   NSString *head=[NSString stringWithFormat:
          @"HEAD / HTTP/1.1\r\nHost: %@:%u\r\nUser-Agent: GTA5RPOnlineLab/0.9\r\nAccept: */*\r\nConnection: close\r\n\r\n",host,port];
   NSData *encoded=[head dataUsingEncoding:NSUTF8StringEncoding];
   nw_connection_receive(conn,1,8192,^(dispatch_data_t bytes,
                                        nw_content_context_t context,
                                        bool complete,nw_error_t receiveError){
    if(finished)return;
    if(receiveError){
     log([NSString stringWithFormat:@"HTTP HEAD: ошибка ответа %d",nw_error_get_error_code(receiveError)]);
     finish();return;
    }
    if(!bytes){log(@"HTTP HEAD: пустой ответ");finish();return;}
    const void *buf=NULL;size_t count=0;
    dispatch_data_t mapped=dispatch_data_create_map(bytes,&buf,&count);
    (void)mapped;
    NSData *data=[NSData dataWithBytes:buf length:count];
    NSString *response=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    if(!response){log(@"HTTP HEAD: ответ не является текстовым HTTP");finish();return;}
    NSArray<NSString *> *lines=[response componentsSeparatedByString:@"\r\n"];
    NSString *first=lines.count?lines.firstObject:@"";
    if(![first hasPrefix:@"HTTP/"]){
     log([NSString stringWithFormat:@"Необычный ответ порта %u: %@",port,
                        [first substringToIndex:MIN((NSUInteger)120,first.length)]]);
     finish();return;
    }
    log([NSString stringWithFormat:@"HTTP HEAD: %@",first]);
    for(NSString *line in lines){
     NSString *lower=line.lowercaseString;
     if([lower hasPrefix:@"content-type:"]||[lower hasPrefix:@"content-length:"]||
        [lower hasPrefix:@"location:"]){
      log([line substringToIndex:MIN((NSUInteger)200,line.length)]);
     }
    }
    log(@"Проверены только заголовки HTTP, не игровые ресурсы.");
    finish();
   });
   void *buf=malloc(encoded.length);
   if(!buf){log(@"HTTP HEAD: ошибка памяти");finish();return;}
   memcpy(buf,encoded.bytes,encoded.length);
   dispatch_data_t payload=dispatch_data_create(buf,encoded.length,queue,^{free(buf);});
   nw_connection_send(conn,payload,NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,true,
     ^(nw_error_t sendError){
      if(finished)return;
      if(sendError){
       log([NSString stringWithFormat:@"HTTP HEAD: отправка не удалась (%d)",
                           nw_error_get_error_code(sendError)]);
       finish();
      }else{
       log(@"Отправлен HEAD / без загрузки данных");
      }
     });
  }else if(state==nw_connection_state_failed){
   log([NSString stringWithFormat:@"TCP %u ошибка %d",port,
          error?nw_error_get_error_code(error):0]);
   finish();
  }
 });
 nw_connection_start(conn);
}
