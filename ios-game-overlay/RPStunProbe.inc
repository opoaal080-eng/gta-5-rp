// STUN Binding Request (RFC 8489), diagnostic only.
static void RPStunProbe(void (^message)(NSString *)) {
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
  struct addrinfo hints={0},*records=NULL;
  hints.ai_family=AF_INET; hints.ai_socktype=SOCK_DGRAM;
  int err=getaddrinfo("stun.l.google.com","19302",&hints,&records);
  if(err){message([NSString stringWithFormat:@"STUN DNS: %s",gai_strerror(err)]);return;}
  struct sockaddr_in target={0};BOOL found=NO;
  for(struct addrinfo *p=records;p;p=p->ai_next){
   if(p->ai_family!=AF_INET)continue;
   const uint8_t *b=(const uint8_t*)&((struct sockaddr_in*)p->ai_addr)->sin_addr;
   if(b[0]==0||b[0]==10||b[0]==127||b[0]>=224||b[0]==192&&b[1]==168)continue;
   target=*(struct sockaddr_in*)p->ai_addr;found=YES;break;
  }
  freeaddrinfo(records);
  if(!found){message(@"STUN DNS: нет публичного IPv4, отключи Fake-IP VPN");return;}
  char address[INET_ADDRSTRLEN]={0};
  inet_ntop(AF_INET,&target.sin_addr,address,sizeof(address));
  message([NSString stringWithFormat:@"STUN сервер: %s:19302",address]);
  int fd=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP);
  if(fd<0){message(@"STUN: невозможно создать сокет");return;}
  struct timeval tv={3,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));
  uint8_t req[20]={0x00,0x01,0x00,0x00,0x21,0x12,0xA4,0x42};
  arc4random_buf(req+8,12);
  CFAbsoluteTime start=CFAbsoluteTimeGetCurrent();
  ssize_t sent=sendto(fd,req,20,0,(struct sockaddr*)&target,sizeof(target));
  if(sent!=20){message([NSString stringWithFormat:@"STUN отправка: %s",strerror(errno)]);close(fd);return;}
  message(@"UDP: отправлено 20 байт (Binding Request)");
  uint8_t buf[1024]={0};
  ssize_t n=recvfrom(fd,buf,sizeof(buf),0,NULL,NULL);
  int savedErrno=errno;
  double elapsed=(CFAbsoluteTimeGetCurrent()-start)*1000.0;
  close(fd);
  if(n<0){message([NSString stringWithFormat:@"STUN: %@ за %.0f мс",
   (savedErrno==EAGAIN||savedErrno==EWOULDBLOCK)?@"тайм-аут":[NSString stringWithUTF8String:strerror(savedErrno)],elapsed]);return;}
  if(n<20||buf[0]!=0x01||buf[1]!=0x01||memcmp(buf+4,req+4,16)!=0){
   message(@"Ответ не соответствует STUN transaction ID");return;
  }
  NSUInteger len=((NSUInteger)buf[2]<<8)|buf[3];
  if(len%4||len>(NSUInteger)n-20){message(@"Некорректная длина STUN");return;}
  NSString *mapped=nil;
  for(NSUInteger i=20;i+4<=20+len;){
   NSUInteger typ=((NSUInteger)buf[i]<<8)|buf[i+1];
   NSUInteger sz=((NSUInteger)buf[i+2]<<8)|buf[i+3];
   if(sz>20+len-i-4)break;
   if((typ==0x0020||typ==0x0001)&&sz>=8&&buf[i+5]==1){
    uint16_t port=((uint16_t)buf[i+6]<<8)|buf[i+7];
    if(typ==0x0020)port^=0x2112;
    uint8_t octets[4];
    for(int j=0;j<4;j++)octets[j]=buf[i+8+j]^(typ==0x0020?req[4+j]:0);
    mapped=[NSString stringWithFormat:@"%u.%u.%u.%u:%u",octets[0],octets[1],octets[2],octets[3],port];
    if(typ==0x0020)break;
   }
   i+=4+((sz+3)&~3);
  }
  message([NSString stringWithFormat:@"STUN ответ: %.0f мс",elapsed]);
  message(mapped?[NSString stringWithFormat:@"Внешний адрес: %@",mapped]:@"Внешний IPv4 не указан");
  message(@"UDP-обмен с STUN работает, но это НЕ вход в GTA5RP");
 });
}
