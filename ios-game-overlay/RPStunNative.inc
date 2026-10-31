// Native iOS UDP STUN probe. RFC 8489. Independent of the game's BSD sockets.
#import <Network/Network.h>
static void RPStunNative(const char *host, const char *port,
                         void (^report)(NSString *), void (^done)(BOOL)) {
 dispatch_queue_t q=dispatch_queue_create("fun.nightwell.gta5rp.stun.native",DISPATCH_QUEUE_SERIAL);
 nw_endpoint_t endpoint=nw_endpoint_create_host(host,port);
 nw_parameters_t parameters=nw_parameters_create_secure_udp(
   NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
 nw_connection_t conn=nw_connection_create(endpoint,parameters);
 nw_connection_set_queue(conn,q);
 __block BOOL finished=NO;
 dispatch_source_t timeout=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,q);
 void (^finish)(BOOL)=^(BOOL success) {
  if(finished)return;
  finished=YES;
  dispatch_source_cancel(timeout);
  nw_connection_cancel(conn);
  done(success);
 };
 dispatch_source_set_timer(timeout,dispatch_time(DISPATCH_TIME_NOW,6*NSEC_PER_SEC),
                           DISPATCH_TIME_FOREVER,NSEC_PER_SEC/10);
 dispatch_source_set_event_handler(timeout,^{
  report(@"Native STUN: тайм-аут 6 секунд, ответа нет.");
  finish(NO);
 });
 dispatch_resume(timeout);
 nw_connection_set_state_changed_handler(conn,^(nw_connection_state_t state,nw_error_t error) {
  if(finished)return;
  if(state==nw_connection_state_waiting) {
   report([NSString stringWithFormat:@"Network.framework: ожидание маршрута (%d)",
           error?nw_error_get_error_code(error):0]);
  } else if(state==nw_connection_state_failed) {
   report([NSString stringWithFormat:@"Network.framework: ошибка %d",
           error?nw_error_get_error_code(error):0]);
   finish(NO);
  } else if(state==nw_connection_state_ready) {
   report(@"Network.framework: UDP-путь готов");
   uint8_t request[20]={0,1,0,0,0x21,0x12,0xA4,0x42};
   arc4random_buf(request+8,12);
   NSData *requestData=[NSData dataWithBytes:request length:sizeof(request)];
   CFAbsoluteTime began=CFAbsoluteTimeGetCurrent();
   nw_connection_receive_message(conn,^(dispatch_data_t content,
       nw_content_context_t context,bool is_complete,nw_error_t receiveError) {
    if(finished)return;
    if(receiveError){
     report([NSString stringWithFormat:@"Native STUN: ошибка чтения %d",
            nw_error_get_error_code(receiveError)]);
     finish(NO);return;
    }
    if(!content){report(@"Native STUN: пустой ответ");finish(NO);return;}
    const void *buffer=NULL;size_t size=0;
    dispatch_data_t mapped=dispatch_data_create_map(content,&buffer,&size);
    (void)mapped;
    const uint8_t *packet=(const uint8_t*)buffer;
    if(size<20||packet[0]!=1||packet[1]!=1||
       memcmp(packet+4,(const uint8_t *)requestData.bytes+4,16)!=0){
     report([NSString stringWithFormat:@"Native STUN: получено %zu байт, но не Binding Success",size]);
     finish(NO);return;
    }
    NSUInteger length=((NSUInteger)packet[2]<<8)|packet[3];
    if((length%4)||length>size-20){
     report(@"Native STUN: неверная длина атрибутов");finish(NO);return;
    }
    NSString *mappedAddress=nil;
    for(NSUInteger i=20;i+4<=20+length;){
     NSUInteger type=((NSUInteger)packet[i]<<8)|packet[i+1];
     NSUInteger n=((NSUInteger)packet[i+2]<<8)|packet[i+3];
     if(n>20+length-i-4)break;
     if((type==0x20||type==0x01)&&n>=8&&packet[i+5]==1){
      unsigned p=((unsigned)packet[i+6]<<8)|packet[i+7];
      if(type==0x20)p^=0x2112;
      uint8_t a[4]={0};
      for(int j=0;j<4;j++)
       a[j]=packet[i+8+j]^(type==0x20?((const uint8_t *)requestData.bytes)[4+j]:0);
      mappedAddress=[NSString stringWithFormat:@"%u.%u.%u.%u:%u",
                     a[0],a[1],a[2],a[3],p];
      if(type==0x20)break;
     }
     i+=4+((n+3)&~3);
    }
    double ms=(CFAbsoluteTimeGetCurrent()-began)*1000;
    report([NSString stringWithFormat:@"✓ Native STUN: ответ %.0f мс",ms]);
    report(mappedAddress?[NSString stringWithFormat:@"Внешний адрес: %@",mappedAddress]:
                         @"Внешний IPv4 не найден в ответе");
    finish(YES);
   });
   uint8_t *heap=malloc(sizeof(request));
   if(!heap){report(@"Native STUN: ошибка памяти");finish(NO);return;}
   memcpy(heap,requestData.bytes,requestData.length);
   dispatch_data_t payload=dispatch_data_create(heap,sizeof(request),q,^{free(heap);});
   nw_connection_send(conn,payload,NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,true,
                      ^(nw_error_t sendError) {
    if(finished)return;
    if(sendError){
     report([NSString stringWithFormat:@"Native STUN: ошибка отправки %d",
       nw_error_get_error_code(sendError)]);
     finish(NO);
    } else {
     report(@"Native STUN: 20 байт отправлены через Network.framework");
    }
   });
  }
 });
 nw_connection_start(conn);
}
